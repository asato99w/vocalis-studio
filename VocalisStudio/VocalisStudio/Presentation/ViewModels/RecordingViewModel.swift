import Foundation
import VocalisDomain
import Combine
import OSLog

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

    // MARK: - Subscription Properties

    @Published public private(set) var currentTier: SubscriptionTier = .free
    @Published public private(set) var dailyRecordingCount: Int = 0
    @Published public private(set) var recordingLimit: RecordingLimit = ProductionRecordingLimitConfig().limitForTier(.free)

    // MARK: - Pitch Detection Properties

    @Published public private(set) var targetPitch: DetectedPitch?
    @Published public private(set) var detectedPitch: DetectedPitch?
    @Published public private(set) var pitchAccuracy: PitchAccuracy = .none
    @Published public private(set) var spectrum: [Float]?

    // MARK: - Dependencies

    private let startRecordingUseCase: StartRecordingUseCaseProtocol
    private let startRecordingWithScaleUseCase: StartRecordingWithScaleUseCaseProtocol
    private let stopRecordingUseCase: StopRecordingUseCaseProtocol
    private let audioPlayer: AudioPlayerProtocol
    private let pitchDetector: RealtimePitchDetector
    private let scalePlayer: ScalePlayerProtocol
    private let subscriptionViewModel: SubscriptionViewModel
    private let usageTracker: RecordingUsageTracker
    private let limitConfig: RecordingLimitConfigProtocol

    // MARK: - Private Properties

    private var countdownTask: Task<Void, Never>?
    private var progressMonitorTask: Task<Void, Never>?
    private var pitchDetectionTask: Task<Void, Never>?
    private var durationMonitorTask: Task<Void, Never>?
    private var recordingStartTime: Date?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Constants

    private static let durationMonitoringIntervalNanoseconds: UInt64 = 500_000_000 // 500ms

    // MARK: - Initialization

    public init(
        startRecordingUseCase: StartRecordingUseCaseProtocol,
        startRecordingWithScaleUseCase: StartRecordingWithScaleUseCaseProtocol,
        stopRecordingUseCase: StopRecordingUseCaseProtocol,
        audioPlayer: AudioPlayerProtocol,
        pitchDetector: RealtimePitchDetector,
        scalePlayer: ScalePlayerProtocol,
        subscriptionViewModel: SubscriptionViewModel,
        usageTracker: RecordingUsageTracker = RecordingUsageTracker(),
        limitConfig: RecordingLimitConfigProtocol = ProductionRecordingLimitConfig()
    ) {
        self.startRecordingUseCase = startRecordingUseCase
        self.startRecordingWithScaleUseCase = startRecordingWithScaleUseCase
        self.stopRecordingUseCase = stopRecordingUseCase
        self.audioPlayer = audioPlayer
        self.pitchDetector = pitchDetector
        self.scalePlayer = scalePlayer
        self.subscriptionViewModel = subscriptionViewModel
        self.usageTracker = usageTracker
        self.limitConfig = limitConfig

        // Subscribe to pitch detector updates
        pitchDetector.$detectedPitch
            .sink { [weak self] detectedPitch in
                guard let self = self else { return }
                Task { @MainActor in
                    self.updateDetectedPitch(detectedPitch)
                }
            }
            .store(in: &cancellables)

        // Subscribe to spectrum updates
        pitchDetector.$spectrum
            .sink { [weak self] spectrum in
                guard let self = self else { return }
                Task { @MainActor in
                    self.spectrum = spectrum
                }
            }
            .store(in: &cancellables)

        // Subscribe to subscription status updates
        subscriptionViewModel.$currentStatus
            .sink { [weak self] status in
                guard let self = self else { return }
                Task { @MainActor in
                    if let status = status {
                        self.currentTier = status.tier
                        self.recordingLimit = self.limitConfig.limitForTier(status.tier)
                    }
                }
            }
            .store(in: &cancellables)

        // Initialize usage count
        dailyRecordingCount = usageTracker.getTodayCount()

        Logger.viewModel.info("RecordingViewModel initialized")
        FileLogger.shared.log(level: "INFO", category: "viewmodel", message: "RecordingViewModel initialized")
    }

    // MARK: - Public Methods

    /// Start the recording process with countdown
    public func startRecording(settings: ScaleSettings? = nil) async {
        // Don't start if already recording or in countdown
        guard recordingState == .idle else {
            Logger.viewModel.warning("Start recording ignored: already in state \(String(describing: self.recordingState))")
            return
        }

        // Check recording count limit
        self.dailyRecordingCount = usageTracker.getTodayCount()
        if !recordingLimit.isCountWithinLimit(self.dailyRecordingCount) {
            Logger.viewModel.warning("Recording limit reached: \(self.dailyRecordingCount)")
            errorMessage = "本日の録音回数の上限に達しました (\(currentTier.displayName)プラン)"
            return
        }

        let settingsInfo = settings != nil ? "5-tone scale" : "no scale"
        Logger.viewModel.info("Starting recording with settings: \(settingsInfo)")
        FileLogger.shared.log(level: "INFO", category: "viewmodel", message: "Starting recording with settings: \(settingsInfo)")

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

        Logger.viewModel.info("Stopping recording")
        FileLogger.shared.log(level: "INFO", category: "viewmodel", message: "Stopping recording")

        // Stop pitch detection and monitoring tasks
        pitchDetector.stopRealtimeDetection()
        progressMonitorTask?.cancel()
        progressMonitorTask = nil
        durationMonitorTask?.cancel()
        durationMonitorTask = nil
        recordingStartTime = nil

        do {
            // Save the recording URL and settings before clearing currentSession
            let recordingURL = currentSession?.recordingURL
            let recordingSettings = currentSession?.settings

            // Stop recording via use case
            _ = try await stopRecordingUseCase.execute()

            let filename = recordingURL?.lastPathComponent ?? "unknown"
            Logger.viewModel.info("Recording stopped successfully: \(filename)")
            FileLogger.shared.log(level: "INFO", category: "viewmodel", message: "Recording stopped successfully: \(filename)")

            // Increment recording count
            usageTracker.incrementCount()
            self.dailyRecordingCount = usageTracker.getTodayCount()
            Logger.viewModel.info("Daily recording count: \(self.dailyRecordingCount)")

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

        } catch {
            // Handle error
            Logger.viewModel.logError(error)
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
            Logger.viewModel.warning("Play recording failed: no recording available")
            errorMessage = "No recording available"
            return
        }

        guard !isPlayingRecording else { return }

        Logger.viewModel.info("Starting playback: \(url.lastPathComponent)")

        do {
            isPlayingRecording = true

            // If we have scale settings, play muted scale for target pitch tracking
            if let settings = lastRecordingSettings {
                let scaleElements = settings.generateScaleWithKeyChange()
                try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)

                // Start muted scale playback in background
                Task {
                    do {
                        try await scalePlayer.play(muted: true)
                    } catch {
                        // Silently handle muted scale playback errors
                    }
                }

                // Start target pitch monitoring
                startTargetPitchMonitoring(settings: settings)
            }

            // Start playback pitch detection from file (it will wait for playback to start)
            startPlaybackPitchDetection(url: url)

            // Play the actual recording (blocks until playback completes)
            try await audioPlayer.play(url: url)

            // Stop target pitch monitoring
            progressMonitorTask?.cancel()
            progressMonitorTask = nil
            targetPitch = nil

            // Stop playback pitch detection
            pitchDetectionTask?.cancel()
            pitchDetectionTask = nil
            detectedPitch = nil
            pitchAccuracy = .none

            // Stop muted scale player
            await scalePlayer.stop()

            isPlayingRecording = false
        } catch {
            errorMessage = error.localizedDescription
            isPlayingRecording = false
            progressMonitorTask?.cancel()
            progressMonitorTask = nil
            pitchDetectionTask?.cancel()
            pitchDetectionTask = nil
            targetPitch = nil
            detectedPitch = nil
            pitchAccuracy = .none
        }
    }

    /// Stop playback
    public func stopPlayback() async {
        await audioPlayer.stop()
        await scalePlayer.stop()
        progressMonitorTask?.cancel()
        progressMonitorTask = nil
        pitchDetectionTask?.cancel()
        pitchDetectionTask = nil
        targetPitch = nil
        detectedPitch = nil
        pitchAccuracy = .none
        isPlayingRecording = false
    }

    // MARK: - Private Methods

    private func executeRecording(settings: ScaleSettings? = nil) async {
        do {
            let session: RecordingSession

            if let scaleSettings = settings {
                // 5トーン: スケール付き録音
                Logger.viewModel.debug("Executing recording with scale settings")
                session = try await startRecordingWithScaleUseCase.execute(settings: scaleSettings)

                // Set recording context for stop use case
                if let stopUseCase = stopRecordingUseCase as? StopRecordingUseCase {
                    stopUseCase.setRecordingContext(url: session.recordingURL, settings: scaleSettings)
                }

                // Start monitoring scale progress for target pitch
                startTargetPitchMonitoring(settings: scaleSettings)
            } else {
                // オフ: スケールなし録音
                Logger.viewModel.debug("Executing recording without scale")
                session = try await startRecordingUseCase.execute()

                // Set recording context for stop use case
                if let stopUseCase = stopRecordingUseCase as? StopRecordingUseCase {
                    stopUseCase.setRecordingContext(url: session.recordingURL, settings: nil)
                }

                // No target pitch monitoring when recording without scale
            }

            Logger.viewModel.info("Recording session started: \(session.recordingURL.lastPathComponent)")

            // Update state
            currentSession = session
            recordingState = .recording
            recordingStartTime = Date()

            // Start pitch detection
            do {
                try pitchDetector.startRealtimeDetection()
                Logger.pitchDetection.debug("Real-time pitch detection started")
            } catch {
                Logger.pitchDetection.error("Failed to start pitch detection: \(error.localizedDescription)")
            }

            // Start duration monitoring if there's a limit
            if let maxDuration = recordingLimit.maxDuration {
                startDurationMonitoring(maxDuration: maxDuration)
            }

        } catch {
            // Handle error
            Logger.viewModel.logError(error)
            errorMessage = error.localizedDescription
            recordingState = .idle
        }
    }

    // MARK: - Pitch Detection Methods

    /// Start monitoring scale player progress to update target pitch
    private func startTargetPitchMonitoring(settings: ScaleSettings) {
        progressMonitorTask = Task {
            while !Task.isCancelled {
                // Get current scale element from ScalePlayer
                if let currentElement = scalePlayer.currentScaleElement {
                    await updateTargetPitchFromScaleElement(currentElement)
                } else {
                    // No current element (silence or completed)
                    targetPitch = nil
                }

                // Check every 100ms
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
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
        case .chordLong(let notes), .chordShort(let notes):
            // Use root note of chord as target
            if let rootNote = notes.first {
                let pitch = DetectedPitch.fromFrequency(
                    rootNote.frequency,
                    confidence: 1.0
                )
                targetPitch = pitch
            } else {
                targetPitch = nil
            }
        case .silence:
            targetPitch = nil
        }
    }

    /// Update detected pitch and calculate accuracy
    private func updateDetectedPitch(_ pitch: DetectedPitch?) {
        guard let pitch = pitch else {
            detectedPitch = nil
            pitchAccuracy = .none
            return
        }

        // Validate frequency is reasonable (avoid NaN/infinite in log calculation)
        guard pitch.frequency > 0 && pitch.frequency < 10000 else {
            detectedPitch = nil
            pitchAccuracy = .none
            return
        }

        // If we have a target pitch, calculate cents difference
        if let target = targetPitch {
            let targetFreq = target.frequency
            let detectedFreq = pitch.frequency

            guard targetFreq > 0 else {
                detectedPitch = pitch
                pitchAccuracy = .none
                return
            }

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

    /// Start detecting pitch from recording file during playback
    private func startPlaybackPitchDetection(url: URL) {
        pitchDetectionTask = Task {
            // Wait for playback to start (max 3 seconds)
            var waitCount = 0
            while !audioPlayer.isPlaying && waitCount < 30 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                waitCount += 1
            }

            if !audioPlayer.isPlaying {
                return
            }

            while !Task.isCancelled && audioPlayer.isPlaying {
                // Get current playback time
                let currentTime = audioPlayer.currentTime

                // Analyze pitch at current time (await completion before next iteration)
                await withCheckedContinuation { continuation in
                    pitchDetector.analyzePitchFromFile(url, atTime: currentTime) { [weak self] pitch in
                        guard let self = self else {
                            continuation.resume()
                            return
                        }
                        Task { @MainActor in
                            self.updateDetectedPitch(pitch)
                            continuation.resume()
                        }
                    }
                }

                // Check every 100ms
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    /// Start monitoring recording duration and auto-stop when limit is reached
    private func startDurationMonitoring(maxDuration: TimeInterval) {
        durationMonitorTask = Task {
            guard let startTime = recordingStartTime else { return }

            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startTime)

                // Check if duration limit reached
                if elapsed >= maxDuration {
                    Logger.viewModel.warning("Recording duration limit reached: \(elapsed)s / \(maxDuration)s")

                    // Stop recording automatically
                    await stopRecording()

                    // Show message to user
                    errorMessage = "録音時間の上限に達しました (\(currentTier.displayName)プラン: \(Int(maxDuration))秒)"
                    return
                }

                // Check at regular intervals
                try? await Task.sleep(nanoseconds: Self.durationMonitoringIntervalNanoseconds)
            }
        }
    }
}
