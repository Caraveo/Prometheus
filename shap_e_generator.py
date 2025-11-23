#!/usr/bin/env python3
"""
OpenAI Shap-E 3D Model Generator
Supports text-to-3D and image-to-3D generation
"""

import argparse
import os
import sys
from pathlib import Path
import json

try:
    import torch
    import numpy as np
    
    # Force float32 for MPS compatibility (MPS doesn't support float64)
    if torch.backends.mps.is_available():
        torch.set_default_dtype(torch.float32)
        
        # Patch numpy conversion to use float32
        original_from_numpy = torch.from_numpy
        def patched_from_numpy(arr):
            if arr.dtype == np.float64:
                arr = arr.astype(np.float32)
            return original_from_numpy(arr)
        torch.from_numpy = patched_from_numpy
    
    from shap_e.diffusion.sample import sample_latents
    from shap_e.diffusion.gaussian_diffusion import diffusion_from_config
    from shap_e.models.download import load_model, load_config
    from shap_e.util.image_util import load_image
    from shap_e.util.notebooks import decode_latent_mesh
    import trimesh
    
    # Monkey patch Shap-E's _extract_into_tensor to use float32 on MPS
    if torch.backends.mps.is_available():
        from shap_e.diffusion import gaussian_diffusion
        original_extract = gaussian_diffusion._extract_into_tensor
        
        def patched_extract_into_tensor(arr, timesteps, broadcast_shape):
            """Patched version that converts to float32 for MPS compatibility"""
            import torch as th
            res = th.from_numpy(arr).to(device=timesteps.device)
            # Convert to float32 if on MPS
            if timesteps.device.type == 'mps':
                res = res.float()
            else:
                res = res.float()
            res = res[timesteps].float()
            while len(res.shape) < len(broadcast_shape):
                res = res[..., None]
            return res.expand(broadcast_shape)
        
        gaussian_diffusion._extract_into_tensor = patched_extract_into_tensor
        
except ImportError as e:
    print(f"Error importing required libraries: {e}", file=sys.stderr)
    print("Please install requirements: pip install -r requirements.txt", file=sys.stderr)
    sys.exit(1)


def setup_models(use_image_model=False):
    """Load Shap-E models"""
    # Determine device: MPS (Apple Silicon) > CUDA > CPU
    # MPS is used with float32 forced for compatibility
    if torch.backends.mps.is_available() and torch.backends.mps.is_built():
        device = torch.device('mps')
        print("Using device: MPS (Apple Silicon GPU) with float32", file=sys.stderr)
        sys.stderr.flush()
    elif torch.cuda.is_available():
        device = torch.device('cuda')
        print("Using device: CUDA", file=sys.stderr)
        sys.stderr.flush()
    else:
        device = torch.device('cpu')
        print("Using device: CPU", file=sys.stderr)
        sys.stderr.flush()
    
    # Load models
    print("Loading Shap-E models...", file=sys.stderr)
    sys.stderr.flush()
    
    try:
        xm = load_model('transmitter', device=device)
        print("✓ Transmitter model loaded", file=sys.stderr)
        sys.stderr.flush()
        
        if use_image_model:
            model = load_model('image300M', device=device)
            print("✓ Image model loaded", file=sys.stderr)
        else:
            model = load_model('text300M', device=device)
            print("✓ Text model loaded", file=sys.stderr)
        sys.stderr.flush()
        
        diffusion = diffusion_from_config(load_config('diffusion'))
        print("✓ Diffusion config loaded", file=sys.stderr)
        sys.stderr.flush()
        
    except Exception as e:
        print(f"Error loading models: {e}", file=sys.stderr)
        sys.stderr.flush()
        raise
    
    return device, xm, model, diffusion


