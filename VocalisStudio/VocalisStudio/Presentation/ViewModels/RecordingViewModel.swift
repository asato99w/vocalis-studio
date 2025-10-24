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

/// Coordinator ViewModel for the main recording screen
/// Delegates responsibilities to RecordingStateViewModel and PitchDetectionViewModel
@MainActor
public class RecordingViewModel: ObservableObject {
    // MARK: - Child ViewModels

    public let recordingStateVM: RecordingStateViewModel
    public let pitchDetectionVM: PitchDetectionViewModel
    public let subscriptionViewModel: SubscriptionViewModel

    // MARK: - Dependencies

    private let pitchDetector: RealtimePitchDetector
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
        pitchDetector: RealtimePitchDetector,
        scalePlayer: ScalePlayerProtocol,
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
            scalePlayer: scalePlayer,
            subscriptionViewModel: subscriptionViewModel,
            usageTracker: usageTracker,
            limitConfig: limitConfig,
            countdownDuration: countdownDuration
        )

        self.pitchDetectionVM = PitchDetectionViewModel(
            pitchDetector: pitchDetector,
            scalePlayer: scalePlayer,
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
        pitchDetector.$spectrum
            .sink { [weak self] spectrum in
                guard let self = self else { return }
                Task { @MainActor in
                    self.spectrum = spectrum
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods (Coordinator)

    /// Start the recording process with countdown
    public func startRecording(settings: ScaleSettings? = nil) async {
        // Start recording through state VM
        await recordingStateVM.startRecording(settings: settings)

        // If settings provided, start pitch detection monitoring
        // Note: We start monitoring regardless of current state because:
        // 1. With countdown=0, recording starts immediately but state may not be updated yet
        // 2. With countdown>0, we start monitoring during countdown so it's ready when recording begins
        if let settings = settings {
            do {
                try await pitchDetectionVM.startTargetPitchMonitoring(settings: settings)
                try pitchDetector.startRealtimeDetection()
            } catch {
                Logger.viewModel.logError(error)
                errorMessage = error.localizedDescription
            }
        }
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
        // If we have settings, start pitch detection BEFORE playback starts
        if let url = lastRecordingURL, let settings = lastRecordingSettings {
            do {
                // Start target pitch monitoring for scale element tracking
                try await pitchDetectionVM.startTargetPitchMonitoring(settings: settings)
                // Start playback pitch detection for user's pitch analysis
                try await pitchDetectionVM.startPlaybackPitchDetection(url: url)
            } catch {
                Logger.viewModel.logError(error)
            }
        }

        await recordingStateVM.playLastRecording()
    }

    /// Stop playing the recording
    public func stopPlayback() async {
        recordingStateVM.stopPlayback()
        await pitchDetectionVM.stopTargetPitchMonitoring()
        pitchDetectionVM.stopPlaybackPitchDetection()
    }
}
