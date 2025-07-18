import SwiftUI
import AVFoundation
import UIKit

struct CameraPreview: UIViewRepresentable {
    let cameraManager: CameraManager
    
    func makeUIView(context: Context) -> CameraPreviewView {
        let previewView = CameraPreviewView()
        previewView.setupPreview(with: cameraManager.getPreviewLayer())
        return previewView
    }
    
    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        // Update if needed
    }
}

final class CameraPreviewView: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    func setupPreview(with previewLayer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = previewLayer
        
        // Configure the preview layer
        previewLayer.frame = bounds
        previewLayer.videoGravity = .resizeAspectFill
        
        // Add to view
        layer.addSublayer(previewLayer)
        
        // Setup constraints
        previewLayer.frame = bounds
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
} 