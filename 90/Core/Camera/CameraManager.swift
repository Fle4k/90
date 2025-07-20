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
    @Published var currentLensType: AVCaptureDevice.DeviceType = .builtInWideAngleCamera
    @Published var availableLenses: [AVCaptureDevice.DeviceType] = []
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
    
    // MARK: - Lens Properties
    private var originalScreenBrightness: CGFloat = 1.0
    
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
            
            // Set session preset for high quality vertical recording
            if self.captureSession.canSetSessionPreset(.hd4K3840x2160) {
                self.captureSession.sessionPreset = .hd4K3840x2160
            } else if self.captureSession.canSetSessionPreset(.hd1920x1080) {
                self.captureSession.sessionPreset = .hd1920x1080
            } else if self.captureSession.canSetSessionPreset(.hd1280x720) {
                self.captureSession.sessionPreset = .hd1280x720
            } else {
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
        // Discover available lenses for this position synchronously
        let availableTypes = discoverAvailableLensesSync(for: position)
        
        // Update properties on main thread
        DispatchQueue.main.async {
            self.availableLenses = availableTypes
            
            // Set default to ultra-wide (0.5x) if available, as it's the most natural starting point
            // on iPhone 15, otherwise fall back to wide angle
            if availableTypes.contains(.builtInUltraWideCamera) {
                self.currentLensType = .builtInUltraWideCamera
            } else if availableTypes.contains(.builtInWideAngleCamera) {
                self.currentLensType = .builtInWideAngleCamera
            } else if let firstLens = availableTypes.first {
                self.currentLensType = firstLens
            }
        }
        
        // Use the discovered lens type for camera setup
        // Prefer ultra-wide as default, then wide-angle, then first available
        let targetLensType = availableTypes.contains(.builtInUltraWideCamera) ? 
            .builtInUltraWideCamera : (availableTypes.contains(.builtInWideAngleCamera) ? 
            .builtInWideAngleCamera : (availableTypes.first ?? .builtInWideAngleCamera))
        
        guard let videoDevice = getCamera(for: position, deviceType: targetLensType) else {
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
    
    private func discoverAvailableLensesSync(for position: AVCaptureDevice.Position) -> [AVCaptureDevice.DeviceType] {
        // Simple approach - check each lens type individually
        var availableTypes: [AVCaptureDevice.DeviceType] = []
        
        print("📷 Individual lens discovery for position \(position):")
        
        // Check ultra-wide
        let ultraWideDiscovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera],
            mediaType: .video,
            position: position
        )
        if !ultraWideDiscovery.devices.isEmpty {
            availableTypes.append(.builtInUltraWideCamera)
            print("  ✓ Ultra-wide (0.5x) available")
        }
        
        // Check wide angle
        let wideAngleDiscovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: position
        )
        if !wideAngleDiscovery.devices.isEmpty {
            availableTypes.append(.builtInWideAngleCamera)
            print("  ✓ Main camera (2x) available")
        }
        
        // Check telephoto
        let telephotoDiscovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTelephotoCamera],
            mediaType: .video,
            position: position
        )
        if !telephotoDiscovery.devices.isEmpty {
            availableTypes.append(.builtInTelephotoCamera)
            print("  ✓ Telephoto (3x) available")
        }
        
        // Note: We're not adding virtual telephoto options anymore
        // Only show lenses that actually exist on the device
        // The DualWideCamera zoom factors are for digital zoom, not optical lenses
        
        // Note: iPhone 15 has a single main camera, so we don't need to check for multiple wide-angle cameras
        
        // Remove duplicates and sort in expected order
        let uniqueTypes = Array(Set(availableTypes))
        let sortedTypes = uniqueTypes.sorted { lhs, rhs in
            let order: [AVCaptureDevice.DeviceType] = [
                .builtInUltraWideCamera,
                .builtInWideAngleCamera,
                .builtInTelephotoCamera
            ]
            let lhsIndex = order.firstIndex(of: lhs) ?? 999
            let rhsIndex = order.firstIndex(of: rhs) ?? 999
            return lhsIndex < rhsIndex
        }
        
        print("📷 Final available lenses: \(sortedTypes.map { deviceTypeToDisplayName($0) })")
        
        // Debug: Print detailed lens information
        print("📱 Device lens details:")
        for lensType in sortedTypes {
            let displayName = deviceTypeToDisplayName(lensType)
            print("  - \(lensType): \(displayName)")
        }
        
        return sortedTypes
    }
    
    private func discoverAvailableLenses(for position: AVCaptureDevice.Position) {
        let availableTypes = discoverAvailableLensesSync(for: position)
        
        DispatchQueue.main.async {
            self.availableLenses = availableTypes
            
            // Set default to ultra-wide (0.5x) if available, as it's the most natural starting point
            // on iPhone 15, otherwise fall back to wide angle
            if availableTypes.contains(.builtInUltraWideCamera) {
                self.currentLensType = .builtInUltraWideCamera
            } else if availableTypes.contains(.builtInWideAngleCamera) {
                self.currentLensType = .builtInWideAngleCamera
            } else if let firstLens = availableTypes.first {
                self.currentLensType = firstLens
            }
        }
    }
    
    private func deviceTypeToDisplayName(_ deviceType: AVCaptureDevice.DeviceType) -> String {
        switch deviceType {
        case .builtInUltraWideCamera:
            return "0.5x"
        case .builtInWideAngleCamera:
            // On iPhone 15, the main camera is actually 2x relative to ultra-wide
            // So we need to check if this is the main camera or a true 1x
            return "2x" // This is the main camera (24mm) on iPhone 15
        case .builtInTelephotoCamera:
            return "3x" // This would be the telephoto if available
        default:
            return "unknown"
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
            
            // Configure video connection after adding output
            if let connection = movieOutput.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
                
                // Allow the device to record in its natural orientation
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90 // Portrait orientation (90 degrees)
                }
            }
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
            
            // Discover lenses for new position synchronously
            let availableTypes = self.discoverAvailableLensesSync(for: newPosition)
            
            // Update properties on main thread
            DispatchQueue.main.async {
                self.availableLenses = availableTypes
                
                            // Set default to ultra-wide (0.5x) if available, as it's the most natural starting point
            // on iPhone 15, otherwise fall back to wide angle
            if availableTypes.contains(.builtInUltraWideCamera) {
                self.currentLensType = .builtInUltraWideCamera
            } else if availableTypes.contains(.builtInWideAngleCamera) {
                self.currentLensType = .builtInWideAngleCamera
            } else if let firstLens = availableTypes.first {
                self.currentLensType = firstLens
            }
            }
            
            // Use the discovered lens type for camera setup
            // Prefer ultra-wide as default, then wide-angle, then first available
            let targetLensType = availableTypes.contains(.builtInUltraWideCamera) ? 
                .builtInUltraWideCamera : (availableTypes.contains(.builtInWideAngleCamera) ? 
                .builtInWideAngleCamera : (availableTypes.first ?? .builtInWideAngleCamera))
            
            // Setup new camera
            if let newCamera = self.getCamera(for: newPosition, deviceType: targetLensType) {
                do {
                    let newVideoInput = try AVCaptureDeviceInput(device: newCamera)
                    if self.captureSession.canAddInput(newVideoInput) {
                        self.captureSession.addInput(newVideoInput)
                        self.videoDeviceInput = newVideoInput
                        
                        DispatchQueue.main.async {
                            self.cameraPosition = newPosition
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
    
    // MARK: - Lens Switching Controls
    func switchToNextLens() {
        guard let currentIndex = availableLenses.firstIndex(of: currentLensType),
              currentIndex < availableLenses.count - 1 else { return }
        
        let nextLensType = availableLenses[currentIndex + 1]
        switchToLens(nextLensType)
    }
    
    func switchToPreviousLens() {
        guard let currentIndex = availableLenses.firstIndex(of: currentLensType),
              currentIndex > 0 else { return }
        
        let previousLensType = availableLenses[currentIndex - 1]
        switchToLens(previousLensType)
    }
    
    func switchToSpecificLens(_ lensType: AVCaptureDevice.DeviceType) {
        guard availableLenses.contains(lensType) else { return }
        switchToLens(lensType)
    }
    
    private func switchToLens(_ lensType: AVCaptureDevice.DeviceType) {
        guard availableLenses.contains(lensType) else { 
            print("📷 Lens type \(lensType) not available")
            return 
        }
        
        sessionQueue.async {
            self.captureSession.beginConfiguration()
            
            // Remove current video input
            if let videoInput = self.videoDeviceInput {
                self.captureSession.removeInput(videoInput)
            }
            
            // Get new camera device
            if let newCamera = self.getCamera(for: self.cameraPosition, deviceType: lensType) {
                do {
                    let newVideoInput = try AVCaptureDeviceInput(device: newCamera)
                    if self.captureSession.canAddInput(newVideoInput) {
                        self.captureSession.addInput(newVideoInput)
                        self.videoDeviceInput = newVideoInput
                        
                        DispatchQueue.main.async {
                            self.currentLensType = lensType
                            print("📷 Successfully switched to lens: \(lensType)")
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.errorMessage = "Unable to switch lens: \(error.localizedDescription)"
                        print("📷 Failed to switch to lens \(lensType): \(error.localizedDescription)")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Lens not available on this device"
                    print("📷 No camera found for lens type: \(lensType)")
                }
            }
            
            self.captureSession.commitConfiguration()
        }
    }
    
    func canSwitchToNextLens() -> Bool {
        guard let currentIndex = availableLenses.firstIndex(of: currentLensType) else { return false }
        return currentIndex < availableLenses.count - 1
    }
    
    func canSwitchToPreviousLens() -> Bool {
        guard let currentIndex = availableLenses.firstIndex(of: currentLensType) else { return false }
        return currentIndex > 0
    }
    
    func getLensDisplayName(_ lensType: AVCaptureDevice.DeviceType) -> String {
        switch lensType {
        case .builtInUltraWideCamera:
            return "0.5x"
        case .builtInWideAngleCamera:
            // On iPhone 15, the main camera is actually 2x relative to ultra-wide
            return "2x" // This is the main camera (24mm) on iPhone 15
        case .builtInTelephotoCamera:
            return "3x" // This would be the telephoto if available
        default:
            return "2x"
        }
    }
    
    func getCurrentLensDisplayName() -> String {
        return getLensDisplayName(currentLensType)
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
                
                guard let videoTrack = videoTracks.first else {
                    await MainActor.run {
                        self.errorMessage = "Unable to load video tracks"
                        self.isProcessingVideo = false
                    }
                    return
                }
                
                // Create composition
                let composition = AVMutableComposition()
                
                guard let videoCompositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                    await MainActor.run {
                        self.errorMessage = "Unable to create composition tracks"
                        self.isProcessingVideo = false
                    }
                    return
                }
                
                // Add audio track if available
                if let audioTrack = audioTracks.first {
                    if let audioCompositionTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                        let duration = try await asset.load(.duration)
                        let timeRange = CMTimeRange(start: .zero, duration: duration)
                        try audioCompositionTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
                    }
                }
                
                // Load properties asynchronously
                let duration = try await asset.load(.duration)
                let timeRange = CMTimeRange(start: .zero, duration: duration)
                
                // Insert video track
                try videoCompositionTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
                
                await MainActor.run {
                    self.processingProgress = 0.3
                    self.processingStatus = "Creating video composition..."
                }
                
                // Load video properties
                let videoSize = try await videoTrack.load(.naturalSize)
                let transform = try await videoTrack.load(.preferredTransform)
                
                // Determine the actual video dimensions after applying transform
                let transformedSize = videoSize.applying(transform)
                let actualWidth = abs(transformedSize.width)
                let actualHeight = abs(transformedSize.height)
                
                // For vertical video (height > width), crop to 16:9 landscape
                let targetAspectRatio: CGFloat = 16.0 / 9.0
                
                // Calculate crop area - take 16:9 slice from center of vertical video
                let cropWidth = min(actualWidth, actualHeight * targetAspectRatio)
                let cropHeight = cropWidth / targetAspectRatio
                
                // Center the crop area
                let cropX = (actualWidth - cropWidth) / 2
                let cropY = (actualHeight - cropHeight) / 2
                
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
                
                // Create transform for cropping and scaling
                var finalTransform = transform
                
                // Apply cropping by translating and scaling
                let scaleX = outputWidth / cropWidth
                let scaleY = outputHeight / cropHeight
                let scale = min(scaleX, scaleY)
                
                finalTransform = finalTransform.concatenating(CGAffineTransform(translationX: -cropX, y: -cropY))
                finalTransform = finalTransform.concatenating(CGAffineTransform(scaleX: scale, y: scale))
                
                layerInstruction.setTransform(finalTransform, at: .zero)
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
                await exportSession.export()
                
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
    private func getCamera(for position: AVCaptureDevice.Position, deviceType: AVCaptureDevice.DeviceType? = nil) -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInUltraWideCamera,
            .builtInWideAngleCamera,
            .builtInTelephotoCamera
        ]
        
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: position
        )
        
        if let specificType = deviceType {
            let matchingDevices = deviceDiscoverySession.devices.filter { $0.deviceType == specificType }
            
            // Only return a device if it actually exists
            if !matchingDevices.isEmpty {
                print("📷 Found \(matchingDevices.count) devices for type \(specificType)")
                return matchingDevices.first
            } else {
                print("📷 No devices found for type \(specificType)")
                return nil
            }
        }
        
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