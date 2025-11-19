import Foundation
import SubscriptionDomain
import VocalisDomain
import SubscriptionDomain
import Combine
import SubscriptionDomain
import OSLog
import SubscriptionDomain

/// Recording state for the main recording screen
public enum RecordingState: Equatable {
    case idle
    case countdown
    case recording
}

/// Coordinator ViewModel for the main recording screen
/// Delegates responsibilities to RecordingStateViewModel and PitchDetectionViewModel
@MainActor
public class RecordingViewModel: ObservableObject {
    // MARK: - Child ViewModels

    public let recordingStateVM: RecordingStateViewModel
    public let pitchDetectionVM: PitchDetectionViewModel
    public let subscriptionViewModel: SubscriptionViewModel

    // MARK: - Dependencies

    private let pitchDetector: any PitchDetectorProtocol & ObservableObject
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Forwarded Properties (for backward compatibility)

    @Published public var recordingState: RecordingState = .idle
    @Published public var currentSession: RecordingSession?
    @Published public var errorMessage: String?
    @Published public var progress: Double = 0.0
    @Published public var countdownValue: Int = 0 // Forwarded from RecordingStateViewModel
    @Published public var lastRecordingURL: URL?
    @Published public var lastRecordingSettings: ScaleSettings?
    @Published public var isPlayingRecording: Bool = false

    @Published public var currentTier: SubscriptionTier = .free
    @Published public var dailyRecordingCount: Int = 0
    @Published public var recordingLimit: RecordingLimit = RecordingLimit(dailyCount: 5, maxDuration: 30)

    @Published public var targetPitch: DetectedPitch?
    @Published public var detectedPitch: DetectedPitch?
    @Published public var pitchAccuracy: PitchAccuracy = .none
    @Published public var spectrum: [Float]?

    // MARK: - Initialization

    public init(
        startRecordingUseCase: StartRecordingUseCaseProtocol,
        startRecordingWithScaleUseCase: StartRecordingWithScaleUseCaseProtocol,
        stopRecordingUseCase: StopRecordingUseCaseProtocol,
        audioPlayer: AudioPlayerProtocol,
        pitchDetector: any PitchDetectorProtocol & ObservableObject,
        scalePlaybackCoordinator: ScalePlaybackCoordinator,
        subscriptionViewModel: SubscriptionViewModel,
        usageTracker: RecordingUsageTracker = RecordingUsageTracker(),
        countdownDuration: Int = 3,
        targetPitchPollingIntervalNanoseconds: UInt64 = 100_000_000,
        playbackPitchPollingIntervalNanoseconds: UInt64 = 50_000_000,
        recordingLimitConfig: RecordingLimit.Configuration = .production
    ) {
        self.pitchDetector = pitchDetector
        self.subscriptionViewModel = subscriptionViewModel

        // Initialize child ViewModels
        self.recordingStateVM = RecordingStateViewModel(
            startRecordingUseCase: startRecordingUseCase,
            startRecordingWithScaleUseCase: startRecordingWithScaleUseCase,
            stopRecordingUseCase: stopRecordingUseCase,
            audioPlayer: audioPlayer,
            scalePlaybackCoordinator: scalePlaybackCoordinator,
            subscriptionViewModel: subscriptionViewModel,
            usageTracker: usageTracker,
            countdownDuration: countdownDuration,
            recordingLimitConfig: recordingLimitConfig
        )

        self.pitchDetectionVM = PitchDetectionViewModel(
            pitchDetector: pitchDetector,
            scalePlaybackCoordinator: scalePlaybackCoordinator,
            audioPlayer: audioPlayer,
            targetPitchPollingIntervalNanoseconds: targetPitchPollingIntervalNanoseconds,
            playbackPitchPollingIntervalNanoseconds: playbackPitchPollingIntervalNanoseconds
        )

        setupBindings()
        setupCallbacks()

        Logger.viewModel.info("RecordingViewModel initialized with child ViewModels")
    }

    // MARK: - Setup

