import SwiftUI
import AVFoundation

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    
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
                // Theme-aware background
                themeBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress information with theme styling
                    VStack(spacing: 0) {
                        if viewModel.isProcessingVideo || viewModel.isSavingToLibrary || viewModel.lastSaveStatus != nil {
                            Text(getProgressText())
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(themeManager.colors.text)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(progressBackground)
                                .modifier(PulseAnimation(isActive: shouldShowPulse()))
                        } else {
                            Color.clear
                                .frame(height: 44)
                        }
                    }
                    .padding(.top, 20)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.isProcessingVideo)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.isSavingToLibrary)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.lastSaveStatus != nil)
                    
                    Spacer()
                    
                    // Camera preview area with theme styling
                    ThemedCameraPreviewArea(
                        cameraManager: viewModel.cameraManager,
                        geometry: geometry,
                        isRecording: viewModel.isRecording,
                        theme: themeManager.currentTheme,
                        colors: themeManager.colors
                    )
                    
                    // Timer and lens controls with theme styling
                    HStack {
                        // Timer with theme design
                        Text(viewModel.formattedDuration)
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .foregroundColor(themeManager.colors.text)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(timerBackground)
                        
                        Spacer()
                        
                        // Lens selection with theme design
                        ThemedLensSelectionView(
                            viewModel: viewModel,
                            theme: themeManager.currentTheme,
                            colors: themeManager.colors
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    Spacer()
                    
                    // Theme-aware ring menu
                    ThemedRingMenuView(
                        isRecording: viewModel.isRecording,
                        onRecordTap: {
                            viewModel.toggleRecording()
                        },
                        viewModel: viewModel,
                        theme: themeManager.currentTheme,
                        colors: themeManager.colors
                    )
                    .padding(.bottom, 50)
                }
                
                // Screen dimming overlay
                if viewModel.isScreenDimmed {
                    Color.black.opacity(themeManager.currentTheme == .dark ? 0.8 : 0.3)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.isScreenDimmed)
                }
            }
        }
        .preferredColorScheme(themeManager.currentTheme.colorScheme)
        .onAppear {
            viewModel.requestPermissions()
            viewModel.startCameraSession()
        }
    }
    
    // MARK: - Theme-specific backgrounds
    @ViewBuilder
    private var themeBackground: some View {
        switch themeManager.currentTheme {
        case .dark:
            themeManager.colors.background
        case .light:
            themeManager.colors.background
        case .neomorphic:
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.95, blue: 0.97), Color(red: 0.98, green: 0.98, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

        }
    }
    
    @ViewBuilder
    private var progressBackground: some View {
        switch themeManager.currentTheme {
        case .dark:
            RoundedRectangle(cornerRadius: 20)
                .fill(themeManager.colors.secondaryBackground)
        case .light:
            RoundedRectangle(cornerRadius: 20)
                .fill(themeManager.colors.secondaryBackground)
        case .neomorphic:
            RoundedRectangle(cornerRadius: 20)
                .fill(themeManager.colors.surface)
                .shadow(color: themeManager.colors.shadow, radius: 8, x: 4, y: 4)
                .shadow(color: themeManager.colors.highlight, radius: 8, x: -4, y: -4)

        }
    }
    
    @ViewBuilder
    private var timerBackground: some View {
        switch themeManager.currentTheme {
        case .dark:
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.colors.surface)
        case .light:
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.colors.surface)
        case .neomorphic:
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.colors.surface)
                .shadow(color: themeManager.colors.shadow, radius: 4, x: 2, y: 2)
                .shadow(color: themeManager.colors.highlight, radius: 4, x: -2, y: -2)

        }
    }
}

// MARK: - Themed Camera Preview Area
struct ThemedCameraPreviewArea: View {
    let cameraManager: CameraManager
    let geometry: GeometryProxy
    let isRecording: Bool
    let theme: AppTheme
    let colors: ThemeColors
    
    private var cropWidth: CGFloat {
        switch theme {
        case .dark:
            return geometry.size.width
        case .light:
            return geometry.size.width
        case .neomorphic:
            return geometry.size.width - 40
        }
    }
    
    private var cropHeight: CGFloat {
        cropWidth / (16/9)
    }
    
    var body: some View {
        ZStack {
            // Theme-specific background
            cameraBackground
                .frame(width: cropWidth, height: cropHeight)
            
            // Camera preview
            CameraPreview(cameraManager: cameraManager)
                .frame(width: previewWidth, height: previewHeight)
                .clipShape(cameraClipShape)
            
            // Recording indicator
            recordingIndicator
        }
        .frame(width: cropWidth, height: cropHeight)
    }
    
