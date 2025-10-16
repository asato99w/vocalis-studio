import Foundation
import VocalisDomain

/// Use case for starting a recording session with scale playback
public protocol StartRecordingWithScaleUseCaseProtocol {
    func execute(settings: ScaleSettings) async throws -> RecordingSession
}

public class StartRecordingWithScaleUseCase: StartRecordingWithScaleUseCaseProtocol {
    private let scalePlayer: ScalePlayerProtocol
    private let audioRecorder: AudioRecorderProtocol

    public init(
        scalePlayer: ScalePlayerProtocol,
        audioRecorder: AudioRecorderProtocol
    ) {
        self.scalePlayer = scalePlayer
        self.audioRecorder = audioRecorder
    }

    public func execute(settings: ScaleSettings) async throws -> RecordingSession {
        // 1. Generate scale elements with key change chords
        let scaleElements = settings.generateScaleWithKeyChange()

        // 2. Prepare recording - get the URL where audio will be saved
        let recordingURL = try await audioRecorder.prepareRecording()

        // 3. Load scale elements into player (with chord support)
        try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)

        // 4. Start recording
        try await audioRecorder.startRecording()

        // 5. Start scale playback (async - will complete when scale finishes)
        // We start the playback task but don't wait for it to complete
        // Recording and playback happen simultaneously
        let playbackTask = Task {
            try await scalePlayer.play()
        }

        // Give playback a moment to start to ensure recording captures it
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Check if playback failed to start
        if playbackTask.isCancelled {
            try await audioRecorder.stopRecording()
            throw ScalePlayerError.playbackFailed("Playback task was cancelled")
        }

        // 6. Return session info
        return RecordingSession(
            recordingURL: recordingURL,
            settings: settings,
            startedAt: Date()
        )
    }
}
