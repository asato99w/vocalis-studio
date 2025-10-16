import Foundation
import VocalisDomain
import Combine

/// Recording state for the main recording screen
public enum RecordingState: Equatable {
    case idle
    case countdown
    case recording
}

/// ViewModel for the main recording screen
@MainActor
public class RecordingViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published public private(set) var recordingState: RecordingState = .idle
    @Published public private(set) var currentSession: RecordingSession?
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var progress: Double = 0.0
    @Published public private(set) var countdownValue: Int = 3
    @Published public private(set) var lastRecordingURL: URL?
    @Published public private(set) var lastRecordingSettings: ScaleSettings?
    @Published public private(set) var isPlayingRecording: Bool = false

    // MARK: - Pitch Detection Properties

    @Published public private(set) var targetPitch: DetectedPitch?
    @Published public private(set) var detectedPitch: DetectedPitch?
    @Published public private(set) var pitchAccuracy: PitchAccuracy = .none

    // MARK: - Dependencies

    private let startRecordingUseCase: StartRecordingWithScaleUseCaseProtocol
    private let stopRecordingUseCase: StopRecordingUseCaseProtocol
    private let audioPlayer: AudioPlayerProtocol
    private let pitchDetector: RealtimePitchDetector
    private let scalePlayer: ScalePlayerProtocol

    // MARK: - Private Properties

    private var countdownTask: Task<Void, Never>?
    private var progressMonitorTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init(
        startRecordingUseCase: StartRecordingWithScaleUseCaseProtocol,
        stopRecordingUseCase: StopRecordingUseCaseProtocol,
        audioPlayer: AudioPlayerProtocol,
        pitchDetector: RealtimePitchDetector,
        scalePlayer: ScalePlayerProtocol
    ) {
        self.startRecordingUseCase = startRecordingUseCase
        self.stopRecordingUseCase = stopRecordingUseCase
        self.audioPlayer = audioPlayer
        self.pitchDetector = pitchDetector
        self.scalePlayer = scalePlayer

        // Subscribe to pitch detector updates
        pitchDetector.$detectedPitch
            .sink { [weak self] detectedPitch in
                guard let self = self else { return }
                Task { @MainActor in
                    self.updateDetectedPitch(detectedPitch)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// Start the recording process with countdown
    public func startRecording(settings: ScaleSettings? = nil) async {
        // Don't start if already recording or in countdown
        guard recordingState == .idle else { return }

        // Clear any previous error
        errorMessage = nil

        // Start countdown
        recordingState = .countdown
        countdownValue = 3

        // Create countdown task
        countdownTask = Task {
            // Countdown: 3, 2, 1
            for value in (1...3).reversed() {
                if Task.isCancelled { return }
                countdownValue = value
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }

            if Task.isCancelled { return }

            // Countdown complete, start recording
            await executeRecording(settings: settings)
        }
    }

    /// Cancel the countdown before recording starts
    public func cancelCountdown() async {
        guard recordingState == .countdown else { return }

        countdownTask?.cancel()
        countdownTask = nil
        recordingState = .idle
        countdownValue = 3
    }

    /// Stop the current recording
    public func stopRecording() async {
        guard recordingState == .recording else { return }

        // Stop pitch detection
        pitchDetector.stopRealtimeDetection()
        progressMonitorTask?.cancel()
        progressMonitorTask = nil

        do {
            // Save the recording URL and settings before clearing currentSession
            let recordingURL = currentSession?.recordingURL
            let recordingSettings = currentSession?.settings
            print("📼 Stopping recording. URL: \(recordingURL?.path ?? "nil")")

            // Stop recording via use case
            let result = try await stopRecordingUseCase.execute()

            // Update state
            recordingState = .idle
            currentSession = nil
            progress = 0.0
            targetPitch = nil
            detectedPitch = nil
            pitchAccuracy = .none

            // Save the recording URL and settings for playback
            lastRecordingURL = recordingURL
            lastRecordingSettings = recordingSettings
            print("✅ Recording stopped. Duration: \(result.duration) seconds")
            print("✅ Saved to: \(recordingURL?.path ?? "unknown")")
            print("✅ File exists: \(recordingURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false)")

        } catch {
            // Handle error
            errorMessage = error.localizedDescription
            recordingState = .idle
            currentSession = nil
            progress = 0.0
            targetPitch = nil
            detectedPitch = nil
            pitchAccuracy = .none
        }
    }

    /// Play the last recording
    public func playLastRecording() async {
        guard let url = lastRecordingURL else {
            errorMessage = "No recording available"
            print("❌ No recording URL available")
            return
        }

        guard !isPlayingRecording else { return }

        print("▶️ Attempting to play recording from: \(url.path)")
        print("▶️ File exists: \(FileManager.default.fileExists(atPath: url.path))")

        do {
            isPlayingRecording = true

            // If we have scale settings, play muted scale for target pitch tracking
            if let settings = lastRecordingSettings {
                print("🎵 Loading scale for playback (muted)")
                let scaleElements = settings.generateScaleWithKeyChange()
                try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)

                // Start muted scale playback in background
                Task {
                    do {
                        try await scalePlayer.play(muted: true)
                        print("🎵 Muted scale playback completed")
                    } catch {
                        print("⚠️ Muted scale playback failed: \(error)")
                    }
                }

                // Start target pitch monitoring
                startTargetPitchMonitoring(settings: settings)
            }

            // Play the actual recording
            try await audioPlayer.play(url: url)
            print("✅ Playback started")

            // Wait for playback to complete (simplified - in production use delegate)
            try await Task.sleep(nanoseconds: 10_000_000_000) // Max 10 seconds

            // Stop target pitch monitoring
            progressMonitorTask?.cancel()
            progressMonitorTask = nil
            targetPitch = nil

            // Stop muted scale player
            await scalePlayer.stop()

            isPlayingRecording = false
            print("⏸ Playback completed")
        } catch {
            errorMessage = error.localizedDescription
            isPlayingRecording = false
            progressMonitorTask?.cancel()
            progressMonitorTask = nil
            targetPitch = nil
            print("❌ Playback failed: \(error.localizedDescription)")
        }
    }

    /// Stop playback
    public func stopPlayback() async {
        await audioPlayer.stop()
        await scalePlayer.stop()
        progressMonitorTask?.cancel()
        progressMonitorTask = nil
        targetPitch = nil
        isPlayingRecording = false
    }

    // MARK: - Private Methods

    private func executeRecording(settings: ScaleSettings? = nil) async {
        do {
            // Use provided settings or MVP default
            let scaleSettings = settings ?? ScaleSettings.mvpDefault

            // Execute use case
            let session = try await startRecordingUseCase.execute(settings: scaleSettings)

            // Set recording context for stop use case
            if let stopUseCase = stopRecordingUseCase as? StopRecordingUseCase {
                stopUseCase.setRecordingContext(url: session.recordingURL, settings: scaleSettings)
            }

            // Update state
            currentSession = session
            recordingState = .recording

            // Start pitch detection
            do {
                try pitchDetector.startRealtimeDetection()
            } catch {
                print("⚠️ Failed to start pitch detection: \(error)")
            }

            // Start monitoring scale progress for target pitch
            startTargetPitchMonitoring(settings: scaleSettings)

        } catch {
            // Handle error
            errorMessage = error.localizedDescription
            recordingState = .idle
        }
    }

    // MARK: - Pitch Detection Methods

    /// Start monitoring scale player progress to update target pitch
    private func startTargetPitchMonitoring(settings: ScaleSettings) {
        progressMonitorTask = Task {
            print("🎯 Started target pitch monitoring")
            while !Task.isCancelled {
                // Get current scale element from ScalePlayer
                if let currentElement = scalePlayer.currentScaleElement {
                    await updateTargetPitchFromScaleElement(currentElement)
                } else {
                    // No current element (silence or completed)
                    targetPitch = nil
                    print("🎯 No current scale element (isPlaying: \(scalePlayer.isPlaying), index: \(scalePlayer.currentNoteIndex))")
                }

                // Check every 100ms
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            print("🎯 Stopped target pitch monitoring")
        }
    }

    /// Update target pitch from current scale element
    private func updateTargetPitchFromScaleElement(_ element: ScaleElement) async {
        switch element {
        case .scaleNote(let note):
            let pitch = DetectedPitch.fromFrequency(
                note.frequency,
                confidence: 1.0
            )
            targetPitch = pitch
            print("🎯 Target: \(pitch.noteName) (\(String(format: "%.1f", pitch.frequency)) Hz)")
        case .chordLong(let notes), .chordShort(let notes):
            // Use root note of chord as target
            if let rootNote = notes.first {
                let pitch = DetectedPitch.fromFrequency(
                    rootNote.frequency,
                    confidence: 1.0
                )
                targetPitch = pitch
                print("🎯 Target (chord): \(pitch.noteName) (\(String(format: "%.1f", pitch.frequency)) Hz)")
            } else {
                targetPitch = nil
            }
        case .silence:
            targetPitch = nil
            print("🎯 Target: silence")
        }
    }

    /// Update detected pitch and calculate accuracy
    private func updateDetectedPitch(_ pitch: DetectedPitch?) {
        guard let pitch = pitch else {
            detectedPitch = nil
            pitchAccuracy = .none
            return
        }

        // If we have a target pitch, calculate cents difference
        if let target = targetPitch {
            let targetFreq = target.frequency
            let detectedFreq = pitch.frequency
            let cents = Int(round(1200 * log2(detectedFreq / targetFreq)))

            detectedPitch = DetectedPitch(
                noteName: pitch.noteName,
                frequency: pitch.frequency,
                confidence: pitch.confidence,
                cents: cents
            )

            pitchAccuracy = PitchAccuracy.from(cents: cents)
        } else {
            detectedPitch = pitch
            pitchAccuracy = PitchAccuracy.from(cents: pitch.cents)
        }
    }
}