    @ViewBuilder
    private var cameraBackground: some View {
        switch theme {
        case .dark:
            Color.black
        case .light:
            Color.black
        case .neomorphic:
            RoundedRectangle(cornerRadius: 20)
                .fill(colors.surface)
                .shadow(color: colors.shadow.opacity(0.15), radius: 12, x: 6, y: 6)
                .shadow(color: colors.highlight.opacity(0.9), radius: 12, x: -6, y: -6)
        }
    }
    
    private var previewWidth: CGFloat {
        switch theme {
        case .dark: return cropWidth
        case .light: return cropWidth
        case .neomorphic: return cropWidth - 4
        }
    }
    
    private var previewHeight: CGFloat {
        switch theme {
        case .dark: return cropHeight
        case .light: return cropHeight
        case .neomorphic: return cropHeight - 4
        }
    }
    
    private var cameraClipShape: AnyShape {
        switch theme {
        case .dark:
            AnyShape(Rectangle())
        case .light:
            AnyShape(Rectangle())
        case .neomorphic:
            AnyShape(RoundedRectangle(cornerRadius: 18))
        }
    }
    
    @ViewBuilder
    private var recordingIndicator: some View {
        if isRecording {
            switch theme {
            case .dark:
                Rectangle()
                    .stroke(colors.accent, lineWidth: 3)
                    .frame(width: cropWidth, height: cropHeight)
                    .animation(.easeInOut(duration: 0.2), value: isRecording)
            case .light:
                Rectangle()
                    .stroke(colors.accent, lineWidth: 3)
                    .frame(width: cropWidth, height: cropHeight)
                    .animation(.easeInOut(duration: 0.2), value: isRecording)
            case .neomorphic:
                RoundedRectangle(cornerRadius: 20)
                    .stroke(colors.accent, lineWidth: 3)
                    .frame(width: cropWidth, height: cropHeight)
                    .animation(.easeInOut(duration: 0.2), value: isRecording)
            }
        }
    }
}

// MARK: - Themed Ring Menu
struct ThemedRingMenuView: View {
    let isRecording: Bool
    let onRecordTap: () -> Void
    let viewModel: CameraViewModel
    let theme: AppTheme
    let colors: ThemeColors
    @State private var showingSettings = false
    
    private let buttonRadius: CGFloat = 112
    private let buttonSize: CGFloat = 44
    
    var body: some View {
        ZStack {
            // Main background based on theme
            ringMenuBackground
            
            // Control buttons
            ForEach(0..<6, id: \.self) { index in
                createThemedControlButton(at: index)
            }
            
            // Record button based on theme
            ThemedRecordButton(
                isRecording: isRecording,
                onTap: onRecordTap,
                theme: theme,
                colors: colors
            )
        }
        .sheet(isPresented: $showingSettings) {
            ThemedSettingsSheetView(theme: theme, colors: colors)
                .preferredColorScheme(theme.colorScheme)
        }
    }
    
    @ViewBuilder
    private var ringMenuBackground: some View {
        switch theme {
        case .dark:
            // Use the original PDF images for dark theme
            Image(isRecording ? "90RecordButtonOnDark" : "90RecordButtonOffDark")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 300, height: 300)
        case .light:
            // Use the light mode PDF images
            Image(isRecording ? "90RecordButtonOnLight" : "90RecordButtonOffLight")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 300, height: 300)
        case .neomorphic:
            Circle()
                .fill(colors.surface)
                .shadow(color: colors.shadow.opacity(0.15), radius: 20, x: 10, y: 10)
                .shadow(color: colors.highlight.opacity(0.9), radius: 20, x: -10, y: -10)
                .frame(width: 300, height: 300)

        }
    }
    
    private func createThemedControlButton(at index: Int) -> some View {
        let symbol = controlSymbols[index]
        let action = getButtonAction(for: index)
        let angle = Double(index) * .pi / 3 - .pi / 2
        let xPos = cos(angle) * buttonRadius
        let yPos = sin(angle) * buttonRadius
        
        return ThemedControlButton(
            sfSymbol: symbol,
            size: buttonSize,
            action: action,
            theme: theme,
            colors: colors
        )
        .offset(x: xPos, y: yPos)
    }
    
    private var controlSymbols: [String] {
        var symbols = [String]()
        symbols.append("arrow.triangle.2.circlepath.camera")
        symbols.append(viewModel.isFlashlightOn ? "bolt.fill" : "bolt.slash")
        symbols.append(viewModel.isScreenDimmed ? "sun.min.fill" : "sun.max")
        symbols.append("photo.on.rectangle")
        symbols.append("gear")
        symbols.append(viewModel.isAudioEnabled ? "speaker.wave.2" : "speaker.slash")
        return symbols
    }
    
    private func getButtonAction(for index: Int) -> () -> Void {
        switch index {
        case 0: return { viewModel.flipCamera() }
        case 1: return { viewModel.toggleFlashlight() }
        case 2: return { viewModel.toggleScreenDimming() }
        case 3: return { 
            if let url = URL(string: "photos-redirect://") {
                UIApplication.shared.open(url)
            }
        }
        case 4: return { showingSettings = true }
        case 5: return { viewModel.toggleAudio() }
        default: return { }
        }
    }
}

