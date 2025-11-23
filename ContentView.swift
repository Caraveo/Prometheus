import SwiftUI

struct ContentView: View {
    @State private var prompt: String = ""
    @State private var selectedMode: GenerationMode = .textTo3D
    @State private var isGenerating: Bool = false
    @State private var statusMessage: String = ""
    @State private var outputPath: String? = nil
    @State private var dragOver: Bool = false
    @State private var droppedImagePath: String = ""
    @State private var generateMaterials: Bool = false
    @State private var materialPaths: [String: String] = [:]
    @State private var nerfImagesDir: String = ""
    
    enum GenerationMode: String, CaseIterable {
        case textTo3D = "Text to 3D"
        case imageTo3D = "Image to 3D"
        case nerf = "NeRF (Multi-Image)"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Main Content
            ScrollView {
                VStack(spacing: 24) {
                    // Mode Selection
                    modeSelectionView
                    
                    // Material Generation Option
                    materialGenerationView
                    
                    // Input Section
                    inputSectionView
                    
                    // Generate Button
                    generateButton
                    
                    // Status and Output
                    statusView
                }
                .padding(32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 600, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "cube.transparent")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.blue)
            
            Text("Prometheus 3D Generator")
                .font(.system(size: 20, weight: .bold))
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var modeSelectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Generation Mode")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            
            Picker("Mode", selection: $selectedMode) {
                ForEach(GenerationMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var materialGenerationView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $generateMaterials) {
                HStack(spacing: 8) {
                    Image(systemName: "paintbrush.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Generate Materials")
                            .font(.system(size: 14, weight: .semibold))
                        Text("PBR maps (albedo, roughness, metallic, bump)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .toggleStyle(.switch)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var inputSectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if selectedMode == .textTo3D {
                textInputView
            } else if selectedMode == .imageTo3D {
                imageInputView
            } else if selectedMode == .nerf {
                nerfInputView
            }
        }
    }
    
    private var textInputView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Enter your prompt")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            
            TextEditor(text: $prompt)
                .font(.system(size: 14))
                .frame(height: 120)
                .padding(12)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
                .overlay(
                    Group {
                        if prompt.isEmpty {
                            Text("Describe the 3D object you want to create...")
                                .foregroundColor(.secondary)
                                .padding(.leading, 16)
                                .padding(.top, 20)
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
        }
    }
    
    private var imageInputView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Drop an image or enter a prompt")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(dragOver ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                dragOver ? Color.blue : Color(NSColor.separatorColor),
                                lineWidth: dragOver ? 2 : 1
                            )
                    )
                    .frame(height: 200)
                
