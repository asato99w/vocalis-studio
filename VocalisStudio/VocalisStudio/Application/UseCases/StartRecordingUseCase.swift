import Foundation
import VocalisDomain

/// Use case for starting a recording session without scale playback
public protocol StartRecordingUseCaseProtocol {
    func execute() async throws -> RecordingSession
}

public class StartRecordingUseCase: StartRecordingUseCaseProtocol {
    private let audioRecorder: AudioRecorderProtocol

    public init(audioRecorder: AudioRecorderProtocol) {
        self.audioRecorder = audioRecorder
    }

    public func execute() async throws -> RecordingSession {
        // Prepare recording - get the URL where audio will be saved
        let recordingURL = try await audioRecorder.prepareRecording()

        // Start recording
        try await audioRecorder.startRecording()

        // Return session info without scale settings
        return RecordingSession(
            recordingURL: recordingURL,
            settings: nil,
            startedAt: Date()
        )
    }
}
