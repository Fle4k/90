import SwiftUI
import AVFoundation

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
                    // 16:9 camera preview area (cropped view)
                    RealCameraPreviewArea(
                        cameraManager: viewModel.cameraManager,
                        geometry: geometry,
                        isRecording: viewModel.isRecording
                    )
                    
                    // Timer and lens controls directly below preview
                    HStack {
                        // Timer on left
                        Text(viewModel.formattedDuration)
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // Lens selection buttons like native Camera app
                        LensSelectionView(viewModel: viewModel)
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
                
                // Status overlays moved to TOP of screen
                if viewModel.isProcessingVideo || viewModel.isSavingToLibrary || viewModel.lastSaveStatus != nil {
                    VStack {
                        // Status at the top
                        if viewModel.isProcessingVideo {
                            VStack(spacing: 12) {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(viewModel.processingStatus ?? "Processing video...")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white)
                                        
                                        // Progress bar
                                        HStack {
                                            Rectangle()
                                                .fill(Color.white)
                                                .frame(width: CGFloat(viewModel.processingProgress) * 120, height: 3)
                                                .animation(.easeInOut(duration: 0.3), value: viewModel.processingProgress)
                                        
                                            Rectangle()
                                                .fill(Color.white.opacity(0.3))
                                                .frame(height: 3)
                                        }
                                        .frame(width: 120, height: 3)
                                        .clipShape(Capsule())
                                        
                                        Text("\(Int(viewModel.processingProgress * 100))%")
                                            .font(.system(size: 12, weight: .regular))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(24)
                        } else if viewModel.isSavingToLibrary {
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
                        
                        Spacer() // Push content to top
                    }
                    .padding(.top, 60) // Safe area padding
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.isProcessingVideo)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.isSavingToLibrary)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.lastSaveStatus != nil)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.requestPermissions()
            viewModel.startCameraSession()
        }
    }
}

// MARK: - Real Camera Preview Area
struct RealCameraPreviewArea: View {
    let cameraManager: CameraManager
    let geometry: GeometryProxy
    let isRecording: Bool
    
    // 16:9 crop area dimensions - only show this area
    private var cropWidth: CGFloat {
        geometry.size.width
    }
    
    private var cropHeight: CGFloat {
        cropWidth / (16/9) // 16:9 aspect ratio
    }
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .frame(width: cropWidth, height: cropHeight)
            
            // Camera preview - cropped to show only 16:9 area
            CameraPreview(cameraManager: cameraManager)
                .frame(width: cropWidth, height: cropHeight)
                .clipped()
            
            // Recording border - white normally, red when recording
            Rectangle()
                .stroke(isRecording ? Color.red : Color.white.opacity(0.3), lineWidth: isRecording ? 3 : 1)
                .frame(width: cropWidth, height: cropHeight)
                .animation(.easeInOut(duration: 0.2), value: isRecording)
        }
        .frame(width: cropWidth, height: cropHeight)
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
            backgroundImage
            buttonCircle
            recordButton
        }
    }
    
    private var backgroundImage: some View {
        Image(isRecording ? "90RecordButtonON" : "90RecordButtonOff")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 300, height: 300)
    }
    
    private var buttonCircle: some View {
        ForEach(0..<6, id: \.self) { index in
            createControlButton(at: index)
        }
    }
    
    private var recordButton: some View {
        Button(action: onRecordTap) {
            Circle()
                .fill(Color.clear)
                .frame(width: 70, height: 70)
        }
    }
    
    private func createControlButton(at index: Int) -> some View {
        let symbol = controlSymbols[index]
        let action = getButtonAction(for: index)
        let angle = Double(index) * .pi / 3 - .pi / 2
        let xPos = cos(angle) * buttonRadius
        let yPos = sin(angle) * buttonRadius
        
        return ControlButtonView(
            sfSymbol: symbol,
            size: buttonSize,
            action: action
        )
        .offset(x: xPos, y: yPos)
    }
    
    private var controlSymbols: [String] {
        var symbols = [String]()
        symbols.append("arrow.triangle.2.circlepath.camera")  // Camera flip (top)
        symbols.append(viewModel.isFlashlightOn ? "bolt.fill" : "bolt.slash") // Flashlight toggle (top right)
        symbols.append(viewModel.isScreenDimmed ? "sun.min.fill" : "sun.max") // Screen dimming toggle (right)
        symbols.append("photo.on.rectangle")                  // Gallery (bottom right)
        symbols.append("ellipsis")                            // Three dots menu (bottom)
        symbols.append(viewModel.isAudioEnabled ? "speaker.wave.2" : "speaker.slash") // Audio toggle (bottom left)
        return symbols
    }
    
    private func getButtonAction(for index: Int) -> () -> Void {
        switch index {
        case 0: // Camera flip
            return { viewModel.flipCamera() }
        case 1: // Flashlight toggle
            return { viewModel.toggleFlashlight() }
        case 2: // Screen dimming toggle
            return { viewModel.toggleScreenDimming() }
        case 3: // Gallery
            return { /* TODO: Implement gallery */ }
        case 4: // Three dots menu
            return { /* TODO: Implement menu */ }
        case 5: // Audio toggle
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

// MARK: - Lens Selection View
struct LensSelectionView: View {
    @ObservedObject var viewModel: CameraViewModel
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(viewModel.availableLenses, id: \.self) { lensType in
                LensButton(
                    lensType: lensType,
                    isSelected: viewModel.currentLensType == lensType,
                    onTap: {
                        viewModel.switchToLens(lensType)
                    }
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.3))
        )
    }
}

// MARK: - Individual Lens Button
struct LensButton: View {
    let lensType: AVCaptureDevice.DeviceType
    let isSelected: Bool
    let onTap: () -> Void
    
    private var displayText: String {
        switch lensType {
        case .builtInUltraWideCamera:
            return "0,5"
        case .builtInWideAngleCamera:
            return "2×" // Main camera on iPhone 15 (24mm)
        case .builtInTelephotoCamera:
            return "3" // Telephoto if available
        default:
            return "2×"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            Text(displayText)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(isSelected ? .black : .white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(isSelected ? Color.yellow : Color.clear)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Color.clear : Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    CameraView()
} 
