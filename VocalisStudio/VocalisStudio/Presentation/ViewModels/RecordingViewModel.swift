import Foundation
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
    @Published public private(set) var isPlayingRecording: Bool = false

    // MARK: - Dependencies

    private let startRecordingUseCase: StartRecordingWithScaleUseCaseProtocol
    private let stopRecordingUseCase: StopRecordingUseCaseProtocol
    private let audioPlayer: AudioPlayerProtocol

    // MARK: - Private Properties

    private var countdownTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init(
        startRecordingUseCase: StartRecordingWithScaleUseCaseProtocol,
        stopRecordingUseCase: StopRecordingUseCaseProtocol,
        audioPlayer: AudioPlayerProtocol
    ) {
        self.startRecordingUseCase = startRecordingUseCase
        self.stopRecordingUseCase = stopRecordingUseCase
        self.audioPlayer = audioPlayer
    }

    // MARK: - Public Methods

    /// Start the recording process with countdown
    public func startRecording() async {
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
            await executeRecording()
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

        do {
            // Save the recording URL before clearing currentSession
            let recordingURL = currentSession?.recordingURL

            // Stop recording via use case
            let result = try await stopRecordingUseCase.execute()

            // Update state
            recordingState = .idle
            currentSession = nil
            progress = 0.0

            // Save the recording URL for playback
            lastRecordingURL = recordingURL
            print("Recording stopped. Duration: \(result.duration) seconds at: \(recordingURL?.lastPathComponent ?? "unknown")")

        } catch {
            // Handle error
            errorMessage = error.localizedDescription
            recordingState = .idle
            currentSession = nil
            progress = 0.0
        }
    }

    /// Play the last recording
    public func playLastRecording() async {
        guard let url = lastRecordingURL else {
            errorMessage = "No recording available"
            return
        }

        guard !isPlayingRecording else { return }

        do {
            isPlayingRecording = true
            try await audioPlayer.play(url: url)

            // Wait for playback to complete (simplified - in production use delegate)
            try await Task.sleep(nanoseconds: 10_000_000_000) // Max 10 seconds

            isPlayingRecording = false
        } catch {
            errorMessage = error.localizedDescription
            isPlayingRecording = false
        }
    }

    /// Stop playback
    public func stopPlayback() async {
        await audioPlayer.stop()
        isPlayingRecording = false
    }

    // MARK: - Private Methods

    private func executeRecording() async {
        do {
            // Use MVP default settings
            let settings = ScaleSettings.mvpDefault

            // Execute use case
            let session = try await startRecordingUseCase.execute(settings: settings)

            // Set recording context for stop use case
            if let stopUseCase = stopRecordingUseCase as? StopRecordingUseCase {
                stopUseCase.setRecordingContext(url: session.recordingURL, settings: settings)
            }

            // Update state
            currentSession = session
            recordingState = .recording

        } catch {
            // Handle error
            errorMessage = error.localizedDescription
            recordingState = .idle
        }
    }
}