def convert_to_usdz(obj_path: str, usdz_path: str) -> bool:
    """Convert OBJ file to USDZ format for iPhone/Vision Pro using Python"""
    try:
        # Try using usdzconvert command-line tool (available on macOS with Xcode)
        import subprocess
        result = subprocess.run(
            ['usdzconvert', obj_path, usdz_path],
            capture_output=True,
            text=True,
            timeout=30
        )
        if result.returncode == 0 and os.path.exists(usdz_path) and os.path.getsize(usdz_path) > 1000:
            return True
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    except Exception:
        pass
    
    # Fallback: Create USDZ manually using Python
    try:
        import zipfile
        import tempfile
        
        # Read OBJ file to extract mesh data
        with open(obj_path, 'r') as f:
            obj_lines = f.readlines()
        
        vertices = []
        faces = []
        
        for line in obj_lines:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            if line.startswith('v '):
                # Vertex: v x y z
                parts = line.split()
                if len(parts) >= 4:
                    try:
                        x, y, z = float(parts[1]), float(parts[2]), float(parts[3])
                        vertices.append(f"({x}, {y}, {z})")
                    except ValueError:
                        continue
            elif line.startswith('f '):
                # Face: f v1 v2 v3 (1-indexed, may have texture/normal indices)
                parts = line.split()[1:]
                if len(parts) >= 3:
                    try:
                        # Extract vertex indices (first number before any '/')
                        face_verts = []
                        for p in parts[:3]:
                            v_idx = int(p.split('/')[0]) - 1  # Convert to 0-indexed
                            if 0 <= v_idx < len(vertices):
                                face_verts.append(v_idx)
                        if len(face_verts) == 3:
                            faces.extend(face_verts)
                    except (ValueError, IndexError):
                        continue
        
        if not vertices or not faces:
            print(f"Invalid OBJ data: {len(vertices)} vertices, {len(faces)} face indices", file=sys.stderr)
            return False
        
        # Create USD file content with proper formatting
        vertex_str = ",\n            ".join(vertices)
        face_vertex_indices = ",\n            ".join([str(i) for i in faces])
        num_faces = len(faces) // 3
        face_vertex_counts = ",\n            ".join(["3"] * num_faces)
        
        usd_content = f"""#usda 1.0
(
    defaultPrim = "Root"
    metersPerUnit = 1
    upAxis = "Y"
)

def Xform "Root"
{{
    def Mesh "Mesh"
    {{
        int[] faceVertexCounts = [{face_vertex_counts}]
        int[] faceVertexIndices = [{face_vertex_indices}]
        point3f[] points = [{vertex_str}]
        normal3f[] normals = []
        texCoord2f[] primvars:st = []
    }}
}}
"""
        
        # Create temporary USD file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.usd', delete=False, encoding='utf-8') as tmp_usd:
            tmp_usd.write(usd_content)
            tmp_usd_path = tmp_usd.name
        
        # Create USDZ (ZIP archive)
        with zipfile.ZipFile(usdz_path, 'w', zipfile.ZIP_DEFLATED) as usdz:
            usdz.write(tmp_usd_path, 'model.usd')
        
        os.unlink(tmp_usd_path)
        
        if os.path.exists(usdz_path) and os.path.getsize(usdz_path) > 1000:
            return True
        return False
        
    except Exception as e:
        print(f"USDZ conversion error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return False


def generate_text_to_3d(prompt: str, output_dir: str = "output") -> str:
    """Generate 3D model from text prompt"""
    device, xm, model, diffusion = setup_models()
    
    print(f"Generating 3D model from prompt: {prompt}", file=sys.stderr)
    sys.stderr.flush()
    
    # Generate latents
    batch_size = 1
    guidance_scale = 15.0
    
    print("Starting diffusion sampling (this may take a few minutes)...", file=sys.stderr)
    sys.stderr.flush()
    
    try:
        latents = sample_latents(
            batch_size=batch_size,
            model=model,
            diffusion=diffusion,
            guidance_scale=guidance_scale,
            model_kwargs=dict(texts=[prompt] * batch_size),
            progress=True,
            clip_denoised=True,
            use_fp16=True,
            use_karras=True,
            karras_steps=64,
            sigma_min=1e-3,
            sigma_max=160,
            s_churn=0,
        )
        print("✓ Sampling complete", file=sys.stderr)
        sys.stderr.flush()
    except Exception as e:
        print(f"Error during sampling: {e}", file=sys.stderr)
        sys.stderr.flush()
        raise
    
    # Decode to mesh
    print("Decoding mesh...", file=sys.stderr)
    sys.stderr.flush()
    
    try:
        t = decode_latent_mesh(xm, latents[0]).tri_mesh()
        print("✓ Mesh decoded", file=sys.stderr)
        sys.stderr.flush()
    except Exception as e:
        print(f"Error decoding mesh: {e}", file=sys.stderr)
        sys.stderr.flush()
        raise
    
    # Save mesh
    os.makedirs(output_dir, exist_ok=True)
    # Sanitize filename
    safe_prompt = "".join(c for c in prompt[:30] if c.isalnum() or c in (' ', '-', '_')).strip()
    safe_prompt = safe_prompt.replace(' ', '_')
    if not safe_prompt:
        safe_prompt = "model"
    output_path = os.path.join(output_dir, f"{safe_prompt}.ply")
    
    print(f"Saving mesh to {output_path}...", file=sys.stderr)
    sys.stderr.flush()
    
    try:
        mesh = trimesh.Trimesh(vertices=t.verts, faces=t.faces)
        mesh.export(output_path)
        print(f"✓ PLY mesh saved", file=sys.stderr)
        sys.stderr.flush()
        
        # Also export as USDZ for iPhone/Vision Pro compatibility
        usdz_path = output_path.replace('.ply', '.usdz')
        print(f"Converting to USDZ for iPhone/Vision Pro...", file=sys.stderr)
        sys.stderr.flush()
        
        try:
            # Export to OBJ first (intermediate format)
            obj_path = output_path.replace('.ply', '.obj')
            mesh.export(obj_path)
            
            # Convert OBJ to USDZ
            usdz_success = convert_to_usdz(obj_path, usdz_path)
            
            if usdz_success:
                print(f"✓ USDZ file saved: {usdz_path}", file=sys.stderr)
                sys.stderr.flush()
                # Clean up intermediate OBJ file
                try:
                    os.remove(obj_path)
                except:
                    pass
            else:
                print(f"⚠ USDZ conversion failed, PLY file is available", file=sys.stderr)
                sys.stderr.flush()
        except Exception as e:
            print(f"⚠ USDZ conversion error: {e}", file=sys.stderr)
            print(f"  PLY file is still available at: {output_path}", file=sys.stderr)
            sys.stderr.flush()
            
    except Exception as e:
        print(f"Error saving mesh: {e}", file=sys.stderr)
        sys.stderr.flush()
        raise
    
    print(f"OUTPUT_PATH: {output_path}", file=sys.stdout)
    usdz_path = output_path.replace('.ply', '.usdz')
    if os.path.exists(usdz_path):
        print(f"USDZ_PATH: {usdz_path}", file=sys.stdout)
    sys.stdout.flush()
    return output_path


def generate_image_to_3d(image_path: str, prompt: str = "", output_dir: str = "output") -> str:
    """Generate 3D model from image"""
    device, xm, model, diffusion = setup_models(use_image_model=True)
    
    if not os.path.exists(image_path):
        raise FileNotFoundError(f"Image not found: {image_path}")
    
    print(f"Generating 3D model from image: {image_path}", file=sys.stderr)
    sys.stderr.flush()
    
    # Load image
    print("Loading image...", file=sys.stderr)
    sys.stderr.flush()
    image = load_image(image_path)
    print("✓ Image loaded", file=sys.stderr)
    sys.stderr.flush()
    
    # Generate latents
    batch_size = 1
    guidance_scale = 15.0
    
    model_kwargs = dict(images=[image] * batch_size)
    if prompt:
        model_kwargs['texts'] = [prompt] * batch_size
    else:
        model_kwargs['texts'] = [""] * batch_size
    
    print("Starting diffusion sampling (this may take a few minutes)...", file=sys.stderr)
    sys.stderr.flush()
    
    try:
        latents = sample_latents(
            batch_size=batch_size,
            model=model,
            diffusion=diffusion,
            guidance_scale=guidance_scale,
            model_kwargs=model_kwargs,
            progress=True,
            clip_denoised=True,
            use_fp16=True,
            use_karras=True,
            karras_steps=64,
            sigma_min=1e-3,
            sigma_max=160,
            s_churn=0,
        )
        print("✓ Sampling complete", file=sys.stderr)
        sys.stderr.flush()
    except Exception as e:
        print(f"Error during sampling: {e}", file=sys.stderr)
        sys.stderr.flush()
        raise
    
    # Decode to mesh
    print("Decoding mesh...", file=sys.stderr)
    sys.stderr.flush()
    
    try:
        t = decode_latent_mesh(xm, latents[0]).tri_mesh()
        print("✓ Mesh decoded", file=sys.stderr)
        sys.stderr.flush()
    except Exception as e:
        print(f"Error decoding mesh: {e}", file=sys.stderr)
        sys.stderr.flush()
        raise
    
    # Save mesh
    os.makedirs(output_dir, exist_ok=True)
    image_name = Path(image_path).stem
    # Sanitize filename
    safe_name = "".join(c for c in image_name if c.isalnum() or c in (' ', '-', '_')).strip()
    if not safe_name:
        safe_name = "model"
    output_path = os.path.join(output_dir, f"{safe_name}.ply")
    
    print(f"Saving mesh to {output_path}...", file=sys.stderr)
    sys.stderr.flush()
    
    try:
        mesh = trimesh.Trimesh(vertices=t.verts, faces=t.faces)
        mesh.export(output_path)
        print(f"✓ PLY mesh saved", file=sys.stderr)
        sys.stderr.flush()
        
        # Also export as USDZ for iPhone/Vision Pro compatibility
        usdz_path = output_path.replace('.ply', '.usdz')
        print(f"Converting to USDZ for iPhone/Vision Pro...", file=sys.stderr)
        sys.stderr.flush()
        
        try:
            # Export to OBJ first (intermediate format)
            obj_path = output_path.replace('.ply', '.obj')
            mesh.export(obj_path)
            
            # Convert OBJ to USDZ
            usdz_success = convert_to_usdz(obj_path, usdz_path)
            
            if usdz_success:
                print(f"✓ USDZ file saved: {usdz_path}", file=sys.stderr)
                sys.stderr.flush()
                # Clean up intermediate OBJ file
                try:
                    os.remove(obj_path)
                except:
                    pass
            else:
                print(f"⚠ USDZ conversion failed, PLY file is available", file=sys.stderr)
                sys.stderr.flush()
        except Exception as e:
            print(f"⚠ USDZ conversion error: {e}", file=sys.stderr)
            print(f"  PLY file is still available at: {output_path}", file=sys.stderr)
            sys.stderr.flush()
            
    except Exception as e:
        print(f"Error saving mesh: {e}", file=sys.stderr)
        sys.stderr.flush()
        raise
    
    print(f"OUTPUT_PATH: {output_path}", file=sys.stdout)
    usdz_path = output_path.replace('.ply', '.usdz')
    if os.path.exists(usdz_path):
        print(f"USDZ_PATH: {usdz_path}", file=sys.stdout)
    sys.stdout.flush()
    return output_path


def main():
    parser = argparse.ArgumentParser(description='Generate 3D models using OpenAI Shap-E')
    parser.add_argument('--mode', choices=['text', 'image'], required=True,
                        help='Generation mode: text or image')
    parser.add_argument('--prompt', type=str, required=True,
                        help='Text prompt for generation')
    parser.add_argument('--image', type=str, default=None,
                        help='Path to input image (required for image mode)')
    parser.add_argument('--output', type=str, default='output',
                        help='Output directory for generated models')
    parser.add_argument('--generate-materials', action='store_true',
                        help='Generate PBR material maps (albedo, roughness, metallic, bump)')
    
    args = parser.parse_args()
    
    try:
        if args.mode == 'text':
            output_path = generate_text_to_3d(args.prompt, args.output)
        elif args.mode == 'image':
            if not args.image:
                print("Error: --image is required for image mode", file=sys.stderr)
                sys.exit(1)
            output_path = generate_image_to_3d(args.image, args.prompt, args.output)
        
        print(f"Successfully generated 3D model: {output_path}", file=sys.stderr)
        
        # Generate materials if requested
        if args.generate_materials:
            print("", file=sys.stderr)
            print("Generating PBR materials...", file=sys.stderr)
            sys.stderr.flush()
            
            try:
                from material_generator import generate_materials
                
                material_result = generate_materials(
                    mesh_path=output_path,
                    prompt=args.prompt,
                    output_dir=os.path.join(args.output, "materials"),
                    model_dir="pretrained_models"
                )
                
                if material_result.get('success'):
                    print(f"✓ Materials generated successfully", file=sys.stderr)
                    print(f"MATERIAL_ALBEDO: {material_result['albedo']}", file=sys.stdout)
                    print(f"MATERIAL_ROUGHNESS: {material_result['roughness']}", file=sys.stdout)
                    print(f"MATERIAL_METALLIC: {material_result['metallic']}", file=sys.stdout)
                    print(f"MATERIAL_BUMP: {material_result['bump']}", file=sys.stdout)
                    sys.stdout.flush()
                else:
                    print(f"⚠ Material generation failed: {material_result.get('error', 'Unknown error')}", file=sys.stderr)
                    print(f"   3D model is still available at: {output_path}", file=sys.stderr)
                    sys.stderr.flush()
            except ImportError:
                print("⚠ MaterialAnything not available. Install dependencies to enable material generation.", file=sys.stderr)
                sys.stderr.flush()
            except Exception as e:
                print(f"⚠ Material generation error: {e}", file=sys.stderr)
                print(f"   3D model is still available at: {output_path}", file=sys.stderr)
                sys.stderr.flush()
        
    except Exception as e:
        print(f"Error: {str(e)}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()

