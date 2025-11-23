# Prometheus Workflow Guide

This document explains the complete workflow for using Prometheus to generate 3D models.

## Initial Setup (One-Time)

### 1. Clone and Setup Environment
```bash
git clone https://github.com/Caraveo/Prometheus.git
cd Prometheus
./setup.sh
```

This will:
- Create Python virtual environment (`env/`)
- Install all dependencies (PyTorch, Shap-E, etc.)
- Install Shap-E from GitHub
- Set up the environment for Apple Silicon M-Series optimization

### 2. (Optional) Download MaterialAnything Models
If you want to use material generation:
```bash
./download_material_models.sh
```

This downloads ~2-3GB of material generation models from HuggingFace.

### 3. Launch the App
```bash
./run.sh
```

This builds and launches the macOS app with proper focus.

---

## Workflow 1: Text-to-3D Generation (Shap-E)

**Best for:** Creating 3D models from text descriptions

### Steps:
1. **Select Mode:** Choose "Text to 3D" from the mode selector
2. **Enter Prompt:** Type a description (e.g., "a red sports car", "a wooden chair")
3. **Optional - Generate Materials:** Toggle "Generate Materials" if you want PBR textures
4. **Generate:** Click "Generate 3D Model"
5. **Wait:** First generation takes 5-10 minutes (downloads models), subsequent ones take 1-3 minutes
6. **View Results:**
   - PLY file saved in `output/` directory
   - USDZ file automatically generated for iPhone/Vision Pro
   - Material maps (if enabled) saved in `output/materials/`

### Output Files:
- `output/{prompt}.ply` - 3D mesh file (Blender, MeshLab compatible)
- `output/{prompt}.usdz` - Spatial computing format (iPhone/Vision Pro)
- `output/materials/{prompt}_albedo.png` - Albedo map (if materials enabled)
- `output/materials/{prompt}_roughness.png` - Roughness map
- `output/materials/{prompt}_metallic.png` - Metallic map
- `output/materials/{prompt}_bump.png` - Bump/normal map

---

## Workflow 2: Image-to-3D Generation (Shap-E)

**Best for:** Converting 2D images into 3D models

### Steps:
1. **Select Mode:** Choose "Image to 3D" from the mode selector
2. **Drop Image:** Drag and drop an image into the drop zone, or use the folder button
3. **Optional Prompt:** Add a text description for additional guidance
4. **Optional - Generate Materials:** Toggle "Generate Materials" for PBR textures
5. **Generate:** Click "Generate 3D Model"
6. **Wait:** Processing takes 1-3 minutes
7. **View Results:** Same as Text-to-3D workflow

### Tips:
- Use clear, well-lit images for best results
- Images with depth information work better
- The prompt helps guide the 3D reconstruction

---

## Workflow 3: NeRF (Neural Radiance Fields)

**Best for:** Reconstructing 3D scenes from multiple photographs

### Prerequisites:
- Multiple images (at least 3, preferably 20+) of the same scene from different angles
- Camera poses (can be generated with COLMAP/LLFF tools)
- **Note:** NeRF requires TensorFlow 1.15 and CUDA, which may not work on Apple Silicon

### Steps:
1. **Prepare Images:**
   - Take 20+ photos of your scene from different angles
   - Place all images in a single directory
   - Ensure consistent lighting and exposure

2. **Generate Camera Poses (if needed):**
   - Use COLMAP or LLFF tools to compute camera poses
   - Save poses as `poses_bounds.npy` in the images directory

3. **Select Mode:** Choose "NeRF (Multi-Image)" from the mode selector

4. **Select Directory:** Click folder button and select your images directory

5. **Generate:** Click "Generate 3D Model"

6. **Wait:** NeRF training takes several hours (depending on scene complexity and hardware)

7. **View Results:**
   - Trained NeRF model in `output/logs/`
   - Extracted mesh in `output/nerf_mesh.ply`
   - Render video in `output/nerf_video.mp4`

### Important Notes:
- ⚠️ **Apple Silicon Limitation:** Original NeRF uses TensorFlow 1.15 which may not work on M-Series chips
- Consider using modern NeRF implementations (like nerfstudio) for Apple Silicon compatibility
- Training time: 2-24 hours depending on scene and hardware
- Requires CUDA GPU for reasonable training times

---

## Workflow 4: Material Generation (MaterialAnything)

