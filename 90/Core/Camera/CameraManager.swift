import AVFoundation
import SwiftUI
import Combine
import Photos

final class CameraManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var isSessionRunning = false
    @Published var hasPermission = false
    @Published var cameraPosition: AVCaptureDevice.Position = .back
    @Published var zoomLevel: CGFloat = 1.0
    @Published var recordedVideoURL: URL?
    @Published var errorMessage: String?
    
    // MARK: - Photo Library Integration
    @Published var hasPhotoLibraryPermission = false
    @Published var isSavingToLibrary = false
    @Published var lastSaveStatus: String?
    
    // MARK: - Video Processing
    @Published var isProcessingVideo = false
    @Published var processingProgress: Float = 0.0
    @Published var processingStatus: String?
    
    // MARK: - New Toggle States
    @Published var isAudioEnabled = true
    @Published var isFlashlightOn = false
    @Published var isScreenDimmed = false
    
    // MARK: - Private Properties
    let captureSession = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    private var movieFileOutput: AVCaptureMovieFileOutput?
    
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var currentDevice: AVCaptureDevice? {
        videoDeviceInput?.device
    }
    
    // MARK: - Optimization Properties
    private var zoomTimer: Timer?
    private var pendingZoomLevel: CGFloat?
    private var originalScreenBrightness: CGFloat = 1.0
    
    // MARK: - Constants
    private let maxZoomLevel: CGFloat = 10.0
    private let minZoomLevel: CGFloat = 1.0
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    // MARK: - Permission Handling
    func checkPermissions() {
        Task {
            let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
            let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            
            if cameraStatus == .authorized && audioStatus == .authorized {
                await MainActor.run {
                    hasPermission = true
                }
                setupSession()
            } else if cameraStatus == .notDetermined || audioStatus == .notDetermined {
                await requestPermissions()
            } else {
                await MainActor.run {
                    hasPermission = false
                    errorMessage = "Camera and microphone permissions are required."
                }
            }
        }
    }
    
    private func requestPermissions() async {
        let cameraGranted = await AVCaptureDevice.requestAccess(for: .video)
        let audioGranted = await AVCaptureDevice.requestAccess(for: .audio)
        
        if cameraGranted && audioGranted {
            await MainActor.run {
                hasPermission = true
            }
            setupSession()
        } else {
            await MainActor.run {
                hasPermission = false
                errorMessage = "Camera and microphone access denied."
            }
        }
    }
    
    // MARK: - Session Setup
    private func setupSession() {
        // Capture current state on main thread first
        let currentPosition = cameraPosition
        let audioEnabled = isAudioEnabled
        
        sessionQueue.async {
            self.captureSession.beginConfiguration()
            
            // Set session preset
            if self.captureSession.canSetSessionPreset(.high) {
                self.captureSession.sessionPreset = .high
            }
            
            // Setup video input with captured position
            self.setupVideoInput(for: currentPosition)
            
            // Setup audio input with captured state
            if audioEnabled {
                self.setupAudioInput()
            }
            
            // Setup movie file output
            self.setupMovieOutput()
            
            self.captureSession.commitConfiguration()
            
            // Start session on background thread
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
            
            // Update UI state on main thread
            DispatchQueue.main.async {
                self.isSessionRunning = self.captureSession.isRunning
            }
        }
    }
    
    private func setupVideoInput(for position: AVCaptureDevice.Position) {
        guard let videoDevice = getCamera(for: position) else {
            DispatchQueue.main.async {
                self.errorMessage = "Unable to access camera"
            }
            return
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
                self.videoDeviceInput = videoInput
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Unable to create video input: \(error.localizedDescription)"
            }
        }
    }
    
    private func setupAudioInput() {
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            DispatchQueue.main.async {
                self.errorMessage = "Unable to access microphone"
            }
            return
        }
        
        do {
            let audioInput = try AVCaptureDeviceInput(device: audioDevice)
            
            if captureSession.canAddInput(audioInput) {
                captureSession.addInput(audioInput)
                self.audioDeviceInput = audioInput
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Unable to create audio input: \(error.localizedDescription)"
            }
        }
    }
    
    private func setupMovieOutput() {
        let movieOutput = AVCaptureMovieFileOutput()
        
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
            self.movieFileOutput = movieOutput
        }
    }
    
    // MARK: - Camera Controls
    func flipCamera() {
        // Capture current position on main thread first
        let currentPosition = cameraPosition
        
        sessionQueue.async {
            self.captureSession.beginConfiguration()
            
            // Remove current video input
            if let videoInput = self.videoDeviceInput {
                self.captureSession.removeInput(videoInput)
            }
            
            // Switch position
            let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
            
            // Setup new camera
            if let newCamera = self.getCamera(for: newPosition) {
                do {
                    let newVideoInput = try AVCaptureDeviceInput(device: newCamera)
                    if self.captureSession.canAddInput(newVideoInput) {
                        self.captureSession.addInput(newVideoInput)
                        self.videoDeviceInput = newVideoInput
                        
                        DispatchQueue.main.async {
                            self.cameraPosition = newPosition
                            self.zoomLevel = 1.0 // Reset zoom when switching cameras
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.errorMessage = "Unable to switch camera: \(error.localizedDescription)"
                    }
                }
            }
            
            self.captureSession.commitConfiguration()
        }
    }
    
    // MARK: - Optimized Camera Controls
    func setZoom(level: CGFloat) {
        guard let device = currentDevice else { return }
        
        let clampedZoom = max(minZoomLevel, min(level, min(maxZoomLevel, device.activeFormat.videoMaxZoomFactor)))
        
        // Store pending zoom level and use timer to debounce rapid calls
        pendingZoomLevel = clampedZoom
        zoomTimer?.invalidate()
        
        zoomTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            self?.applyPendingZoom()
        }
        
        // Update UI immediately for responsiveness
        DispatchQueue.main.async {
            self.zoomLevel = clampedZoom
        }
    }
    
    private func applyPendingZoom() {
        guard let device = currentDevice, let zoom = pendingZoomLevel else { return }
        
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = zoom
            device.unlockForConfiguration()
            pendingZoomLevel = nil
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Unable to set zoom: \(error.localizedDescription)"
            }
        }
    }
    
    func zoomIn() {
        setZoom(level: zoomLevel + 0.5)
    }
    
    func zoomOut() {
        setZoom(level: zoomLevel - 0.5)
    }
    
    // MARK: - New Toggle Controls
    func toggleAudio() {
        // First capture the new state
        let newAudioState = !isAudioEnabled
        
        DispatchQueue.main.async {
            self.isAudioEnabled = newAudioState
        }
        
        sessionQueue.async {
            self.captureSession.beginConfiguration()
            
            if newAudioState {
                self.setupAudioInput()
            } else {
                if let audioInput = self.audioDeviceInput {
                    self.captureSession.removeInput(audioInput)
                    self.audioDeviceInput = nil
                }
            }
            
            self.captureSession.commitConfiguration()
        }
    }
    
    func toggleFlashlight() {
        guard let device = currentDevice, device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            
            if isFlashlightOn {
                device.torchMode = .off
            } else {
                device.torchMode = .on
            }
            
            device.unlockForConfiguration()
            
            DispatchQueue.main.async {
                self.isFlashlightOn = !self.isFlashlightOn
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Unable to toggle flashlight: \(error.localizedDescription)"
            }
        }
    }
    
    func toggleScreenDimming() {
        if isScreenDimmed {
            // Restore original brightness
            UIScreen.main.brightness = originalScreenBrightness
        } else {
            // Store current brightness and dim screen
            originalScreenBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 0.02 // Very dim for dark concerts (2%)
        }
        
        DispatchQueue.main.async {
            self.isScreenDimmed.toggle()
        }
    }
    
    // MARK: - Video Processing
    func processVideo(_ inputURL: URL) {
        DispatchQueue.main.async {
            self.isProcessingVideo = true
            self.processingProgress = 0.0
            self.processingStatus = "Processing video..."
        }
        
        // Create output URL for processed video
        let outputURL = getProcessedVideoURL()
        
        // Create asset from input video
        let asset = AVURLAsset(url: inputURL)
        
        Task {
            do {
                // Use modern async APIs instead of deprecated ones
                let videoTracks = try await asset.loadTracks(withMediaType: .video)
                let audioTracks = try await asset.loadTracks(withMediaType: .audio)
                
                guard let videoTrack = videoTracks.first,
                      let audioTrack = audioTracks.first else {
                    await MainActor.run {
                        self.errorMessage = "Unable to load video tracks"
                        self.isProcessingVideo = false
                    }
                    return
                }
                
                // Create composition
                let composition = AVMutableComposition()
                
                guard let videoCompositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
                      let audioCompositionTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                    await MainActor.run {
                        self.errorMessage = "Unable to create composition tracks"
                        self.isProcessingVideo = false
                    }
                    return
                }
                
                // Load properties asynchronously
                let duration = try await asset.load(.duration)
                let timeRange = CMTimeRange(start: .zero, duration: duration)
                
                // Insert tracks
                try videoCompositionTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
                try audioCompositionTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
                
                await MainActor.run {
                    self.processingProgress = 0.3
                    self.processingStatus = "Creating video composition..."
                }
                
                // Load video properties
                let videoSize = try await videoTrack.load(.naturalSize)
                let transform = try await videoTrack.load(.preferredTransform)
                
                // For vertical video, extract 16:9 horizontal slice from center
                let targetAspectRatio: CGFloat = 16.0 / 9.0
                
                // Calculate dimensions for 16:9 horizontal slice from vertical video
                let cropWidth = videoSize.width // Use full width of vertical video
                let cropHeight = videoSize.width / targetAspectRatio // Calculate height for 16:9 ratio
                
                // Center the crop vertically (take from middle of vertical video)
                let cropX: CGFloat = 0
                let cropY = (videoSize.height - cropHeight) / 2
                
                // Final output size (landscape 16:9)
                let outputWidth: CGFloat = 1920 // HD width  
                let outputHeight: CGFloat = 1080 // HD height
                
                // Create video composition
                let videoComposition = AVMutableVideoComposition()
                videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
                videoComposition.renderSize = CGSize(width: outputWidth, height: outputHeight)
                
                // Create instruction for the video track
                let instruction = AVMutableVideoCompositionInstruction()
                instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
                
                let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoCompositionTrack)
                
                // Create crop and rotation transform
                var combinedTransform = CGAffineTransform.identity
                
                // Apply cropping transform
                let scaleX = outputWidth / cropWidth
                let scaleY = outputHeight / cropHeight
                let scale = max(scaleX, scaleY)
                
                combinedTransform = combinedTransform.scaledBy(x: scale, y: scale)
                combinedTransform = combinedTransform.translatedBy(x: -cropX * scale, y: -cropY * scale)
                
                // Apply 90-degree clockwise rotation for landscape output
                combinedTransform = combinedTransform.rotated(by: .pi / 2)
                combinedTransform = combinedTransform.translatedBy(x: 0, y: -outputWidth)
                
                layerInstruction.setTransform(combinedTransform, at: .zero)
                instruction.layerInstructions = [layerInstruction]
                videoComposition.instructions = [instruction]
                
                await MainActor.run {
                    self.processingProgress = 0.6
                    self.processingStatus = "Exporting video..."
                }
                
                // Export using modern async API
                guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
                    await MainActor.run {
                        self.errorMessage = "Unable to create export session"
                        self.isProcessingVideo = false
                    }
                    return
                }
                
                exportSession.outputURL = outputURL
                exportSession.outputFileType = .mov
                exportSession.videoComposition = videoComposition
                
                // Use modern async export
                try await exportSession.export()
                
                await MainActor.run {
                    self.processingProgress = 1.0
                    self.processingStatus = "Processing complete!"
                    self.isProcessingVideo = false
                    
                    // Save the processed video to photo library
                    self.saveVideoToLibrary(outputURL)
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = "Video processing failed: \(error.localizedDescription)"
                    self.isProcessingVideo = false
                    self.processingProgress = 0.0
                }
            }
        }
    }
    
    private func getProcessedVideoURL() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "processed_video_\(Date().timeIntervalSince1970).mov"
        return documentsDirectory.appendingPathComponent(fileName)
    }
    
    // MARK: - Photo Library Integration
    func checkPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        DispatchQueue.main.async {
            switch status {
            case .authorized, .limited:
                self.hasPhotoLibraryPermission = true
            case .denied, .restricted:
                self.hasPhotoLibraryPermission = false
                self.errorMessage = "Photo library access denied. Enable in Settings to save videos."
            case .notDetermined:
                self.hasPhotoLibraryPermission = false
                self.requestPhotoLibraryPermission()
            @unknown default:
                self.hasPhotoLibraryPermission = false
            }
        }
    }
    
    private func requestPhotoLibraryPermission() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    self?.hasPhotoLibraryPermission = true
                case .denied, .restricted:
                    self?.hasPhotoLibraryPermission = false
                    self?.errorMessage = "Photo library access denied. Enable in Settings to save videos."
                case .notDetermined:
                    self?.hasPhotoLibraryPermission = false
                @unknown default:
                    self?.hasPhotoLibraryPermission = false
                }
            }
        }
    }
    
    func saveVideoToLibrary(_ videoURL: URL) {
        guard hasPhotoLibraryPermission else {
            checkPhotoLibraryPermission()
            return
        }
        
        DispatchQueue.main.async {
            self.isSavingToLibrary = true
            self.lastSaveStatus = nil
        }
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: videoURL, options: nil)
        }) { [weak self] saved, error in
            DispatchQueue.main.async {
                self?.isSavingToLibrary = false
                
                if saved {
                    self?.lastSaveStatus = "Video saved to camera roll! 📸"
                } else if let error = error {
                    self?.lastSaveStatus = "Failed to save video: \(error.localizedDescription)"
                    self?.errorMessage = "Failed to save video: \(error.localizedDescription)"
                } else {
                    self?.lastSaveStatus = "Failed to save video to camera roll"
                    self?.errorMessage = "Failed to save video to camera roll"
                }
                
                // Clear status message after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self?.lastSaveStatus = nil
                }
            }
        }
    }
    
    // MARK: - Recording Controls
    func startRecording() {
        guard let movieOutput = movieFileOutput else {
            errorMessage = "Movie output not available"
            return
        }
        
        sessionQueue.async {
            if !movieOutput.isRecording {
                let outputURL = self.getOutputURL()
                movieOutput.startRecording(to: outputURL, recordingDelegate: self)
                
                DispatchQueue.main.async {
                    self.isRecording = true
                }
            }
        }
    }
    
    func stopRecording() {
        guard let movieOutput = movieFileOutput else { return }
        
        sessionQueue.async {
            if movieOutput.isRecording {
                movieOutput.stopRecording()
                
                DispatchQueue.main.async {
                    self.isRecording = false
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func getCamera(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera],
            mediaType: .video,
            position: position
        )
        return deviceDiscoverySession.devices.first
    }
    
    private func getOutputURL() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "video_\(Date().timeIntervalSince1970).mov"
        return documentsDirectory.appendingPathComponent(fileName)
    }
    
    // MARK: - Preview Layer
    // Preview layer is now handled directly in CameraPreview.swift
    
    // MARK: - Session Control
    func startSession() {
        sessionQueue.async {
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = true
                }
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = false
                }
            }
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        // Recording started successfully
    }
    
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            Task { @MainActor in
                self.errorMessage = "Recording failed: \(error.localizedDescription)"
                self.isRecording = false
            }
        } else {
            Task { @MainActor in
                self.recordedVideoURL = outputFileURL
                self.isRecording = false
                
                // Process video (crop and rotate) before saving to photo library
                self.processVideo(outputFileURL)
            }
        }
    }
} 