// MARK: - Themed Control Button
struct ThemedControlButton: View {
    let sfSymbol: String
    let size: CGFloat
    let action: () -> Void
    let theme: AppTheme
    let colors: ThemeColors
    
    var body: some View {
        Button(action: action) {
            ZStack {
                buttonBackground
                    .frame(width: size, height: size)
                
                Image(systemName: sfSymbol)
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundColor(colors.text)
            }
        }
        .scaleEffect(1.0)
        .animation(.easeInOut(duration: 0.1), value: true)
    }
    
    @ViewBuilder
    private var buttonBackground: some View {
        switch theme {
        case .dark:
            Circle()
                .fill(colors.surface)
        case .light:
            Circle()
                .fill(colors.surface)
        case .neomorphic:
            Circle()
                .fill(colors.surface)
                .shadow(color: colors.shadow, radius: 6, x: 3, y: 3)
                .shadow(color: colors.highlight, radius: 6, x: -3, y: -3)
        }
    }
}

// MARK: - Themed Record Button
struct ThemedRecordButton: View {
    let isRecording: Bool
    let onTap: () -> Void
    let theme: AppTheme
    let colors: ThemeColors
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                switch theme {
                case .dark:
                    // For dark theme, use transparent button over PDF
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 70, height: 70)
                case .light:
                    // For light theme, use transparent button over PDF (same as dark)
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 70, height: 70)
                case .neomorphic:
                    // Outer ring
                    Circle()
                        .fill(colors.surface)
                        .shadow(color: colors.shadow.opacity(0.15), radius: 8, x: 4, y: 4)
                        .shadow(color: colors.highlight, radius: 8, x: -4, y: -4)
                        .frame(width: 80, height: 80)
                    
                    // Inner circle
                    Circle()
                        .fill(isRecording ? colors.accent : colors.secondary.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .animation(.easeInOut(duration: 0.2), value: isRecording)

                }
            }
        }
        .scaleEffect(1.0)
        .animation(.easeInOut(duration: 0.1), value: true)
    }
}

// MARK: - Themed Lens Selection View
struct ThemedLensSelectionView: View {
    @ObservedObject var viewModel: CameraViewModel
    let theme: AppTheme
    let colors: ThemeColors
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(viewModel.availableLenses, id: \.self) { lensType in
                ThemedLensButton(
                    lensType: lensType,
                    isSelected: viewModel.currentLensType == lensType,
                    onTap: {
                        viewModel.switchToLens(lensType)
                    },
                    theme: theme,
                    colors: colors
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(lensSelectionBackground)
    }
    
    @ViewBuilder
    private var lensSelectionBackground: some View {
        switch theme {
        case .dark:
            RoundedRectangle(cornerRadius: 20)
                .fill(colors.surface)
        case .light:
            RoundedRectangle(cornerRadius: 20)
                .fill(colors.surface)
        case .neomorphic:
            RoundedRectangle(cornerRadius: 20)
                .fill(colors.surface)
                .shadow(color: colors.shadow, radius: 6, x: 3, y: 3)
                .shadow(color: colors.highlight, radius: 6, x: -3, y: -3)
        }
    }
}

// MARK: - Themed Lens Button
struct ThemedLensButton: View {
    let lensType: AVCaptureDevice.DeviceType
    let isSelected: Bool
    let onTap: () -> Void
    let theme: AppTheme
    let colors: ThemeColors
    
    private var displayText: String {
        switch lensType {
        case .builtInUltraWideCamera: return "0,5"
        case .builtInWideAngleCamera: return "2×"
        case .builtInTelephotoCamera: return "3"
        default: return "2×"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            Text(displayText)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(isSelected ? .black : colors.text)
                .frame(width: 44, height: 44)
                .background(lensButtonBackground)
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    @ViewBuilder
    private var lensButtonBackground: some View {
        switch theme {
        case .dark:
            Circle()
                .fill(isSelected ? colors.secondary : Color.clear)
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.clear : colors.border, lineWidth: 1)
                )
        case .light:
            Circle()
                .fill(isSelected ? colors.secondary : Color.clear)
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.clear : colors.border, lineWidth: 1)
                )
        case .neomorphic:
            Circle()
                .fill(isSelected ? colors.secondary : colors.surface)
                .shadow(color: colors.shadow, radius: 4, x: 2, y: 2)
                .shadow(color: colors.highlight, radius: 4, x: -2, y: -2)
        }
    }
}

