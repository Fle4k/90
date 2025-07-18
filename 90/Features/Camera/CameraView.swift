import SwiftUI

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    Spacer()
                    // Full-width camera preview area (16:9)
                    RealCameraPreviewArea(
                        cameraManager: viewModel.cameraManager,
                        geometry: geometry
                    )
                    
                    // Timer and zoom controls directly below preview
                    HStack {
                        // Timer on left
                        Text(viewModel.formattedDuration)
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // Zoom controls on right
                        HStack(spacing: 40) {
                            Button(action: {
                                viewModel.zoomOut()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.4))
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: "minus")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(width: 60, height: 60) // Larger tap area
                            
                            Button(action: {
                                viewModel.zoomIn()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.4))
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: "plus")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(width: 60, height: 60) // Larger tap area
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    // More space before ring menu
                    Spacer()
                    
                    // Ring menu with PDF background and 8 buttons
                    RingMenuView(
                        isRecording: viewModel.isRecording,
                        onRecordTap: {
                            viewModel.toggleRecording()
                        },
                        viewModel: viewModel
                    )
                    .padding(.bottom, 50)
                }
                
                // Save status overlay
                if viewModel.isSavingToLibrary || viewModel.lastSaveStatus != nil {
                    VStack {
                        Spacer()
                        
                        if viewModel.isSavingToLibrary {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                
                                Text("Saving to camera roll...")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(20)
                        } else if let status = viewModel.lastSaveStatus {
                            Text(status)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(20)
                        }
                        
                        Spacer()
                            .frame(height: 120) // Space above controls
                    }
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.isSavingToLibrary)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.lastSaveStatus != nil)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.requestPermissions()
        }
    }
}

// MARK: - Real Camera Preview Area
struct RealCameraPreviewArea: View {
    let cameraManager: CameraManager
    let geometry: GeometryProxy
    
    private var previewHeight: CGFloat {
        geometry.size.width / (16/9) // 16:9 aspect ratio
    }
    
    var body: some View {
        ZStack {
            // Real camera preview
            CameraPreview(cameraManager: cameraManager)
                .frame(width: geometry.size.width, height: previewHeight)
                .clipped() // Crop to 16:9 ratio
            
            // Optional: 16:9 crop indicator (subtle overlay)
            Rectangle()
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                .frame(width: geometry.size.width, height: previewHeight)
        }
        .clipped()
    }
}

// MARK: - Ring Menu with PDF Background and 8 Buttons
struct RingMenuView: View {
    let isRecording: Bool
    let onRecordTap: () -> Void
    let viewModel: CameraViewModel
    
    private let buttonRadius: CGFloat = 112 // Decreased from 130 to bring icons closer
    private let buttonSize: CGFloat = 44
    
    var body: some View {
        ZStack {
            // PDF Background for ring menu
            Image(isRecording ? "90RecordButtonON" : "90RecordButtonOff")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 300, height: 300)
            
            // 8 control buttons positioned around the circle
            ForEach(0..<8, id: \.self) { index in
                ControlButtonView(
                    sfSymbol: controlSymbols[index],
                    size: buttonSize,
                    action: getButtonAction(for: index)
                )
                .offset(
                    x: cos(Double(index) * .pi / 4 - .pi / 2) * buttonRadius,
                    y: sin(Double(index) * .pi / 4 - .pi / 2) * buttonRadius
                )
            }
            
            // Invisible tappable area for record button (using PDF background)
            Button(action: onRecordTap) {
                Circle()
                    .fill(Color.clear)  // Invisible
                    .frame(width: 70, height: 70)  // Same size as original red button
            }
        }
    }
    
    private var controlSymbols: [String] {
        [
            "arrow.triangle.2.circlepath.camera",  // Camera flip (top)
            viewModel.isFlashlightOn ? "bolt.fill" : "bolt.slash", // Flashlight toggle (top right)
            viewModel.isScreenDimmed ? "sun.min.fill" : "sun.max", // Screen dimming toggle (right)
            "ellipsis",                            // Three dots menu (bottom right)
            "photo.on.rectangle",                  // Gallery (bottom)
            "square.and.arrow.up",                 // Share (bottom left)
            "film.stack",                          // Settings (left)
            viewModel.isAudioEnabled ? "speaker.wave.2" : "speaker.slash" // Audio toggle (top left)
        ]
    }
    
    private func getButtonAction(for index: Int) -> () -> Void {
        switch index {
        case 0: // Camera flip
            return { viewModel.flipCamera() }
        case 1: // Flashlight toggle
            return { viewModel.toggleFlashlight() }
        case 2: // Screen dimming toggle
            return { viewModel.toggleScreenDimming() }
        case 3: // Three dots menu
            return { /* TODO: Implement menu */ }
        case 4: // Gallery
            return { /* TODO: Implement gallery */ }
        case 5: // Share
            return { /* TODO: Implement share */ }
        case 6: // Settings
            return { /* TODO: Implement settings */ }
        case 7: // Audio toggle
            return { viewModel.toggleAudio() }
        default:
            return { }
        }
    }
}

// MARK: - Control Button
struct ControlButtonView: View {
    let sfSymbol: String
    let size: CGFloat
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: size, height: size)
                
                Image(systemName: sfSymbol)
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }
}

#Preview {
    CameraView()
} 
