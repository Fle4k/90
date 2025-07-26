import Foundation
import SwiftUI
import AVFoundation

// MARK: - Theme System
enum AppTheme: String, CaseIterable, Identifiable {
    case dark = "dark"
    case light = "light"
    case neomorphic = "neomorphic"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        case .neomorphic: return "Neomorphic"
        }
    }
    
    var colorScheme: ColorScheme {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .neomorphic: return .light
        }
    }
}

// MARK: - Theme Colors
struct ThemeColors {
    let background: Color
    let secondaryBackground: Color
    let surface: Color
    let primary: Color
    let secondary: Color
    let accent: Color
    let text: Color
    let secondaryText: Color
    let border: Color
    let shadow: Color
    let highlight: Color
    
    static func colors(for theme: AppTheme) -> ThemeColors {
        switch theme {
        case .dark:
            return ThemeColors(
                background: Color.black,
                secondaryBackground: Color.black.opacity(0.8),
                surface: Color.black.opacity(0.18),
                primary: Color.white,
                secondary: Color.gray,
                accent: Color.red,
                text: Color.white,
                secondaryText: Color.gray,
                border: Color.white.opacity(0.3),
                shadow: Color.clear,
                highlight: Color.clear
            )
        case .light:
            return ThemeColors(
                background: Color(red: 0.851, green: 0.859, blue: 0.820),
                secondaryBackground: Color.black.opacity(0.8),
                surface: Color.black.opacity(0.18),
                primary: Color.white,
                secondary: Color.gray,
                accent: Color.red,
                text: Color.white,
                secondaryText: Color.gray,
                border: Color.white.opacity(0.3),
                shadow: Color.clear,
                highlight: Color.clear
            )
        case .neomorphic:
            return ThemeColors(
                background: Color(red: 0.95, green: 0.95, blue: 0.97),
                secondaryBackground: Color.white,
                surface: Color.white,
                primary: Color.primary,
                secondary: Color.blue,
                accent: Color.red,
                text: Color.primary,
                secondaryText: Color.secondary,
                border: Color.clear,
                shadow: Color.black.opacity(0.1),
                highlight: Color.white.opacity(0.8)
            )

        }
    }
}

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    @Published var currentTheme: AppTheme = .dark
    
    static let shared = ThemeManager()
    
    private init() {
        loadTheme()
    }
    
    var colors: ThemeColors {
        ThemeColors.colors(for: currentTheme)
    }
    
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        saveTheme()
    }
    
    private func saveTheme() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: "selectedTheme")
    }
    
    private func loadTheme() {
        if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = AppTheme(rawValue: savedTheme) {
            currentTheme = theme
        }
    }
}

// MARK: - Camera Recording State
enum CameraRecordingState {
    case idle
    case recording
    case processing
    case saving
}

// MARK: - Video Processing Status
struct VideoProcessingStatus {
    let isProcessing: Bool
    let progress: Float?
    let statusMessage: String?
}

// MARK: - Camera Error Types
enum CameraError: Error {
    case permissionDenied
    case deviceUnavailable
    case recordingFailed
    case processingFailed
    case savingFailed
    
    var localizedDescription: String {
        switch self {
        case .permissionDenied:
            return "Camera permission denied"
        case .deviceUnavailable:
            return "Camera device unavailable"
        case .recordingFailed:
            return "Recording failed"
        case .processingFailed:
            return "Video processing failed"
        case .savingFailed:
            return "Failed to save video"
        }
    }
}

// MARK: - Camera Configuration
struct CameraConfiguration {
    static let aspectRatio: CGFloat = 16.0 / 9.0
    static let previewCornerRadius: CGFloat = 0  // Edge-to-edge, no corners
    static let controlsHeight: CGFloat = 200
}

// MARK: - UI Constants (Liquid Glass Ready)
struct UIConstants {
    // Recording button
    static let recordButtonSize: CGFloat = 80
    static let recordButtonRingWidth: CGFloat = 4
    
    // Control buttons
    static let controlButtonSize: CGFloat = 44
    static let controlCircleRadius: CGFloat = 140
    
    // Typography
    static let timerFontSize: CGFloat = 20
    static let zoomControlFontSize: CGFloat = 18
    
    // Spacing and padding
    static let edgeSpacing: CGFloat = 20
    static let controlPadding: CGFloat = 16
    
    // Recording ring animation
    static let recordingRingWidth: CGFloat = 3
    static let recordingRingScale: CGFloat = 1.05
    static let recordingRingOpacity: CGFloat = 0.8
    
    // Colors for Liquid Glass compatibility
    static let backgroundOpacity: CGFloat = 0.6
    static let glassBlurRadius: CGFloat = 10
}

// MARK: - Recording State
enum RecordingState: CaseIterable {
    case idle
    case recording
    case paused
    
    var isActive: Bool {
        self != .idle
    }
}

// MARK: - Camera Control Actions
enum CameraAction: CaseIterable {
    case toggleCamera
    case toggleFlash
    case showGallery
    case showSettings
    case toggleMute
    case share
    
    var sfSymbol: String {
        switch self {
        case .toggleCamera:
            return "arrow.triangle.2.circlepath.camera"
        case .toggleFlash:
            return "bolt.slash"
        case .showGallery:
            return "photo.on.rectangle"
        case .showSettings:
            return "stop.fill"
        case .toggleMute:
            return "mic.slash"
        case .share:
            return "square.and.arrow.up"
        }
    }
    
    var angle: Double {
        switch self {
        case .toggleCamera: return -90    // Top
        case .toggleMute: return -30      // Top right
        case .showSettings: return 30     // Bottom right
        case .showGallery: return 90      // Bottom
        case .toggleFlash: return 150     // Bottom left
        case .share: return -150          // Top left
        }
    }
}

// MARK: - Video Recording Model
struct VideoRecording {
    let url: URL
    let duration: TimeInterval
    let cropRect: CGRect
    let orientation: UIDeviceOrientation
    
    var isLandscape: Bool {
        orientation == .landscapeLeft || orientation == .landscapeRight
    }
}

// MARK: - Camera Settings
struct CameraSettings {
    var isRecording: Bool = false
    var showCropOverlay: Bool = true
    var cropAspectRatio: CGFloat = CameraConfiguration.aspectRatio
    var cameraPosition: AVCaptureDevice.Position = .back
    var flashMode: AVCaptureDevice.FlashMode = .off
    var isMuted: Bool = false
    var zoomLevel: CGFloat = 1.0
    
    // Liquid Glass effects
    var useGlassEffects: Bool = true
    var backgroundBlurEnabled: Bool = true
}

// MARK: - Camera Permissions
enum CameraPermissionStatus {
    case notDetermined
    case authorized
    case denied
    case restricted
    
    var isAuthorized: Bool {
        self == .authorized
    }
} 