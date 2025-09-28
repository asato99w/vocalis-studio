import Foundation

public protocol AudioRecording {
    func startRecording() async throws -> URL
    func stopRecording() async throws
    func pauseRecording()
    func resumeRecording()
    var isRecording: Bool { get }
    var currentTime: TimeInterval { get }
}

public enum AudioRecorderError: Error {
    case microphoneAccessDenied
    case audioSessionError
    case fileCreationFailed
    case recordingInProgress
}

public class StartRecordingUseCase {
    private let recordingRepository: RecordingRepository
    private let audioRecorder: AudioRecording
    
    public init(
        recordingRepository: RecordingRepository,
        audioRecorder: AudioRecording
    ) {
        self.recordingRepository = recordingRepository
        self.audioRecorder = audioRecorder
    }
    
    public func execute() async throws -> Recording {
        // 1. Start audio recording
        let audioFileUrl = try await audioRecorder.startRecording()
        
        // 2. Create Recording entity
        let recording = Recording(
            id: RecordingId(),
            audioFileUrl: audioFileUrl,
            startTime: Date(),
            endTime: nil
        )
        
        // 3. Save to repository
        try await recordingRepository.save(recording)
        
        return recording
    }
}