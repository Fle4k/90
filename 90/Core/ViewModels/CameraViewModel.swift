import SwiftUI
import AVFoundation
import Combine

@MainActor
final class CameraViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var showsCropOverlay = true
    @Published var hasRecordingPermission = false
    @Published var previewImage: UIImage?
    @Published var errorMessage: String?
    @Published var zoomLevel: CGFloat = 1.0
    
    // MARK: - New Toggle States
    @Published var isAudioEnabled = true
    @Published var isFlashlightOn = false
    @Published var isScreenDimmed = false
    
    // MARK: - Photo Library Integration
    @Published var hasPhotoLibraryPermission = false
    @Published var isSavingToLibrary = false
    @Published var lastSaveStatus: String?
    
    // MARK: - Video Processing
    @Published var isProcessingVideo = false
    @Published var processingProgress: Float = 0.0
    @Published var processingStatus: String?
    
    // MARK: - Camera Manager
    @Published var cameraManager = CameraManager()
    
    // MARK: - Private Properties
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        let centiseconds = Int((recordingDuration.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d:%02d", minutes, seconds, centiseconds)
    }
    
    // MARK: - Initializer
    init() {
        setupBindings()
        requestPermissions()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Bind camera manager properties
        cameraManager.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                self?.handleRecordingStateChange(isRecording)
            }
            .store(in: &cancellables)
        
        cameraManager.$hasPermission
            .receive(on: DispatchQueue.main)
            .assign(to: \.hasRecordingPermission, on: self)
            .store(in: &cancellables)
        
        cameraManager.$errorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
        
        cameraManager.$zoomLevel
            .receive(on: DispatchQueue.main)
            .assign(to: \.zoomLevel, on: self)
            .store(in: &cancellables)
        
        // Bind new toggle states
        cameraManager.$isAudioEnabled
            .receive(on: DispatchQueue.main)
            .assign(to: \.isAudioEnabled, on: self)
            .store(in: &cancellables)
        
        cameraManager.$isFlashlightOn
            .receive(on: DispatchQueue.main)
            .assign(to: \.isFlashlightOn, on: self)
            .store(in: &cancellables)
        
        cameraManager.$isScreenDimmed
            .receive(on: DispatchQueue.main)
            .assign(to: \.isScreenDimmed, on: self)
            .store(in: &cancellables)
        
        // Bind photo library states
        cameraManager.$hasPhotoLibraryPermission
            .receive(on: DispatchQueue.main)
            .assign(to: \.hasPhotoLibraryPermission, on: self)
            .store(in: &cancellables)
        
        cameraManager.$isSavingToLibrary
            .receive(on: DispatchQueue.main)
            .assign(to: \.isSavingToLibrary, on: self)
            .store(in: &cancellables)
        
        cameraManager.$lastSaveStatus
            .receive(on: DispatchQueue.main)
            .assign(to: \.lastSaveStatus, on: self)
            .store(in: &cancellables)
        
        // Bind video processing states
        cameraManager.$isProcessingVideo
            .receive(on: DispatchQueue.main)
            .assign(to: \.isProcessingVideo, on: self)
            .store(in: &cancellables)
        
        cameraManager.$processingProgress
            .receive(on: DispatchQueue.main)
            .assign(to: \.processingProgress, on: self)
            .store(in: &cancellables)
        
        cameraManager.$processingStatus
            .receive(on: DispatchQueue.main)
            .assign(to: \.processingStatus, on: self)
            .store(in: &cancellables)
    }
    
    private func handleRecordingStateChange(_ isRecording: Bool) {
        self.isRecording = isRecording
        
        if isRecording {
            startTimer()
        } else {
            stopTimer()
        }
    }
    
    // MARK: - Timer Management
    private func startTimer() {
        recordingStartTime = Date()
        recordingDuration = 0
        
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                guard let startTime = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
    }
    
    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartTime = nil
    }
    
    // MARK: - Permission Methods
    func requestPermissions() {
        cameraManager.checkPermissions()
        cameraManager.checkPhotoLibraryPermission()
    }
    
    private func checkPermissions() {
        hasRecordingPermission = cameraManager.hasPermission
    }
    
    // MARK: - Recording Controls
    func toggleRecording() {
        if isRecording {
            cameraManager.stopRecording()
        } else {
            cameraManager.startRecording()
        }
    }
    
    private func startRecording() {
        cameraManager.startRecording()
    }
    
    private func stopRecording() {
        cameraManager.stopRecording()
    }
    
    // MARK: - Camera Controls
    func flipCamera() {
        cameraManager.flipCamera()
    }
    
    func toggleCamera() {
        cameraManager.flipCamera()
    }
    
    func zoomIn() {
        cameraManager.zoomIn()
    }
    
    func zoomOut() {
        cameraManager.zoomOut()
    }
    
    func setZoom(level: CGFloat) {
        cameraManager.setZoom(level: level)
    }
    
    // MARK: - New Toggle Controls
    func toggleAudio() {
        cameraManager.toggleAudio()
    }
    
    func toggleFlashlight() {
        cameraManager.toggleFlashlight()
    }
    
    func toggleScreenDimming() {
        cameraManager.toggleScreenDimming()
    }
    
    // MARK: - UI Controls
    func toggleCropOverlay() {
        showsCropOverlay.toggle()
    }
    
    // MARK: - Session Control
    func startCameraSession() {
        cameraManager.startSession()
    }
    
    func stopCameraSession() {
        cameraManager.stopSession()
    }
} 
