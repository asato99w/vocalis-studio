import Foundation
import VocalisDomain

/// Use case for stopping a recording session
public protocol StopRecordingUseCaseProtocol {
    func setRecordingContext(url: URL, settings: ScaleSettings?)
    func execute() async throws -> StopRecordingResult
}

public class StopRecordingUseCase: StopRecordingUseCaseProtocol {
    private let audioRecorder: AudioRecorderProtocol
    private let scalePlayer: ScalePlayerProtocol
    private let recordingRepository: RecordingRepositoryProtocol
    private var currentRecordingURL: URL?
    private var currentSettings: ScaleSettings?

    public init(
        audioRecorder: AudioRecorderProtocol,
        scalePlayer: ScalePlayerProtocol,
        recordingRepository: RecordingRepositoryProtocol
    ) {
        self.audioRecorder = audioRecorder
        self.scalePlayer = scalePlayer
        self.recordingRepository = recordingRepository
    }

    /// Set the current recording context (called by StartRecordingUseCase)
    public func setRecordingContext(url: URL, settings: ScaleSettings?) {
        self.currentRecordingURL = url
        self.currentSettings = settings
    }

    public func execute() async throws -> StopRecordingResult {
        // Stop the scale player first (only if it was playing)
        if currentSettings != nil {
            await scalePlayer.stop()
        }

        // Stop the audio recorder
        let duration = try await audioRecorder.stopRecording()

        // Save recording to repository if we have context with scale settings
        if let url = currentRecordingURL, let settings = currentSettings {
            let recording = Recording(
                fileURL: url,
                createdAt: Date(),
                duration: Duration(seconds: duration),
                scaleSettings: settings
            )
            try await recordingRepository.save(recording)
        }

        // Clear context
        currentRecordingURL = nil
        currentSettings = nil

        // Return result
        return StopRecordingResult(duration: duration)
    }
}