// MARK: - Themed Settings Sheet View
struct ThemedSettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var themeManager: ThemeManager
    let theme: AppTheme
    let colors: ThemeColors
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                themedSettingsList
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(colors.text)
                }
            }
        }
        .tint(colors.text)
        .preferredColorScheme(theme.colorScheme)
    }
    
    private var themedSettingsList: some View {
        List {
            // Theme Selection Section
            Section("Appearance") {
                ForEach(AppTheme.allCases) { appTheme in
                    HStack {
                        Text(appTheme.displayName)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(colors.text)
                        
                        Spacer()
                        
                        if themeManager.currentTheme == appTheme {
                            Image(systemName: "checkmark")
                                .foregroundColor(colors.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        themeManager.setTheme(appTheme)
                    }
                    .listRowBackground(settingsRowBackground)
                }
            }
            
            Section("Settings") {
                themedStartRecordingToggle
                themedPlaceholderToggle1
                themedPlaceholderToggle2
            }
            
            Section {
                // Logo with theme styling
                HStack {
                    Spacer()
                    Image("metame_Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 160)
                        .padding(.vertical, 8)
                        .background(logoBackground)
                        .onTapGesture {
                            if let url = URL(string: "https://www.metame.de") {
                                openURL(url)
                            }
                        }
                    Spacer()
                }
                .listRowBackground(Color.clear)
                
                themedAppVersionRow
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(settingsListBackground)
    }
    
    @State private var startRecordingOnLaunch = false
    @State private var placeholderToggle1State = false
    @State private var placeholderToggle2State = false
    
    private var themedStartRecordingToggle: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Record on launch")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(colors.text)
                
                Text("Automatically start recording when the app opens")
                    .font(.caption)
                    .foregroundColor(colors.secondaryText)
            }
            
            Spacer()
            
            Toggle("", isOn: $startRecordingOnLaunch)
                .toggleStyle(.switch)
                .tint(colors.secondary)
        }
        .padding(.vertical, 4)
        .listRowBackground(settingsRowBackground)
    }
    
    private var themedPlaceholderToggle1: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Lorem Ipsum Dolor")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(colors.text)
                
                Text("This is a placeholder setting for future features")
                    .font(.caption)
                    .foregroundColor(colors.secondaryText)
            }
            
            Spacer()
            
            Toggle("", isOn: $placeholderToggle1State)
                .toggleStyle(.switch)
                .tint(colors.secondary)
        }
        .padding(.vertical, 4)
        .listRowBackground(settingsRowBackground)
    }
    
    private var themedPlaceholderToggle2: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("mauris rhoncus")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(colors.text)
                
                Text("Another placeholder setting for future features")
                    .font(.caption)
                    .foregroundColor(colors.secondaryText)
            }
            
            Spacer()
            
            Toggle("", isOn: $placeholderToggle2State)
                .toggleStyle(.switch)
                .tint(colors.secondary)
        }
        .padding(.vertical, 4)
        .listRowBackground(settingsRowBackground)
    }
    
    private var themedAppVersionRow: some View {
        VStack(spacing: 2) {
            Text("Version")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(colors.text)
            
            Text("1.0")
                .font(.caption)
                .foregroundColor(colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .listRowBackground(Color.clear)
    }
    
    // MARK: - Theme-specific backgrounds
    @ViewBuilder
    private var settingsRowBackground: some View {
        switch theme {
        case .dark:
            colors.surface
        case .light:
            colors.surface
        case .neomorphic:
            colors.surface
        }
    }
    
    @ViewBuilder
    private var settingsListBackground: some View {
        switch theme {
        case .dark:
            colors.background
        case .light:
            colors.background
        case .neomorphic:
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.95, blue: 0.97), Color(red: 0.98, green: 0.98, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

        }
    }
    
    @ViewBuilder
    private var logoBackground: some View {
        switch theme {
        case .dark:
            EmptyView()
        case .light:
            EmptyView()
        case .neomorphic:
            RoundedRectangle(cornerRadius: 16)
                .fill(colors.surface)
                .shadow(color: colors.shadow, radius: 8, x: 4, y: 4)
                .shadow(color: colors.highlight, radius: 8, x: -4, y: -4)

        }
    }
}

#Preview {
    ContentView()
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
