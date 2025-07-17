import Foundation
import SwiftUI

// MARK: - Camera Configuration
struct CameraConfiguration {
    static let aspectRatio: CGFloat = 16.0 / 9.0
    static let previewCornerRadius: CGFloat = 12
    static let controlsHeight: CGFloat = 200
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
            return "photo.stack"
        case .showSettings:
            return "slider.horizontal.3"
        case .toggleMute:
            return "mic.slash"
        case .share:
            return "square.and.arrow.up"
        }
    }
    
    var angle: Double {
        switch self {
        case .toggleCamera:
            return 0
        case .toggleFlash:
            return 45
        case .showGallery:
            return 90
        case .showSettings:
            return 135
        case .toggleMute:
            return 225
        case .share:
            return 315
        }
    }
}

// MARK: - UI Constants
struct UIConstants {
    static let recordButtonSize: CGFloat = 80
    static let controlButtonSize: CGFloat = 44
    static let controlCircleRadius: CGFloat = 120
    static let timerFontSize: CGFloat = 24
    static let primarySpacing: CGFloat = 20
} 