    private func setupBindings() {
        // Forward RecordingStateVM properties
        recordingStateVM.$recordingState
            .assign(to: &$recordingState)

        recordingStateVM.$currentSession
            .assign(to: &$currentSession)

        recordingStateVM.$errorMessage
            .assign(to: &$errorMessage)

        recordingStateVM.$progress
            .assign(to: &$progress)

        recordingStateVM.$countdownValue
            .assign(to: &$countdownValue)

        recordingStateVM.$lastRecordingURL
            .assign(to: &$lastRecordingURL)

        recordingStateVM.$lastRecordingSettings
            .assign(to: &$lastRecordingSettings)

        // isPlayingRecording is managed directly in RecordingViewModel for immediate UI updates

        recordingStateVM.$currentTier
            .assign(to: &$currentTier)

        recordingStateVM.$dailyRecordingCount
            .assign(to: &$dailyRecordingCount)

        recordingStateVM.$recordingLimit
            .assign(to: &$recordingLimit)

        // Forward PitchDetectionVM properties
        pitchDetectionVM.$targetPitch
            .assign(to: &$targetPitch)

        pitchDetectionVM.$detectedPitch
            .assign(to: &$detectedPitch)

        pitchDetectionVM.$pitchAccuracy
            .assign(to: &$pitchAccuracy)

        // Subscribe to spectrum updates from pitch detector
        // Note: Using RealtimePitchDetector for spectrum updates
        if let realtimePitchDetector = pitchDetector as? RealtimePitchDetector {
            realtimePitchDetector.$spectrum
                .sink { [weak self] spectrum in
                    guard let self = self else { return }
                    Task { @MainActor in
                        self.spectrum = spectrum
                    }
                }
                .store(in: &cancellables)
        }
    }

    private func setupCallbacks() {
        // Set up auto-stop callback for duration limit
        // When RecordingStateVM detects duration limit reached, it will call this
        // to ensure proper cleanup of pitch detection and scale playback
        recordingStateVM.onAutoStopNeeded = { [weak self] in
            guard let self = self else { return }
            Logger.viewModel.info("⏱️ Duration limit reached - calling RecordingViewModel.stopRecording() for cleanup")
            Logger.viewModel.logToFile(level: "INFO", message: "⏱️ Duration limit reached - calling RecordingViewModel.stopRecording() for cleanup")
            await self.stopRecording()
        }
    }

    // MARK: - Public Methods (Coordinator)

