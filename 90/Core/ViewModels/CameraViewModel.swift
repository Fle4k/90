import SwiftUI
import AVFoundation
import Combine

@MainActor
final class CameraViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var showsCropOverlay = true
    @Published var cameraPosition: AVCaptureDevice.Position = .back
    @Published var hasRecordingPermission = false
    @Published var previewImage: UIImage?
    
    // MARK: - Private Properties
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    
    // MARK: - Computed Properties
    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        let centiseconds = Int((recordingDuration.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d:%02d", minutes, seconds, centiseconds)
    }
    
    var canRecord: Bool {
        hasRecordingPermission && !isRecording
    }
    
    // MARK: - Initialization
    init() {
        checkPermissions()
    }
    
    // MARK: - Public Methods
    func startRecording() {
        guard canRecord else { return }
        
        isRecording = true
        recordingStartTime = Date()
        recordingDuration = 0
        
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateRecordingDuration()
            }
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartTime = nil
    }
    
    func toggleCamera() {
        cameraPosition = cameraPosition == .back ? .front : .back
    }
    
    func toggleCropOverlay() {
        showsCropOverlay.toggle()
    }
    
    // MARK: - Private Methods
    private func updateRecordingDuration() {
        guard let startTime = recordingStartTime else { return }
        recordingDuration = Date().timeIntervalSince(startTime)
    }
    
    private func checkPermissions() {
        Task {
            let hasPermission = await requestCameraPermission()
            await MainActor.run {
                self.hasRecordingPermission = hasPermission
            }
        }
    }
    
    private func requestCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
} 