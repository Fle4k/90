import SwiftUI
import AVFoundation
import UIKit
import Combine

struct CameraPreview: UIViewRepresentable {
    let cameraManager: CameraManager
    
    func makeUIView(context: Context) -> CameraPreviewView {
        let previewView = CameraPreviewView()
        previewView.setupPreview(with: cameraManager)
        return previewView
    }
    
    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        // Ensure session is connected when view updates
        uiView.updateSession(with: cameraManager)
    }
}

final class CameraPreviewView: UIView {
    private var cancellables = Set<AnyCancellable>()
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    func setupPreview(with cameraManager: CameraManager) {
        // Configure the preview layer to show the full camera feed
        videoPreviewLayer.videoGravity = .resizeAspectFill
        
        // Initial session assignment
        updateSession(with: cameraManager)
        
        // Observe session running state and update preview accordingly
        cameraManager.$isSessionRunning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRunning in
                if isRunning && self?.videoPreviewLayer.session == nil {
                    self?.videoPreviewLayer.session = cameraManager.captureSession
                }
            }
            .store(in: &cancellables)
    }
    
    func updateSession(with cameraManager: CameraManager) {
        if videoPreviewLayer.session !== cameraManager.captureSession {
            videoPreviewLayer.session = cameraManager.captureSession
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer.frame = bounds
    }
    
    deinit {
        cancellables.removeAll()
    }
} 