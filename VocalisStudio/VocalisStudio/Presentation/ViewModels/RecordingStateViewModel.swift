import Foundation
import Combine
import OSLog
import VocalisDomain
import SubscriptionDomain

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
    @Published internal var isPlayingRecording: Bool = false
    @Published public private(set) var isCountdownComplete: Bool = false

    // MARK: - Subscription Properties

    @Published public private(set) var currentTier: SubscriptionTier = .free
    @Published public private(set) var dailyRecordingCount: Int = 0
    @Published public private(set) var recordingLimit: RecordingLimit = RecordingLimit(dailyCount: 2, maxDuration: 30)

    // MARK: - Callbacks

    /// Called when automatic stop is needed (e.g., duration limit reached)
    /// This allows parent coordinator to perform proper cleanup (stop pitch detection, etc.) before stopping recording
    public var onAutoStopNeeded: (() async -> Void)?

    // MARK: - Dependencies

    private let startRecordingUseCase: StartRecordingUseCaseProtocol
    private let startRecordingWithScaleUseCase: StartRecordingWithScaleUseCaseProtocol
    private let stopRecordingUseCase: StopRecordingUseCaseProtocol
    internal let audioPlayer: AudioPlayerProtocol
    internal let scalePlaybackCoordinator: ScalePlaybackCoordinator
    private let subscriptionViewModel: SubscriptionViewModel
    private let usageTracker: RecordingUsageTracker

    // MARK: - Private Properties

    private var countdownTask: Task<Void, Never>?
    private var durationMonitorTask: Task<Void, Never>?
    private var recordingStartTime: Date?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Constants

    private static let durationMonitoringIntervalNanoseconds: UInt64 = 500_000_000 // 500ms

    // MARK: - Configuration

    private let countdownDuration: Int
    private let recordingLimitConfig: RecordingLimit.Configuration

    // MARK: - Initialization

    public init(
        startRecordingUseCase: StartRecordingUseCaseProtocol,
        startRecordingWithScaleUseCase: StartRecordingWithScaleUseCaseProtocol,
        stopRecordingUseCase: StopRecordingUseCaseProtocol,
        audioPlayer: AudioPlayerProtocol,
        scalePlaybackCoordinator: ScalePlaybackCoordinator,
        subscriptionViewModel: SubscriptionViewModel,
        usageTracker: RecordingUsageTracker = RecordingUsageTracker(),
        countdownDuration: Int = 3,
        recordingLimitConfig: RecordingLimit.Configuration = .production
    ) {
        self.startRecordingUseCase = startRecordingUseCase
        self.startRecordingWithScaleUseCase = startRecordingWithScaleUseCase
        self.stopRecordingUseCase = stopRecordingUseCase
        self.audioPlayer = audioPlayer
        self.scalePlaybackCoordinator = scalePlaybackCoordinator
        self.subscriptionViewModel = subscriptionViewModel
        self.usageTracker = usageTracker
        self.countdownDuration = countdownDuration
        self.recordingLimitConfig = recordingLimitConfig
        self.countdownValue = countdownDuration

        // Subscribe to subscription status updates
        subscriptionViewModel.$currentStatus
            .sink { [weak self] status in
                guard let self = self else { return }
                Task { @MainActor in
                    Logger.viewModel.error("🔴 RECORDING_LIMIT_MARK: currentStatus updated, tier=\(status?.tier.rawValue ?? "nil")")
                    FileLogger.shared.log(level: "ERROR", category: "recording_limit", message: "🔴 currentStatus updated, tier=\(status?.tier.rawValue ?? "nil")")
                    if let status = status {
                        self.currentTier = status.tier
                        self.recordingLimit = RecordingLimit.forTier(status.tier, configuration: self.recordingLimitConfig)
                        Logger.viewModel.error("🔴 RECORDING_LIMIT_MARK: recordingLimit updated, dailyCount=\(self.recordingLimit.dailyCount?.description ?? "nil"), maxDuration=\(self.recordingLimit.maxDuration?.description ?? "nil")")
                        FileLogger.shared.log(level: "ERROR", category: "recording_limit", message: "🔴 recordingLimit updated, dailyCount=\(self.recordingLimit.dailyCount?.description ?? "nil"), maxDuration=\(self.recordingLimit.maxDuration?.description ?? "nil")")
                    }
                }
            }
            .store(in: &cancellables)

        // Initialize usage count
        dailyRecordingCount = usageTracker.getTodayCount()

        Logger.viewModel.error("🔴 RECORDING_LIMIT_MARK: RecordingStateViewModel initialized, defaultLimit dailyCount=\(self.recordingLimit.dailyCount?.description ?? "nil"), maxDuration=\(self.recordingLimit.maxDuration?.description ?? "nil")")
        FileLogger.shared.log(level: "ERROR", category: "recording_limit", message: "🔴 RecordingStateViewModel initialized, defaultLimit dailyCount=\(self.recordingLimit.dailyCount?.description ?? "nil"), maxDuration=\(self.recordingLimit.maxDuration?.description ?? "nil")")
        Logger.viewModel.info("RecordingStateViewModel initialized")
    }

    // MARK: - Public Methods

    /// Clear error message
    public func clearError() {
        errorMessage = nil
    }

    /// Start the recording process with countdown
    public func startRecording(settings: ScaleSettings? = nil) async {
        print("[DIAG] startRecording START: state=\(recordingState)")
        Logger.viewModel.error("🔴 RECORDING_LIMIT_MARK: startRecording START, state=\(String(describing: self.recordingState))")

        // Don't start if already recording or in countdown
        guard recordingState == .idle else {
            print("[DIAG] startRecording REJECTED: already in state \(recordingState)")
            Logger.viewModel.error("🔴 RECORDING_LIMIT_MARK: startRecording REJECTED - already in state \(String(describing: self.recordingState))")
            Logger.viewModel.warning("Start recording ignored: already in state \(String(describing: self.recordingState))")
            return
        }

        // Check recording count limit
        self.dailyRecordingCount = usageTracker.getTodayCount()
        Logger.viewModel.error("🔴 RECORDING_LIMIT_MARK: Recording count check: current=\(self.dailyRecordingCount), limit=\(self.recordingLimit.dailyCount?.description ?? "nil")")
        FileLogger.shared.log(level: "ERROR", category: "recording_limit", message: "🔴 Recording count check: current=\(self.dailyRecordingCount), limit=\(self.recordingLimit.dailyCount?.description ?? "nil")")
        print("[DIAG] Recording count check: current=\(self.dailyRecordingCount), limit=\(recordingLimit.dailyCount ?? -1)")
        if !recordingLimit.isCountWithinLimit(self.dailyRecordingCount) {
            Logger.viewModel.error("🔴 RECORDING_LIMIT_MARK: Recording REJECTED - count limit reached")
            FileLogger.shared.log(level: "ERROR", category: "recording_limit", message: "🔴 Recording REJECTED - count limit reached")
            print("[DIAG] startRecording REJECTED: count limit reached")
            Logger.viewModel.warning("Recording limit reached: \(self.dailyRecordingCount)")
            let errorMsg = "本日の録音回数の上限に達しました (\(currentTier.displayName)プラン)"
            errorMessage = errorMsg
            FileLogger.shared.log(level: "ERROR", category: "recording", message: "❌ Recording rejected - User error message: \(errorMsg)")
            return
        }

        let settingsInfo = settings != nil ? "5-tone scale" : "no scale"
        Logger.viewModel.info("Starting recording with settings: \(settingsInfo)")
        Logger.viewModel.error("🔴 RECORDING_LIMIT_MARK: startRecording PASSED checks, settings=\(settingsInfo)")
        print("[DIAG] startRecording PASSED checks, settings=\(settingsInfo)")

        // Clear any previous error
        errorMessage = nil

        // If countdown is 0, skip countdown and start recording immediately
        if countdownDuration == 0 {
            print("[DIAG] Skipping countdown, executing immediately")
            isCountdownComplete = true
            await executeRecording(settings: settings)
            return
        }

        // Start countdown
        print("[DIAG] Starting countdown: \(countdownDuration) seconds")
        Logger.viewModel.error("🔴 RECORDING_LIMIT_MARK: Starting countdown \(self.countdownDuration) seconds")
        recordingState = .countdown
        countdownValue = countdownDuration

        // Create countdown task
        countdownTask = Task { [weak self] in
            guard let self = self else {
                Logger.viewModel.error("🔴 RECORDING_LIMIT_MARK: Countdown task - self is nil")
                return
            }
            print("[DIAG] Countdown task started")
            Logger.viewModel.error("🔴 RECORDING_LIMIT_MARK: Countdown task started")
            // Countdown: countdownDuration, ..., 2, 1
            for value in (1...self.countdownDuration).reversed() {
                if Task.isCancelled {
                    print("[DIAG] Countdown task cancelled at \(value)")
                    return
                }
                await MainActor.run { self.countdownValue = value }
                print("[DIAG] Countdown: \(value)")
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }

            if Task.isCancelled {
                print("[DIAG] Countdown task cancelled before execute")
                return
            }

            // Countdown complete, set flag before executing recording
            print("[DIAG] Countdown complete, setting isCountdownComplete=true")
            Logger.viewModel.error("🔴 RECORDING_LIMIT_MARK: Countdown complete")
            await MainActor.run { self.isCountdownComplete = true }
            print("[DIAG] Calling executeRecording")
            Logger.viewModel.error("🔴 RECORDING_LIMIT_MARK: Calling executeRecording")
            await self.executeRecording(settings: settings)
        }
    }

    /// Cancel the countdown before recording starts
    public func cancelCountdown() async {
        guard recordingState == .countdown else { return }

        countdownTask?.cancel()
        countdownTask = nil
        recordingState = .idle
        countdownValue = countdownDuration
        isCountdownComplete = false
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
            isCountdownComplete = false

            // Save the recording URL and settings for playback
            lastRecordingURL = recordingURL
            lastRecordingSettings = recordingSettings

        } catch {
            // Handle error
            Logger.viewModel.logError(error)
            let errorMsg = error.localizedDescription
            errorMessage = errorMsg
            FileLogger.shared.log(level: "ERROR", category: "recording", message: "❌ Recording failed - User error message: \(errorMsg)")
            recordingState = .idle
            currentSession = nil
            progress = 0.0
            isCountdownComplete = false
        }
    }

    /// Play the last recording
    public func playLastRecording() async {
        Logger.viewModel.debug("🔵 playLastRecording() called in RecordingStateViewModel")

        guard let url = lastRecordingURL else {
            Logger.viewModel.warning("Play recording failed: no recording available")
            let errorMsg = "No recording available"
            errorMessage = errorMsg
            FileLogger.shared.log(level: "ERROR", category: "playback", message: "❌ Playback failed - User error message: \(errorMsg)")
            return
        }

        guard !isPlayingRecording else {
            Logger.viewModel.warning("⚠️ playLastRecording() blocked: isPlayingRecording = true")
            return
        }

        Logger.viewModel.info("Starting playback: \(url.lastPathComponent)")

        do {
            isPlayingRecording = true

            // If we have scale settings, start muted scale playback via coordinator
            if let settings = lastRecordingSettings {
                try await scalePlaybackCoordinator.startMutedPlayback(settings: settings)
            }

            // Play the actual recording (blocks until playback completes)
            try await audioPlayer.play(url: url)

            // Playback completed naturally - stop scale playback
            await scalePlaybackCoordinator.stopPlayback()

            isPlayingRecording = false
            Logger.viewModel.info("Playback completed")

        } catch {
            Logger.viewModel.logError(error)
            errorMessage = error.localizedDescription
            isPlayingRecording = false
        }
    }

    /// Stop playing the recording
    public func stopPlayback() async {
        await audioPlayer.stop()
        await scalePlaybackCoordinator.stopPlayback()
        isPlayingRecording = false
        Logger.viewModel.info("Playback stopped")
    }

    // MARK: - Private Methods

    /// Create User object from current state
    private func createCurrentUser() -> User {
        let stats = RecordingStats(
            todayCount: dailyRecordingCount,
            lastResetDate: Date(),
            totalCount: 0
        )

        // Use current subscription status, or default to free tier
        let status = subscriptionViewModel.currentStatus ?? .defaultFree(cohort: .v2_0)

        return User(
            id: UserId(),
            subscriptionStatus: status,
            recordingStats: stats
        )
    }

    /// Execute the actual recording after countdown
    private func executeRecording(settings: ScaleSettings?) async {
        print("[DIAG] executeRecording START")
        Logger.viewModel.error("🔴 RECORDING_LIMIT_MARK: executeRecording START")
        do {
            // Create user object from current state
            let user = createCurrentUser()
            print("[DIAG] User created: tier=\(user.subscriptionStatus.tier)")

            // Start recording based on settings
            let session: RecordingSession
            if let settings = settings {
                print("[DIAG] Starting recording WITH scale")
                session = try await startRecordingWithScaleUseCase.execute(user: user, settings: settings)
                Logger.viewModel.info("Recording started with scale")
            } else {
                print("[DIAG] Starting recording WITHOUT scale")
                session = try await startRecordingUseCase.execute(user: user)
                Logger.viewModel.info("Recording started without scale")
            }
            print("[DIAG] Recording session created: \(session.recordingURL.lastPathComponent)")

            // Set recording context for StopRecordingUseCase
            stopRecordingUseCase.setRecordingContext(url: session.recordingURL, settings: session.settings)

            // Update state
            print("[DIAG] Setting recordingState to .recording")
            Logger.viewModel.error("🔴 RECORDING_LIMIT_MARK: Setting recordingState to .recording")
            recordingState = .recording
            currentSession = session
            progress = 0.0
            recordingStartTime = Date()
            print("[DIAG] recordingState is now: \(recordingState)")

            // Start duration monitoring
            startDurationMonitoring()

            Logger.viewModel.info("Recording in progress")
            Logger.viewModel.error("🔴 RECORDING_LIMIT_MARK: executeRecording SUCCESS")
            print("[DIAG] executeRecording SUCCESS")

        } catch {
            print("[DIAG] executeRecording ERROR: \(error.localizedDescription)")
            Logger.viewModel.error("🔴 RECORDING_LIMIT_MARK: executeRecording ERROR - \(error.localizedDescription)")
            Logger.viewModel.logError(error)
            let errorMsg = error.localizedDescription
            errorMessage = errorMsg
            FileLogger.shared.log(level: "ERROR", category: "recording", message: "❌ executeRecording failed - User error message: \(errorMsg)")
            recordingState = .idle
            currentSession = nil
            progress = 0.0
            isCountdownComplete = false  // Reset flag to prevent pitch detection from starting
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
                    // Only show error message for free tier (premium stops silently)
                    let tier = await MainActor.run { self.currentTier }
                    if tier == .free {
                        await MainActor.run {
                            let tierName = self.currentTier.displayName
                            self.errorMessage = "録音時間の上限に達しました (\(tierName)プラン: \(Int(maxDuration))秒)"
                        }
                    }

                    // Call the auto-stop handler if provided (allows parent coordinator to cleanup pitch detection, etc.)
                    let callback = await MainActor.run { self.onAutoStopNeeded }
                    if let callback = callback {
                        await callback()
                    } else {
                        // Fallback: just stop recording state (but this won't cleanup pitch detection)
                        await self.stopRecording()
                    }
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
