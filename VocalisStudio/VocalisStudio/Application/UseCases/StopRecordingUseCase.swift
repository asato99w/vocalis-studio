import Foundation

public class StopRecordingUseCase {
    private let recordingRepository: RecordingRepository
    private let audioRecorder: AudioRecording
    
    public init(
        recordingRepository: RecordingRepository,
        audioRecorder: AudioRecording
    ) {
        self.recordingRepository = recordingRepository
        self.audioRecorder = audioRecorder
    }
    
    public func execute(_ recording: Recording) async throws -> Recording {
        // 1. Stop audio recording
        try await audioRecorder.stopRecording()
        
        // 2. Update recording with end time
        var updatedRecording = recording
        updatedRecording.complete(at: Date())
        
        // 3. Save updated recording
        try await recordingRepository.save(updatedRecording)
        
        return updatedRecording
    }
}