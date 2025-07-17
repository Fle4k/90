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
                    // Timer Display
                    TimerDisplayView(duration: viewModel.formattedDuration)
                        .padding(.top, 60)
                    
                    Spacer()
                    
                    // 16:9 Preview Area
                    CameraPreviewArea(
                        showsCropOverlay: viewModel.showsCropOverlay,
                        geometry: geometry
                    )
                    
                    Spacer()
                    
                    // Circular Controls
                    CircularControlsView(viewModel: viewModel)
                        .frame(height: CameraConfiguration.controlsHeight)
                        .padding(.bottom, 50)
                }
            }
        }
        .environmentObject(viewModel)
    }
}

// MARK: - Timer Display
struct TimerDisplayView: View {
    let duration: String
    
    var body: some View {
        Text(duration)
            .font(.system(size: UIConstants.timerFontSize, weight: .medium, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
            )
    }
}

// MARK: - Preview Area
struct CameraPreviewArea: View {
    let showsCropOverlay: Bool
    let geometry: GeometryProxy
    
    private var previewSize: CGSize {
        let width = geometry.size.width - 40
        let height = width / CameraConfiguration.aspectRatio
        return CGSize(width: width, height: height)
    }
    
    var body: some View {
        ZStack {
            // Camera Preview (placeholder for now)
            RoundedRectangle(cornerRadius: CameraConfiguration.previewCornerRadius)
                .fill(Color.gray.opacity(0.3))
                .frame(width: previewSize.width, height: previewSize.height)
                .overlay(
                    Image(systemName: "camera")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.6))
                )
            
            // 16:9 Crop Overlay
            if showsCropOverlay {
                RoundedRectangle(cornerRadius: CameraConfiguration.previewCornerRadius)
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: previewSize.width, height: previewSize.height)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Circular Controls
struct CircularControlsView: View {
    @ObservedObject var viewModel: CameraViewModel
    
    var body: some View {
        ZStack {
            // Control buttons around the circle
            ForEach(CameraAction.allCases, id: \.self) { action in
                ControlButton(action: action) {
                    handleControlAction(action)
                }
                .offset(
                    x: cos(action.angle * .pi / 180) * UIConstants.controlCircleRadius,
                    y: sin(action.angle * .pi / 180) * UIConstants.controlCircleRadius
                )
            }
            
            // Central record button
            RecordButton(
                isRecording: viewModel.isRecording,
                canRecord: viewModel.canRecord
            ) {
                toggleRecording()
            }
        }
    }
    
    private func handleControlAction(_ action: CameraAction) {
        switch action {
        case .toggleCamera:
            viewModel.toggleCamera()
        case .toggleFlash:
            // TODO: Implement flash toggle
            break
        case .showGallery:
            // TODO: Implement gallery
            break
        case .showSettings:
            // TODO: Implement settings
            break
        case .toggleMute:
            // TODO: Implement mute toggle
            break
        case .share:
            // TODO: Implement share
            break
        }
    }
    
    private func toggleRecording() {
        if viewModel.isRecording {
            viewModel.stopRecording()
        } else {
            viewModel.startRecording()
        }
    }
}

// MARK: - Control Button
struct ControlButton: View {
    let action: CameraAction
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Image(systemName: action.sfSymbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
                .frame(width: UIConstants.controlButtonSize, height: UIConstants.controlButtonSize)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .blur(radius: 0.5)
                )
        }
    }
}

// MARK: - Record Button
struct RecordButton: View {
    let isRecording: Bool
    let canRecord: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: UIConstants.recordButtonSize + 20, height: UIConstants.recordButtonSize + 20)
                
                Circle()
                    .fill(isRecording ? Color.red : Color.red.opacity(0.8))
                    .frame(width: UIConstants.recordButtonSize, height: UIConstants.recordButtonSize)
                    .scaleEffect(isRecording ? 0.8 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isRecording)
                
                if isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                } else {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .disabled(!canRecord && !isRecording)
    }
}

#Preview {
    CameraView()
} 