    /// Start the recording process with countdown
    public func startRecording(settings: ScaleSettings? = nil) async {
        print("[RecordingVM] startRecording() called, settings = \(settings != nil ? "present ✅" : "nil ⚠️")")
        Logger.viewModel.info("RecordingViewModel.startRecording() called, settings = \(settings != nil ? "present" : "nil")")
        Logger.viewModel.logToFile(level: "INFO", message: "RecordingViewModel.startRecording() called, settings = \(settings != nil ? "present" : "nil")")

        // Start recording through state VM (this starts countdown → executeRecording → scale playback)
        await recordingStateVM.startRecording(settings: settings)

        // Wait for recording to actually start (AudioSession configured + recording started)
        // CRITICAL: Must wait for recordingState == .recording, not just isCountdownComplete
        // because AudioSession configuration happens AFTER isCountdownComplete is set
        Logger.viewModel.info("Waiting for recording to start (AudioSession configuration + recording start)...")
        Logger.viewModel.logToFile(level: "INFO", message: "Waiting for recording to start...")

        while recordingStateVM.recordingState != .recording {
            // If recording failed and returned to idle, break the loop
            if recordingStateVM.recordingState == .idle {
                Logger.viewModel.warning("Recording failed to start - skipping pitch detection")
                Logger.viewModel.logToFile(level: "WARNING", message: "Recording failed to start - skipping pitch detection")
                return
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
        Logger.viewModel.info("✅ Recording started (AudioSession configured) - now starting pitch detection")
        Logger.viewModel.logToFile(level: "INFO", message: "✅ Recording started - starting pitch detection")

        do {
            // Always start pitch detector AFTER countdown (for realtime pitch visualization)
            try await pitchDetector.startRealtimeDetection()
            Logger.viewModel.info("✅ Realtime pitch detection started (after countdown)")
            Logger.viewModel.logToFile(level: "INFO", message: "✅ Realtime pitch detection started (after countdown)")

            // If settings provided, start target pitch monitoring
            if let settings = settings {
                Logger.viewModel.info("✅ Settings present - starting target pitch monitoring")
                Logger.viewModel.logToFile(level: "INFO", message: "✅ Settings present - starting target pitch monitoring")

                // NOTE: Audible scale playback is already started by UseCase
                // No need to start it again via Coordinator

                // Start target pitch monitoring (which polls the UseCase's scale player current element)
                try await pitchDetectionVM.startTargetPitchMonitoring(settings: settings)
                Logger.viewModel.info("✅ Target pitch monitoring started")
                Logger.viewModel.logToFile(level: "INFO", message: "✅ Target pitch monitoring started")
            } else {
                Logger.viewModel.info("No settings provided - skipping target pitch monitoring (realtime detection only)")
                Logger.viewModel.logToFile(level: "INFO", message: "No settings provided - skipping target pitch monitoring (realtime detection only)")
            }
        } catch {
            Logger.viewModel.error("❌ Error starting pitch detection: \(error.localizedDescription)")
            Logger.viewModel.logToFile(level: "ERROR", message: "❌ Error starting pitch detection: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        Logger.viewModel.info("RecordingViewModel.startRecording() completed")
        Logger.viewModel.logToFile(level: "INFO", message: "RecordingViewModel.startRecording() completed")
    }

    /// Cancel the countdown before recording starts
    public func cancelCountdown() async {
        await recordingStateVM.cancelCountdown()
    }

    /// Stop the current recording
    public func stopRecording() async {
        // Stop pitch detection first
        await pitchDetectionVM.stopTargetPitchMonitoring()
        pitchDetector.stopRealtimeDetection()

        // Stop scale playback
        await recordingStateVM.scalePlaybackCoordinator.stopPlayback()

        // Then stop recording
        await recordingStateVM.stopRecording()

        // Reset pitch detection state
        pitchDetectionVM.reset()
    }

    /// Play the last recording
    public func playLastRecording() async {
        Logger.viewModel.debug("🔵 playLastRecording() called")
        Logger.viewModel.logToFile(level: "DEBUG", message: "🔵 playLastRecording() called")
        Logger.viewModel.debug("🔵 lastRecordingURL: \(String(describing: self.lastRecordingURL))")
        Logger.viewModel.logToFile(level: "DEBUG", message: "🔵 lastRecordingURL: \(String(describing: self.lastRecordingURL))")
        Logger.viewModel.debug("🔵 lastRecordingSettings: \(String(describing: self.lastRecordingSettings))")
        Logger.viewModel.logToFile(level: "DEBUG", message: "🔵 lastRecordingSettings: \(String(describing: self.lastRecordingSettings))")

        guard let url = lastRecordingURL, let settings = lastRecordingSettings else {
            Logger.viewModel.debug("🔵 Missing URL or settings - starting simple playback without pitch detection")
            Logger.viewModel.logToFile(level: "DEBUG", message: "🔵 Missing URL or settings - starting simple playback without pitch detection")
            await recordingStateVM.playLastRecording()
            return
        }

        Logger.viewModel.debug("🔵 Both URL and settings exist - starting coordinated playback with pitch detection")
        Logger.viewModel.logToFile(level: "DEBUG", message: "🔵 Both URL and settings exist - starting coordinated playback with pitch detection")
        Logger.viewModel.logToFile(level: "DEBUG", message: "🔵 About to enter do block")

        do {
            Logger.viewModel.logToFile(level: "DEBUG", message: "🔵 Entered do block")
            // Note: isPlayingRecording is already set by RecordingView.togglePlayback() before calling this method
            // This ensures immediate UI update without async delay
            Logger.viewModel.info("🔵 playLastRecording() started (isPlayingRecording should already be true)")
            Logger.viewModel.logToFile(level: "INFO", message: "🔵 playLastRecording() started")

            // Step 1: Start muted scale playback FIRST (non-blocking)
            Logger.viewModel.info("🔵 Step 1: Starting muted scale playback in background")
            Logger.viewModel.logToFile(level: "INFO", message: "🔵 Step 1: Starting muted scale playback in background")
            Task {
                Logger.viewModel.logToFile(level: "DEBUG", message: "🔵 Task block entered")
                do {
                    Logger.viewModel.logToFile(level: "DEBUG", message: "🔵 About to call startMutedPlayback")
                    try await recordingStateVM.scalePlaybackCoordinator.startMutedPlayback(settings: settings)
                    Logger.viewModel.info("🔵 ✅ Scale playback completed")
                    Logger.viewModel.logToFile(level: "INFO", message: "🔵 ✅ Scale playback completed")
                } catch {
                    Logger.viewModel.error("🔵 ❌ Scale playback error: \(error.localizedDescription)")
                    Logger.viewModel.logToFile(level: "ERROR", message: "🔵 ❌ Scale playback error: \(error.localizedDescription)")
                }
            }
            // Give scale playback a moment to start
            Logger.viewModel.logToFile(level: "DEBUG", message: "🔵 About to sleep 0.1s")
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            Logger.viewModel.info("🔵 ✅ Scale playback started in background")
            Logger.viewModel.logToFile(level: "INFO", message: "🔵 ✅ Scale playback started in background")

            // Step 2: Start pitch monitoring AFTER scale is playing
            Logger.viewModel.info("🔵 Step 2: Starting target pitch monitoring AFTER scale is playing")
            Logger.viewModel.logToFile(level: "INFO", message: "🔵 Step 2: Starting target pitch monitoring")
            try await pitchDetectionVM.startTargetPitchMonitoring(settings: settings)
            Logger.viewModel.info("🔵 ✅ Target pitch monitoring started")
            Logger.viewModel.logToFile(level: "INFO", message: "🔵 ✅ Target pitch monitoring started")

            // Step 3: Start playback pitch detection for user's pitch analysis
            Logger.viewModel.info("🔵 Step 3: Starting playback pitch detection")
            Logger.viewModel.logToFile(level: "INFO", message: "🔵 Step 3: Starting playback pitch detection")
            try await pitchDetectionVM.startPlaybackPitchDetection(url: url)
            Logger.viewModel.info("🔵 ✅ Playback pitch detection started")
            Logger.viewModel.logToFile(level: "INFO", message: "🔵 ✅ Playback pitch detection started")

            // Step 4: Play the recording audio (scale is already playing)
            Logger.viewModel.info("🔵 Step 4: Starting audio playback (scale already playing)")
            Logger.viewModel.logToFile(level: "INFO", message: "🔵 Step 4: Starting audio playback")
            try await recordingStateVM.audioPlayer.play(url: url)
            Logger.viewModel.info("🔵 ✅ Audio playback completed")
            Logger.viewModel.logToFile(level: "INFO", message: "🔵 ✅ Audio playback completed")

            // Playback completed naturally - cleanup
            Logger.viewModel.debug("🔵 Playback completed naturally, cleaning up")
            await recordingStateVM.scalePlaybackCoordinator.stopPlayback()
            await pitchDetectionVM.stopTargetPitchMonitoring()
            pitchDetectionVM.stopPlaybackPitchDetection()

            // Clear playing state directly in RecordingViewModel for immediate UI update
            isPlayingRecording = false
            recordingStateVM.isPlayingRecording = false
            Logger.viewModel.info("🔵 isPlayingRecording = false (normal completion)")

        } catch {
            Logger.viewModel.error("🔵 ❌ Error during playback: \(error.localizedDescription)")
            Logger.viewModel.logToFile(level: "ERROR", message: "🔵 ❌ Error during playback: \(error.localizedDescription)")
            Logger.viewModel.logError(error)
            errorMessage = error.localizedDescription

            // Error cleanup
            Logger.viewModel.debug("🔵 Performing error cleanup")
            await recordingStateVM.scalePlaybackCoordinator.stopPlayback()
            await pitchDetectionVM.stopTargetPitchMonitoring()
            pitchDetectionVM.stopPlaybackPitchDetection()

            // Clear playing state directly in RecordingViewModel for immediate UI update
            isPlayingRecording = false
            recordingStateVM.isPlayingRecording = false
            Logger.viewModel.info("🔵 isPlayingRecording = false (error cleanup)")
        }
    }

    /// Stop playing the recording
    public func stopPlayback() async {
        Logger.viewModel.debug("🔵 stopPlayback() called - cleaning up all playback components")
        Logger.viewModel.logToFile(level: "INFO", message: "🔴 stopPlayback() called - cleaning up all playback components")

        // Stop audio playback first
        await recordingStateVM.audioPlayer.stop()
        Logger.viewModel.logToFile(level: "DEBUG", message: "🔴 Audio player stopped")

        // Stop scale playback
        await recordingStateVM.scalePlaybackCoordinator.stopPlayback()
        Logger.viewModel.logToFile(level: "DEBUG", message: "🔴 Scale playback stopped")

        // Stop pitch detection
        await pitchDetectionVM.stopTargetPitchMonitoring()
        Logger.viewModel.logToFile(level: "DEBUG", message: "🔴 stopTargetPitchMonitoring() completed")

        pitchDetectionVM.stopPlaybackPitchDetection()
        Logger.viewModel.logToFile(level: "DEBUG", message: "🔴 stopPlaybackPitchDetection() completed")

        // Reset pitch detection state (clears targetPitch display)
        pitchDetectionVM.reset()
        Logger.viewModel.logToFile(level: "DEBUG", message: "🔴 pitch detection reset (targetPitch cleared)")

        // Clear playing state directly in RecordingViewModel for immediate UI update
        isPlayingRecording = false
        recordingStateVM.isPlayingRecording = false
        Logger.viewModel.info("🔵 isPlayingRecording = false (manual stop)")
        Logger.viewModel.logToFile(level: "INFO", message: "🔴 isPlayingRecording = false (manual stop)")

        Logger.viewModel.debug("🔵 stopPlayback() completed")
        Logger.viewModel.logToFile(level: "INFO", message: "🔴 stopPlayback() completed")
    }

    /// Reload audio detection settings from repository and update pitch detector
    /// Called after user modifies settings in AudioSettingsView
    public func reloadAudioSettings(from repository: AudioSettingsRepositoryProtocol) {
        let settings = repository.get()
        if let pitchDetector = pitchDetector as? RealtimePitchDetector {
            pitchDetector.updateSettings(settings)
            Logger.viewModel.info("🔧 Audio settings reloaded: RMS=\(settings.rmsSilenceThreshold), Confidence=\(settings.confidenceThreshold)")
        }
    }
}
