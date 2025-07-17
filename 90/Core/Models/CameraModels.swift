import Foundation
import SwiftUI
import AVFoundation

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