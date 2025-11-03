import Foundation
import VocalisDomain
import Combine
import OSLog

/// Analysis state for the analysis screen
public enum AnalysisState: Equatable {
    case loading(progress: Double)  // progress: 0.0 to 1.0
    case ready(result: AnalysisResult)
    case error(message: String)
}

/// ViewModel for the analysis screen
@MainActor
public class AnalysisViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published public private(set) var state: AnalysisState = .loading(progress: 0.0)
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var currentTime: Double = 0.0

    // MARK: - Dependencies

    private let recording: Recording
    private let audioPlayer: AudioPlayerProtocol
    private let analyzeRecordingUseCase: AnalyzeRecordingUseCase
    private let logger = Logger(subsystem: "com.kazuasato.VocalisStudio", category: "AnalysisViewModel")

    // MARK: - Private Properties

    private var playbackTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    public var duration: Double {
        recording.duration.seconds
    }

    public var analysisResult: AnalysisResult? {
        if case .ready(let result) = state {
            return result
        }
        return nil
    }

    // MARK: - Initialization

    public init(
        recording: Recording,
        audioPlayer: AudioPlayerProtocol,
        analyzeRecordingUseCase: AnalyzeRecordingUseCase
    ) {
        self.recording = recording
        self.audioPlayer = audioPlayer
        self.analyzeRecordingUseCase = analyzeRecordingUseCase
    }

    // MARK: - Public Methods

    /// Start analysis when view appears
    public func startAnalysis() async {
        logger.info("Starting analysis for recording: \(self.recording.id.value.uuidString)")

        state = .loading(progress: 0.0)

        do {
            // Execute analysis use case with progress reporting
            let result = try await analyzeRecordingUseCase.execute(recording: recording) { [weak self] progress in
                guard let self = self else { return }
                self.state = .loading(progress: progress)
            }

            state = .ready(result: result)
            logger.info("Analysis completed successfully")

        } catch {
            logger.error("Analysis failed: \(error.localizedDescription)")
            state = .error(message: error.localizedDescription)
        }
    }

    /// Toggle playback
    public func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    /// Seek to specific time
    public func seek(to time: Double) {
        currentTime = min(max(0, time), duration)
        audioPlayer.seek(to: currentTime)
    }

    /// Skip backward 5 seconds
    public func skipBackward() {
        seek(to: currentTime - 5.0)
    }

    /// Skip forward 5 seconds
    public func skipForward() {
        seek(to: currentTime + 5.0)
    }

    // MARK: - Private Methods

    private func play() {
        guard case .ready = state else { return }

        isPlaying = true

        // Start audio playback
        Task { [weak self] in
            guard let self = self else { return }
            do {
                try await self.audioPlayer.play(url: self.recording.fileURL)
                // Playback finished
                await MainActor.run {
                    self.pause()
                    self.currentTime = self.duration
                }
            } catch {
                self.logger.error("Audio playback failed: \(error.localizedDescription)")
                await MainActor.run {
                    self.pause()
                }
            }
        }

        // Start playback timer to update currentTime
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor in
                // Sync currentTime with audio player
                self.currentTime = self.audioPlayer.currentTime

                if self.currentTime >= self.duration {
                    self.pause()
                    self.currentTime = self.duration
                }
            }
        }

        logger.debug("Playback started")
    }

    private func pause() {
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil

        audioPlayer.pause()
        logger.debug("Playback paused")
    }

    deinit {
        playbackTimer?.invalidate()
    }
}
