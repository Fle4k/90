import SwiftUI
import AVFoundation

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    
    private func getProgressText() -> String {
        if viewModel.isProcessingVideo {
            return viewModel.processingStatus ?? "Processing video..."
        } else if viewModel.isSavingToLibrary {
            return "Saving to camera roll..."
        } else if let status = viewModel.lastSaveStatus {
            return status
        }
        return ""
    }
    
    private func shouldShowPulse() -> Bool {
        return viewModel.isProcessingVideo || viewModel.isSavingToLibrary
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // Progress information above video frame, below safe zone
                    VStack(spacing: 0) {
                        if viewModel.isProcessingVideo || viewModel.isSavingToLibrary || viewModel.lastSaveStatus != nil {
                            Text(getProgressText())
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.black.opacity(0.8))
                                .cornerRadius(20)
                                .modifier(PulseAnimation(isActive: shouldShowPulse()))
                        } else {
                            // Hidden placeholder to maintain consistent spacing
                            Color.clear
                                .frame(height: 44) // Fixed height for all progress states
                        }
                    }
                    .padding(.top, 20)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.isProcessingVideo)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.isSavingToLibrary)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.lastSaveStatus != nil)
                    
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
                    
                    // Ring menu with PDF background and 6 buttons
                    RingMenuView(
                        isRecording: viewModel.isRecording,
                        onRecordTap: {
                            viewModel.toggleRecording()
                        },
                        viewModel: viewModel
                    )
                    .padding(.bottom, 50)
                }
                
                // Screen dimming overlay
                if viewModel.isScreenDimmed {
                    Color.black.opacity(0.8)
                        .ignoresSafeArea()
                        .allowsHitTesting(false) // Allow taps to pass through to buttons underneath
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.isScreenDimmed)
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
    @State private var showingSettings = false
    
    private let buttonRadius: CGFloat = 112 // Decreased from 130 to bring icons closer
    private let buttonSize: CGFloat = 44
    
    var body: some View {
        ZStack {
            backgroundImage
            buttonCircle
            recordButton
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheetView()
                .preferredColorScheme(.dark)
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
            return { 
                // Open the camera roll directly
                if let url = URL(string: "photos-redirect://") {
                    UIApplication.shared.open(url)
                }
            }
        case 4: // Three dots menu
            return { showingSettings = true }
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
                    .fill(Color.black.opacity(0.18))
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
                        .fill(isSelected ? Color.gray : Color.clear)
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

// MARK: - Settings Sheet View
struct SettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                settingsList
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                }
            }
        }
        .tint(.white)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Settings List
    private var settingsList: some View {
        List {
            // Settings Section
            Section {
                startRecordingToggle
                placeholderToggle1
                placeholderToggle2
            }
            
            // App Info Section
            Section {
                // Logo
                HStack {
                    Spacer()
                    Image("metame_Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 160)
                        .padding(.vertical, 8)
                        .onTapGesture {
                            if let url = URL(string: "https://www.metame.de") {
                                openURL(url)
                            }
                        }
                    Spacer()
                }
                .listRowBackground(Color.clear)
                
                appVersionRow
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.black)
    }
    
    // MARK: - Toggle Rows
    @State private var startRecordingOnLaunch = false
    @State private var placeholderToggle1State = false
    @State private var placeholderToggle2State = false
    
    private var startRecordingToggle: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Record on launch")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text("Automatically start recording when the app opens")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Toggle("", isOn: $startRecordingOnLaunch)
                .toggleStyle(.switch)
                .tint(.white)
        }
        .padding(.vertical, 4)
    }
    
    private var placeholderToggle1: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Lorem Ipsum Dolor")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text("This is a placeholder setting for future features")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Toggle("", isOn: $placeholderToggle1State)
                .toggleStyle(.switch)
                .tint(.white)
        }
        .padding(.vertical, 4)
    }
    
    private var placeholderToggle2: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("mauris rhoncus")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text("Another placeholder setting for future features")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Toggle("", isOn: $placeholderToggle2State)
                .toggleStyle(.switch)
                .tint(.white)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - App Version Row
    private var appVersionRow: some View {
        VStack(spacing: 2) {
            Text("Version")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            Text("1.0")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .listRowBackground(Color.clear)
    }
}

#Preview {
    CameraView()
}

// MARK: - Pulse Animation Modifier
struct PulseAnimation: ViewModifier {
    let isActive: Bool
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive ? (isAnimating ? 1.05 : 1.0) : 1.0)
            .opacity(isActive ? (isAnimating ? 0.8 : 1.0) : 1.0)
            .onAppear {
                if isActive {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        isAnimating = true
                    }
                }
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        isAnimating = true
                    }
                } else {
                    isAnimating = false
                }
            }
    }
} 