                VStack(spacing: 12) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    if droppedImagePath.isEmpty {
                        Text("Drag and drop an image here")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Image: \(URL(fileURLWithPath: droppedImagePath).lastPathComponent)")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                            .lineLimit(1)
                    }
                }
            }
            .onDrop(of: [.image], isTargeted: $dragOver) { providers in
                handleImageDrop(providers: providers)
            }
            
            TextEditor(text: $prompt)
                .font(.system(size: 14))
                .frame(height: 80)
                .padding(12)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
                .overlay(
                    Group {
                        if prompt.isEmpty {
                            Text("Optional: Additional prompt details...")
                                .foregroundColor(.secondary)
                                .padding(.leading, 16)
                                .padding(.top, 12)
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
        }
    }
    
    private var generateButton: some View {
        Button(action: generate3D) {
            HStack {
                if isGenerating {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(.circular)
                } else {
                    Image(systemName: "sparkles")
                }
                
                Text(isGenerating ? "Generating..." : "Generate 3D Model")
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(isGenerating ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(isGenerating || (selectedMode == .textTo3D && prompt.isEmpty) || (selectedMode == .imageTo3D && droppedImagePath.isEmpty))
        .buttonStyle(.plain)
    }
    
    private var statusView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !statusMessage.isEmpty {
                HStack {
                    Image(systemName: statusMessage.contains("Error") ? "exclamationmark.triangle.fill" : "info.circle.fill")
                        .foregroundColor(statusMessage.contains("Error") ? .red : .blue)
                    
                    Text(statusMessage)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            
            if let outputPath = outputPath, !outputPath.isEmpty {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: outputPath.hasSuffix(".usdz") ? "cube.transparent.fill" : "checkmark.circle.fill")
                            .foregroundColor(outputPath.hasSuffix(".usdz") ? .blue : .green)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Output: \(URL(fileURLWithPath: outputPath).lastPathComponent)")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            
                            if outputPath.hasSuffix(".usdz") {
                                Text("Ready for iPhone/Vision Pro")
                                    .font(.system(size: 11))
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            NSWorkspace.shared.selectFile(outputPath, inFileViewerRootedAtPath: "")
                        }) {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Material maps display
                    if !materialPaths.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Material Maps:")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            ForEach(Array(materialPaths.keys.sorted()), id: \.self) { key in
                                if let path = materialPaths[key] {
                                    HStack {
                                        Image(systemName: "paintbrush.fill")
                                            .foregroundColor(.orange)
                                            .font(.system(size: 10))
                                        
                                        Text(key.capitalized)
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                                        }) {
                                            Image(systemName: "folder.fill")
                                                .foregroundColor(.blue)
                                                .font(.system(size: 10))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
        }
    }
    
    private func handleImageDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        if provider.canLoadObject(ofClass: NSImage.self) {
            provider.loadObject(ofClass: NSImage.self) { image, error in
                DispatchQueue.main.async {
                    if let nsImage = image as? NSImage {
                        saveDroppedImage(nsImage)
                    }
                }
            }
            return true
        }
        
        if provider.hasItemConformingToTypeIdentifier("public.file-url") {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        droppedImagePath = url.path
                    }
                }
            }
            return true
        }
        
        return false
    }
    
    private func saveDroppedImage(_ image: NSImage) {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "input_image_\(UUID().uuidString).png"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        if let tiffData = image.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImage.representation(using: .png, properties: [:]) {
            try? pngData.write(to: fileURL)
            droppedImagePath = fileURL.path
        }
    }
    
    private func generate3D() {
        // Validate NeRF input
        if selectedMode == .nerf {
            if nerfImagesDir.isEmpty {
                statusMessage = "Error: Please select an images directory for NeRF"
                return
            }
            if !FileManager.default.fileExists(atPath: nerfImagesDir) {
                statusMessage = "Error: Images directory not found: \(nerfImagesDir)"
                return
            }
        }
        
        isGenerating = true
        statusMessage = "Initializing generation..."
        outputPath = nil
        materialPaths = [:]
        
        // Get the script path - try bundle first, then current directory
        let scriptName = "shap_e_generator.py"
        let pythonScript: String
        let baseDir: String
        
        if let bundlePath = Bundle.main.path(forResource: "shap_e_generator", ofType: "py") {
            pythonScript = bundlePath
            // If running from bundle, get the bundle's parent directory (project root)
            let bundleURL = Bundle.main.bundleURL
            baseDir = bundleURL.deletingLastPathComponent().path
        } else {
            // Fallback to current directory
            baseDir = FileManager.default.currentDirectoryPath
            pythonScript = (baseDir as NSString).appendingPathComponent(scriptName)
        }
        
        // Get environment path relative to base directory
        let envPath = (baseDir as NSString).appendingPathComponent("env")
        
        Task {
            do {
                let result: (success: Bool, outputPath: String?, error: String?, materialPaths: [String: String])
                
                if selectedMode == .nerf {
                    // NeRF uses different script
                    result = try await runNeRFScript(
                        imagesDir: nerfImagesDir,
                        envPath: envPath
                    )
                } else {
                    result = try await runPythonScript(
                        scriptPath: pythonScript,
                        envPath: envPath,
                        mode: selectedMode,
                        prompt: prompt,
                        imagePath: selectedMode == .imageTo3D ? droppedImagePath : nil,
                        generateMaterials: generateMaterials
                    )
                }
                
                await MainActor.run {
                    isGenerating = false
                    if result.success {
                        statusMessage = "3D model generated successfully!"
                        outputPath = result.outputPath
                        materialPaths = result.materialPaths
                        if !result.materialPaths.isEmpty {
                            statusMessage += " Materials generated!"
                        }
                    } else {
                        statusMessage = "Error: \(result.error ?? "Unknown error")"
                    }
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    statusMessage = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func runPythonScript(
        scriptPath: String,
        envPath: String,
        mode: GenerationMode,
        prompt: String,
        imagePath: String?,
        generateMaterials: Bool = false
    ) async throws -> (success: Bool, outputPath: String?, error: String?, materialPaths: [String: String]) {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Create a status update callback
                let updateStatus: (String) -> Void = { message in
                    Task { @MainActor in
                        self.statusMessage = message
                    }
                }
                let process = Process()
                let pipe = Pipe()
                let errorPipe = Pipe()
                
                // Use Python from the virtual environment
                let pythonExecutable = "\(envPath)/bin/python3"
                
                // Check if virtual environment exists
                if !FileManager.default.fileExists(atPath: pythonExecutable) {
                    continuation.resume(returning: (false, nil, "Python environment not found at \(envPath). Please create it first.", [:]))
                    return
                }
                
                process.executableURL = URL(fileURLWithPath: pythonExecutable)
                process.standardOutput = pipe
                process.standardError = errorPipe
                
                var arguments = [scriptPath]
                arguments.append("--mode")
                arguments.append(mode == .textTo3D ? "text" : "image")
                arguments.append("--prompt")
                arguments.append(prompt)
                
                if let imagePath = imagePath {
                    arguments.append("--image")
                    arguments.append(imagePath)
                }
                
                if generateMaterials {
                    arguments.append("--generate-materials")
                }
                
                process.arguments = arguments
                
                // Set working directory to script location
                let scriptDir = (scriptPath as NSString).deletingLastPathComponent
                process.currentDirectoryURL = URL(fileURLWithPath: scriptDir)
                
                // Create output directory if it doesn't exist
                let outputDir = (scriptDir as NSString).appendingPathComponent("output")
                try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
                
                // Set up notification observers for real-time output
                var errorLines: [String] = []
                
                let outputHandle = pipe.fileHandleForReading
                let errorHandle = errorPipe.fileHandleForReading
                
                // Read stderr in real-time for progress updates
                errorHandle.readabilityHandler = { handle in
                    let data = handle.availableData
                    if data.isEmpty { return }
                    
                    if let text = String(data: data, encoding: .utf8) {
                        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
                        errorLines.append(contentsOf: lines)
                        
                        // Update status with latest progress message
                        if let lastLine = lines.last, !lastLine.isEmpty {
                            // Update status message with progress
                            if lastLine.contains("Loading") || lastLine.contains("Loading Shap-E") {
                                updateStatus("Loading models...")
                            } else if lastLine.contains("Generating") {
                                updateStatus("Generating 3D model...")
                            } else if lastLine.contains("Sampling") || lastLine.contains("Starting diffusion") {
                                updateStatus("Running diffusion sampling...")
                            } else if lastLine.contains("Decoding") {
                                updateStatus("Decoding mesh...")
                            } else if lastLine.contains("Saving") {
                                updateStatus("Saving mesh...")
                            } else if lastLine.contains("✓") {
                                // Keep the checkmark message briefly
                                updateStatus(lastLine)
                            } else if !lastLine.contains("Using device") && !lastLine.contains("FutureWarning") {
                                // Update with other progress messages (skip warnings)
                                updateStatus(lastLine)
                            }
                        }
                    }
                }
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    // Close handles
                    outputHandle.readabilityHandler = nil
                    errorHandle.readabilityHandler = nil
                    
                    let outputData = outputHandle.readDataToEndOfFile()
                    let remainingErrorData = errorHandle.readDataToEndOfFile()
                    
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    if let remainingError = String(data: remainingErrorData, encoding: .utf8), !remainingError.isEmpty {
                        errorLines.append(contentsOf: remainingError.components(separatedBy: .newlines).filter { !$0.isEmpty })
                    }
                    
                    let errorOutput = errorLines.joined(separator: "\n")
                    
                    if process.terminationStatus == 0 {
                        // Extract output path from the output
                        let lines = output.components(separatedBy: .newlines)
                        var outputPath: String? = nil
                        var usdzPath: String? = nil
                        var materialPaths: [String: String] = [:]
                        
                        for line in lines {
                            if line.contains("OUTPUT_PATH:") {
                                let path = line.components(separatedBy: "OUTPUT_PATH:").last?.trimmingCharacters(in: .whitespaces) ?? ""
                                if !path.isEmpty {
                                    if (path as NSString).isAbsolutePath {
                                        outputPath = path
                                    } else {
                                        outputPath = (scriptDir as NSString).appendingPathComponent(path)
                                    }
                                }
                            } else if line.contains("USDZ_PATH:") {
                                let path = line.components(separatedBy: "USDZ_PATH:").last?.trimmingCharacters(in: .whitespaces) ?? ""
                                if !path.isEmpty {
                                    if (path as NSString).isAbsolutePath {
                                        usdzPath = path
                                    } else {
                                        usdzPath = (scriptDir as NSString).appendingPathComponent(path)
                                    }
                                }
                            } else if line.contains("MATERIAL_ALBEDO:") {
                                let path = line.components(separatedBy: "MATERIAL_ALBEDO:").last?.trimmingCharacters(in: .whitespaces) ?? ""
                                if !path.isEmpty {
                                    materialPaths["albedo"] = (path as NSString).isAbsolutePath ? path : (scriptDir as NSString).appendingPathComponent(path)
                                }
                            } else if line.contains("MATERIAL_ROUGHNESS:") {
                                let path = line.components(separatedBy: "MATERIAL_ROUGHNESS:").last?.trimmingCharacters(in: .whitespaces) ?? ""
                                if !path.isEmpty {
                                    materialPaths["roughness"] = (path as NSString).isAbsolutePath ? path : (scriptDir as NSString).appendingPathComponent(path)
                                }
                            } else if line.contains("MATERIAL_METALLIC:") {
                                let path = line.components(separatedBy: "MATERIAL_METALLIC:").last?.trimmingCharacters(in: .whitespaces) ?? ""
                                if !path.isEmpty {
                                    materialPaths["metallic"] = (path as NSString).isAbsolutePath ? path : (scriptDir as NSString).appendingPathComponent(path)
                                }
                            } else if line.contains("MATERIAL_BUMP:") {
                                let path = line.components(separatedBy: "MATERIAL_BUMP:").last?.trimmingCharacters(in: .whitespaces) ?? ""
                                if !path.isEmpty {
                                    materialPaths["bump"] = (path as NSString).isAbsolutePath ? path : (scriptDir as NSString).appendingPathComponent(path)
                                }
                            }
                        }
                        
                        // If USDZ exists, prefer showing it (for iPhone/Vision Pro)
                        if let usdzPath = usdzPath, FileManager.default.fileExists(atPath: usdzPath) {
                            outputPath = usdzPath
                        }
                        
                        continuation.resume(returning: (true, outputPath, nil, materialPaths))
                    } else {
                        let errorMsg = errorOutput.isEmpty ? "Process failed with status \(process.terminationStatus)" : errorOutput
                        continuation.resume(returning: (false, nil, errorMsg, [:]))
                    }
                } catch {
                    outputHandle.readabilityHandler = nil
                    errorHandle.readabilityHandler = nil
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func runNeRFScript(
        imagesDir: String,
        envPath: String
    ) async throws -> (success: Bool, outputPath: String?, error: String?, materialPaths: [String: String]) {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()
                let errorPipe = Pipe()
                
                let pythonExecutable = "\(envPath)/bin/python3"
                
                if !FileManager.default.fileExists(atPath: pythonExecutable) {
                    continuation.resume(returning: (false, nil, "Python environment not found at \(envPath). Please create it first.", [:]))
                    return
                }
                
                // Get base directory (same logic as generate3D)
                let baseDir: String
                if Bundle.main.path(forResource: "nerf_generator", ofType: "py") != nil {
                    let bundleURL = Bundle.main.bundleURL
                    baseDir = bundleURL.deletingLastPathComponent().path
                } else {
                    baseDir = FileManager.default.currentDirectoryPath
                }
                
                let scriptPath = (baseDir as NSString).appendingPathComponent("nerf_generator.py")
                if !FileManager.default.fileExists(atPath: scriptPath) {
                    continuation.resume(returning: (false, nil, "NeRF generator script not found at \(scriptPath).", [:]))
                    return
                }
                
                process.executableURL = URL(fileURLWithPath: pythonExecutable)
                process.arguments = [scriptPath, "--images", imagesDir, "--output", "output"]
                process.standardOutput = pipe
                process.standardError = errorPipe
                
                let outputHandle = pipe.fileHandleForReading
                let errorHandle = errorPipe.fileHandleForReading
                
                var outputLines: [String] = []
                var errorLines: [String] = []
                
                outputHandle.readabilityHandler = { handle in
                    let data = handle.availableData
                    if data.isEmpty { return }
                    if let text = String(data: data, encoding: .utf8) {
                        outputLines.append(contentsOf: text.components(separatedBy: .newlines).filter { !$0.isEmpty })
                    }
                }
                
                errorHandle.readabilityHandler = { handle in
                    let data = handle.availableData
                    if data.isEmpty { return }
                    if let text = String(data: data, encoding: .utf8) {
                        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
                        errorLines.append(contentsOf: lines)
                        if let lastLine = lines.last, !lastLine.isEmpty {
                            Task { @MainActor in
                                self.statusMessage = lastLine
                            }
                        }
                    }
                }
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    outputHandle.readabilityHandler = nil
                    errorHandle.readabilityHandler = nil
                    
                    let outputData = outputHandle.readDataToEndOfFile()
                    let remainingErrorData = errorHandle.readDataToEndOfFile()
                    
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    if let remainingError = String(data: remainingErrorData, encoding: .utf8), !remainingError.isEmpty {
                        errorLines.append(contentsOf: remainingError.components(separatedBy: .newlines).filter { !$0.isEmpty })
                    }
                    
                    let errorOutput = errorLines.joined(separator: "\n")
                    
                    if process.terminationStatus == 0 {
                        var outputPath: String? = nil
                        let lines = output.components(separatedBy: .newlines)
                        
                        for line in lines {
                            if line.contains("MESH:") {
                                let path = line.components(separatedBy: "MESH:").last?.trimmingCharacters(in: .whitespaces) ?? ""
                                if !path.isEmpty {
                                    outputPath = (path as NSString).isAbsolutePath ? path : (baseDir as NSString).appendingPathComponent(path)
                                }
                            }
                        }
                        
                        continuation.resume(returning: (true, outputPath, nil, [:]))
                    } else {
                        let errorMsg = errorOutput.isEmpty ? "NeRF process failed with status \(process.terminationStatus)" : errorOutput
                        continuation.resume(returning: (false, nil, errorMsg, [:]))
                    }
                } catch {
                    outputHandle.readabilityHandler = nil
                    errorHandle.readabilityHandler = nil
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

