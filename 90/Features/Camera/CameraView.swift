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
                    CameraPreviewArea(geometry: geometry)
                    
                    // Timer and zoom controls directly below preview
                    HStack {
                        // Timer on left
                        Text(viewModel.formattedDuration)
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // Zoom controls on right
                        HStack(spacing: 60) {
                            Button(action: {}) {
                                Image(systemName: "minus")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            
                            Button(action: {}) {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
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
                        }
                    )
                    .padding(.bottom, 50)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.requestPermissions()
        }
    }
}

// MARK: - Camera Preview Area
struct CameraPreviewArea: View {
    let geometry: GeometryProxy
    
    private var previewHeight: CGFloat {
        geometry.size.width / (16/9) // 16:9 aspect ratio
    }
    
    var body: some View {
        ZStack {
            // Camera preview background - will be replaced with actual camera
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.6),
                            Color.teal.opacity(0.8),
                            Color.green.opacity(0.4)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: geometry.size.width, height: previewHeight)
            
            // Landscape preview content (simulating your target image)
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.7))
        }
        .clipped()
    }
}

// MARK: - Ring Menu with PDF Background and 8 Buttons
struct RingMenuView: View {
    let isRecording: Bool
    let onRecordTap: () -> Void
    
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
                    size: buttonSize
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
            "bolt.slash",                           // Microphone (top right)
            "photo",                               // Video mode (right)
            "sun.max",                           // dim (bottom right)
            "photo.on.rectangle",                  // Gallery (bottom)
            "square.and.arrow.up",                 // Share (bottom left)
            "film.stack",                           // Settings (left)
            "speaker.slash"                           // Mute (top left)
        ]
    }
}

// MARK: - Control Button
struct ControlButtonView: View {
    let sfSymbol: String
    let size: CGFloat
    
    var body: some View {
        Button(action: {
            // Handle action
        }) {
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