**Best for:** Adding realistic textures to generated 3D models

### Prerequisites:
- A generated 3D model (from Shap-E workflows)
- MaterialAnything models downloaded (`./download_material_models.sh`)

### Steps:
1. **Generate 3D Model:** Use Text-to-3D or Image-to-3D workflow first
2. **Enable Materials:** Toggle "Generate Materials" before generating
3. **Wait:** Material generation adds 2-5 minutes to processing time
4. **View Results:** Material maps appear in the output section

### Material Maps Explained:
- **Albedo:** Base color/diffuse texture
- **Roughness:** Surface roughness (affects how light scatters)
- **Metallic:** Metallic properties (for PBR rendering)
- **Bump:** Surface detail/normal map

### Usage in 3D Software:
- Import PLY mesh into Blender, Unreal Engine, Unity, etc.
- Apply material maps using PBR shader
- Adjust material properties based on the generated maps

---

## Complete Example Workflow

### Creating a Textured 3D Car:

1. **Setup (one-time):**
   ```bash
   ./setup.sh
   ./download_material_models.sh
   ```

2. **Generate Model:**
   - Launch app: `./run.sh`
   - Select "Text to 3D"
   - Enter prompt: "a red sports car, detailed, realistic"
   - Toggle "Generate Materials" ON
   - Click "Generate 3D Model"
   - Wait 5-10 minutes (first time) or 2-5 minutes (subsequent)

3. **Results:**
   - `output/a_red_sports_car.ply` - 3D mesh
   - `output/a_red_sports_car.usdz` - For iPhone/Vision Pro
   - `output/materials/a_red_sports_car_albedo.png` - Car paint texture
   - `output/materials/a_red_sports_car_roughness.png` - Surface finish
   - `output/materials/a_red_sports_car_metallic.png` - Chrome/metal parts
   - `output/materials/a_red_sports_car_bump.png` - Surface details

4. **Use in 3D Software:**
   - Import PLY into Blender
   - Create PBR material
   - Load material maps
   - Render or export

---

## Performance Notes

### Apple Silicon (M1/M2/M3/M4):
- ✅ **Optimized:** Shap-E uses MPS (Metal Performance Shaders) for GPU acceleration
- ✅ **Fast:** Text-to-3D generation: 1-3 minutes
- ✅ **Material Generation:** Works in simplified mode
- ⚠️ **NeRF:** May not work (TensorFlow 1.15 limitation)

### Intel Macs:
- ✅ **Supported:** Falls back to CPU mode
- ⚠️ **Slower:** Generation takes 3-5 minutes
- ⚠️ **No GPU:** No CUDA support

### CUDA GPUs (NVIDIA):
- ✅ **Fastest:** Full GPU acceleration
- ✅ **NeRF:** Works with TensorFlow 1.15
- ✅ **Materials:** Full MaterialAnything pipeline

---

## Troubleshooting

### "Python environment not found"
- Run: `./setup.sh` to create the virtual environment

### "MaterialAnything models not found"
- Run: `./download_material_models.sh`
- Or disable material generation

### NeRF not working on Apple Silicon
- Expected behavior - TensorFlow 1.15 doesn't support M-Series chips
- Use modern NeRF implementations like nerfstudio instead

### Slow generation
- First generation downloads models (~2GB) - be patient
- Ensure you're using Apple Silicon for best performance
- Check that MPS is being used (check status messages)

---

## File Structure After Generation

```
Prometheus/
├── output/
│   ├── your_model.ply          # 3D mesh
│   ├── your_model.usdz         # iPhone/Vision Pro format
│   └── materials/               # Material maps (if generated)
│       ├── your_model_albedo.png
│       ├── your_model_roughness.png
│       ├── your_model_metallic.png
│       └── your_model_bump.png
├── env/                         # Python environment
└── ...
```

---

## Quick Reference

| Feature | Input | Output | Time | Apple Silicon |
|---------|-------|--------|------|---------------|
| Text-to-3D | Text prompt | PLY + USDZ | 1-3 min | ✅ Optimized |
| Image-to-3D | Single image | PLY + USDZ | 1-3 min | ✅ Optimized |
| NeRF | Multiple images | PLY + Video | Hours | ⚠️ May not work |
| Materials | 3D model | PBR maps | +2-5 min | ✅ Simplified mode |

---

For more details, see the [README.md](README.md).

