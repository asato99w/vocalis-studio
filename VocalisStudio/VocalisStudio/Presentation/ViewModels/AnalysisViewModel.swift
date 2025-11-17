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

    /// Store currentTime when manually paused to preserve it in completion handler
    /// This is needed because AVAudioPlayerWrapper.pause() calls playbackContinuation?.resume(),
    /// which triggers the play() completion handler even for manual pause.
    /// By checking if pausedTime is set in the completion handler, we can distinguish:
    /// - Manual pause: pausedTime != nil → restore currentTime
    /// - Natural completion: pausedTime == nil → reset currentTime to 0
    private var pausedTime: Double?

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
        guard case .ready = state else {
            return
        }

        isPlaying = true

        // Check if we're resuming from a paused position or starting fresh
        let startTime = currentTime
        let isResuming = startTime > 0.01  // Small threshold to handle floating point precision

        if isResuming {
            // Resume from current position
            audioPlayer.resume()

            // CRITICAL: Clear pausedTime when resuming
            // If not cleared, the completion handler will mistakenly treat
            // natural completion as manual pause and restore the old position
            pausedTime = nil

            logger.debug("Playback resumed from time: \(startTime)")
        } else {
            // Start fresh playback from beginning
            Task { [weak self] in
                guard let self = self else { return }
                do {
                    try await self.audioPlayer.play(url: self.recording.fileURL)

                    // Playback finished - check if natural completion or manual pause
                    await MainActor.run {
                        // Check if pause() was called before this completion handler
                        // If pausedTime is set, it means manual pause
                        self.logger.debug("🎵 COMPLETION: Playback finished. pausedTime=\(self.pausedTime?.description ?? "nil")")
                        if let savedTime = self.pausedTime {
                            // Manual pause - restore the saved time
                            self.logger.debug("🎵 COMPLETION: Manual pause detected, restoring time: \(savedTime)")
                            self.currentTime = savedTime
                            self.pausedTime = nil
                        } else {
                            // Natural completion - reset to beginning
                            // CRITICAL: Set isPlaying = false FIRST before stopping timer
                            // to ensure UI shows play button (not pause button)
                            self.logger.debug("🎵 COMPLETION: Natural completion, setting isPlaying=false")
                            self.isPlaying = false

                            // Stop timer if still running
                            self.playbackTimer?.invalidate()
                            self.playbackTimer = nil

                            // Reset position to beginning
                            self.currentTime = 0.0
                            self.logger.debug("🎵 COMPLETION: Reset complete. isPlaying=\(self.isPlaying), currentTime=\(self.currentTime)")
                        }
                    }
                } catch {
                    self.logger.error("Audio playback failed: \(error.localizedDescription)")
                    await MainActor.run {
                        self.pause()
                    }
                }
            }
            logger.debug("Playback started from beginning")
        }

        // Start playback timer to update currentTime
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor in
                // Only update if still playing (avoid race with completion handler)
                guard self.isPlaying else { return }

                // Sync currentTime with audio player
                self.currentTime = self.audioPlayer.currentTime

                // Timer-based completion check is NOT needed
                // The play() completion handler already handles playback completion
                // This check can cause race conditions with the completion handler
            }
        }
    }

    private func pause() {
        // CRITICAL: Stop timer FIRST before reading position to prevent race condition
        playbackTimer?.invalidate()
        playbackTimer = nil

        // CRITICAL: Use audioPlayer.currentTime (actual playback position), not self.currentTime
        // self.currentTime may have been updated by timer after UI test tapped pause button
        // but before this method was called, causing a race condition
        pausedTime = audioPlayer.currentTime

        isPlaying = false

        audioPlayer.pause()

        // Update currentTime to match the actual paused position
        currentTime = audioPlayer.currentTime
    }

    deinit {
        playbackTimer?.invalidate()
    }
}
