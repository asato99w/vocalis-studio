import Foundation
import VocalisDomain
import OSLog

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
        let tempo = settings.tempo.secondsPerNote
        Logger.useCase.info("Starting recording with scale settings, tempo: \(tempo)s")
        FileLogger.shared.log(level: "INFO", category: "usecase", message: "Starting recording with scale settings, tempo: \(tempo)s")

        // 1. Generate scale elements with key change chords
        let scaleElements = settings.generateScaleWithKeyChange()
        Logger.useCase.debug("Generated \(scaleElements.count) scale elements")

        // 2. Prepare recording - get the URL where audio will be saved
        let recordingURL = try await audioRecorder.prepareRecording()
        Logger.recording.info("Recording prepared: \(recordingURL.lastPathComponent)")

        // 3. Load scale elements into player (with chord support)
        try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)
        Logger.scalePlayer.debug("Scale elements loaded")

        // 4. Start recording
        try await audioRecorder.startRecording()
        Logger.recording.info("Recording started")

        // 5. Start scale playback (async - will complete when scale finishes)
        // We start the playback task but don't wait for it to complete
        // Recording and playback happen simultaneously
        let playbackTask = Task {
            try await scalePlayer.play()
        }
        Logger.scalePlayer.info("Scale playback started")
        FileLogger.shared.log(level: "INFO", category: "scale", message: "Scale playback started")

        // Give playback a moment to start to ensure recording captures it
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Check if playback failed to start
        if playbackTask.isCancelled {
            Logger.scalePlayer.error("Playback task was cancelled")
            _ = try await audioRecorder.stopRecording()
            throw ScalePlayerError.playbackFailed("Playback task was cancelled")
        }

        // 6. Return session info
        Logger.useCase.info("Recording session created successfully")
        FileLogger.shared.log(level: "INFO", category: "usecase", message: "Recording session created successfully")
        return RecordingSession(
            recordingURL: recordingURL,
            settings: settings,
            startedAt: Date()
        )
    }
}
