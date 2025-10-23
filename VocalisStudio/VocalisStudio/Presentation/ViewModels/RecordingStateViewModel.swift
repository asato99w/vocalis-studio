import Foundation
import VocalisDomain
import Combine
import OSLog

/// ViewModel for recording state management
/// Manages core recording functionality including countdown, start, stop, and duration monitoring
@MainActor
public class RecordingStateViewModel: ObservableObject {
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
    @Published public private(set) var recordingLimit: RecordingLimit = RecordingLimit(dailyCount: 5, maxDuration: 30)

    // MARK: - Dependencies

    private let startRecordingUseCase: StartRecordingUseCaseProtocol
    private let startRecordingWithScaleUseCase: StartRecordingWithScaleUseCaseProtocol
    private let stopRecordingUseCase: StopRecordingUseCaseProtocol
    private let audioPlayer: AudioPlayerProtocol
    private let scalePlayer: ScalePlayerProtocol
    private let subscriptionViewModel: SubscriptionViewModel
    private let usageTracker: RecordingUsageTracker
    private let limitConfig: RecordingLimitConfigProtocol

    // MARK: - Private Properties

    private var countdownTask: Task<Void, Never>?
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
        scalePlayer: ScalePlayerProtocol,
        subscriptionViewModel: SubscriptionViewModel,
        usageTracker: RecordingUsageTracker = RecordingUsageTracker(),
        limitConfig: RecordingLimitConfigProtocol = ProductionRecordingLimitConfig()
    ) {
        self.startRecordingUseCase = startRecordingUseCase
        self.startRecordingWithScaleUseCase = startRecordingWithScaleUseCase
        self.stopRecordingUseCase = stopRecordingUseCase
        self.audioPlayer = audioPlayer
        self.scalePlayer = scalePlayer
        self.subscriptionViewModel = subscriptionViewModel
        self.usageTracker = usageTracker
        self.limitConfig = limitConfig

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

        Logger.viewModel.info("RecordingStateViewModel initialized")
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

        // Clear any previous error
        errorMessage = nil

        // Start countdown
        recordingState = .countdown
        countdownValue = 3

        // Create countdown task
        countdownTask = Task { [weak self] in
            guard let self = self else { return }
            // Countdown: 3, 2, 1
            for value in (1...3).reversed() {
                if Task.isCancelled { return }
                await MainActor.run { self.countdownValue = value }
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }

            if Task.isCancelled { return }

            // Countdown complete, start recording
            await self.executeRecording(settings: settings)
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

        // Stop monitoring tasks
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

            // Increment recording count
            usageTracker.incrementCount()
            self.dailyRecordingCount = usageTracker.getTodayCount()
            Logger.viewModel.info("Daily recording count: \(self.dailyRecordingCount)")

            // Update state
            recordingState = .idle
            currentSession = nil
            progress = 0.0

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
                Task { [weak self] in
                    guard let self = self else { return }
                    do {
                        try await self.scalePlayer.play(muted: true)
                    } catch {
                        // Silently handle muted scale playback errors
                    }
                }
            }

            // Play the actual recording (blocks until playback completes)
            try await audioPlayer.play(url: url)

            isPlayingRecording = false
            Logger.viewModel.info("Playback completed")

        } catch {
            Logger.viewModel.logError(error)
            errorMessage = error.localizedDescription
            isPlayingRecording = false
        }
    }

    /// Stop playing the recording
    public func stopPlayback() {
        Task { @MainActor in
            await audioPlayer.stop()
            isPlayingRecording = false
            Logger.viewModel.info("Playback stopped")
        }
    }

    // MARK: - Private Methods

    /// Execute the actual recording after countdown
    private func executeRecording(settings: ScaleSettings?) async {
        do {
            // Start recording based on settings
            let session: RecordingSession
            if let settings = settings {
                session = try await startRecordingWithScaleUseCase.execute(settings: settings)
                Logger.viewModel.info("Recording started with scale")
            } else {
                session = try await startRecordingUseCase.execute()
                Logger.viewModel.info("Recording started without scale")
            }

            // Update state
            recordingState = .recording
            currentSession = session
            progress = 0.0
            recordingStartTime = Date()

            // Start duration monitoring
            startDurationMonitoring()

            Logger.viewModel.info("Recording in progress")

        } catch {
            Logger.viewModel.logError(error)
            errorMessage = error.localizedDescription
            recordingState = .idle
            currentSession = nil
            progress = 0.0
        }
    }

    /// Monitor recording duration and enforce time limit
    private func startDurationMonitoring() {
        durationMonitorTask = Task { [weak self] in
            guard let self = self else { return }

            let startTime = await MainActor.run { self.recordingStartTime }
            guard let startTime = startTime else { return }

            let maxDuration = await MainActor.run { self.recordingLimit.maxDuration }
            guard let maxDuration = maxDuration else {
                // No duration limit, no monitoring needed
                return
            }

            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startTime)
                let progress = min(elapsed / maxDuration, 1.0)

                await MainActor.run {
                    self.progress = progress
                }

                // Check if time limit reached
                if elapsed >= maxDuration {
                    await MainActor.run {
                        let tierName = self.currentTier.displayName
                        self.errorMessage = "録音時間の上限に達しました (\(tierName)プラン: \(Int(maxDuration))秒)"
                    }
                    await self.stopRecording()
                    break
                }

                try? await Task.sleep(nanoseconds: Self.durationMonitoringIntervalNanoseconds)
            }
        }
    }

    deinit {
        countdownTask?.cancel()
        durationMonitorTask?.cancel()
    }
}
