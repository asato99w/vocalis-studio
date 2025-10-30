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
        limitConfig: RecordingLimitConfigProtocol = ProductionRecordingLimitConfig(),
        countdownDuration: Int = 3,
        targetPitchPollingIntervalNanoseconds: UInt64 = 100_000_000,
        playbackPitchPollingIntervalNanoseconds: UInt64 = 50_000_000
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
            limitConfig: limitConfig,
            countdownDuration: countdownDuration
        )

        self.pitchDetectionVM = PitchDetectionViewModel(
            pitchDetector: pitchDetector,
            scalePlaybackCoordinator: scalePlaybackCoordinator,
            audioPlayer: audioPlayer,
            targetPitchPollingIntervalNanoseconds: targetPitchPollingIntervalNanoseconds,
            playbackPitchPollingIntervalNanoseconds: playbackPitchPollingIntervalNanoseconds
        )

        setupBindings()

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

        recordingStateVM.$isPlayingRecording
            .assign(to: &$isPlayingRecording)

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

    // MARK: - Public Methods (Coordinator)

    /// Start the recording process with countdown
    public func startRecording(settings: ScaleSettings? = nil) async {
        // FileLoggerに直接書き込んで動作確認
        FileLogger.shared.log(level: "INFO", category: "viewmodel", message: "RecordingViewModel.startRecording() called, settings = \(settings != nil ? "present" : "nil")")

        // Start recording through state VM
        await recordingStateVM.startRecording(settings: settings)
        FileLogger.shared.log(level: "DEBUG", category: "viewmodel", message: "Recording started through state VM")

        // If settings provided, start pitch detection monitoring
        // Note: We start monitoring regardless of current state because:
        // 1. With countdown=0, recording starts immediately but state may not be updated yet
        // 2. With countdown>0, we start monitoring during countdown so it's ready when recording begins
        if let settings = settings {
            FileLogger.shared.log(level: "INFO", category: "viewmodel", message: "Settings present, starting scale playback and pitch detection...")
            do {
                // First, start scale playback in background (non-blocking)
                Task {
                    do {
                        try await recordingStateVM.scalePlaybackCoordinator.startMutedPlayback(settings: settings)
                        FileLogger.shared.log(level: "INFO", category: "viewmodel", message: "✅ Scale playback started for recording")
                    } catch {
                        FileLogger.shared.log(level: "ERROR", category: "viewmodel", message: "❌ Scale playback error: \(error.localizedDescription)")
                    }
                }

                // Give scale playback a moment to start
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

                // Then start monitoring (which polls the coordinator's current scale element)
                try await pitchDetectionVM.startTargetPitchMonitoring(settings: settings)
                FileLogger.shared.log(level: "DEBUG", category: "viewmodel", message: "✅ Target pitch monitoring started")

                try pitchDetector.startRealtimeDetection()
                FileLogger.shared.log(level: "INFO", category: "viewmodel", message: "✅ Realtime pitch detection started")
            } catch {
                FileLogger.shared.log(level: "ERROR", category: "viewmodel", message: "❌ Error starting pitch detection: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }
        } else {
            FileLogger.shared.log(level: "WARNING", category: "viewmodel", message: "⚠️ No settings provided, pitch detection NOT started")
        }
        FileLogger.shared.log(level: "INFO", category: "viewmodel", message: "RecordingViewModel.startRecording() completed")
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
            // Set playing state
            recordingStateVM.isPlayingRecording = true
            Logger.viewModel.info("🔵 isPlayingRecording = true")
            Logger.viewModel.logToFile(level: "INFO", message: "🔵 isPlayingRecording = true")

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

            // Clear playing state
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

            // Clear playing state
            recordingStateVM.isPlayingRecording = false
            Logger.viewModel.info("🔵 isPlayingRecording = false (error cleanup)")
        }
    }

    /// Stop playing the recording
    public func stopPlayback() async {
        Logger.viewModel.debug("🔵 stopPlayback() called - cleaning up all playback components")

        // Stop audio playback first
        await recordingStateVM.audioPlayer.stop()

        // Stop scale playback
        await recordingStateVM.scalePlaybackCoordinator.stopPlayback()

        // Stop pitch detection
        await pitchDetectionVM.stopTargetPitchMonitoring()
        pitchDetectionVM.stopPlaybackPitchDetection()

        // Clear playing state
        recordingStateVM.isPlayingRecording = false
        Logger.viewModel.info("🔵 isPlayingRecording = false (manual stop)")

        Logger.viewModel.debug("🔵 stopPlayback() completed")
    }
}
