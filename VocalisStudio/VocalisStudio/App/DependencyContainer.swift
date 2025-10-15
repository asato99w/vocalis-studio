import Foundation
import VocalisDomain

@MainActor
public class DependencyContainer {
    public static let shared = DependencyContainer()

    private init() {
        // Initialize dependencies
        setupInfrastructure()
        setupUseCases()
    }

    // MARK: - Infrastructure Layer

    private lazy var scalePlayer: ScalePlayerProtocol = {
        AVAudioEngineScalePlayer()
    }()

    private lazy var audioRecorder: AudioRecorderProtocol = {
        AVAudioRecorderWrapper()
    }()

    public lazy var audioPlayer: AudioPlayerProtocol = {
        AVAudioPlayerWrapper()
    }()

    public lazy var recordingRepository: RecordingRepositoryProtocol = {
        FileRecordingRepository()
    }()

    // MARK: - Application Layer

    private lazy var startRecordingUseCase: StartRecordingWithScaleUseCaseProtocol = {
        StartRecordingWithScaleUseCase(
            scalePlayer: scalePlayer,
            audioRecorder: audioRecorder
        )
    }()

    private lazy var stopRecordingUseCase: StopRecordingUseCaseProtocol = {
        StopRecordingUseCase(
            audioRecorder: audioRecorder,
            scalePlayer: scalePlayer,
            recordingRepository: recordingRepository
        )
    }()

    // MARK: - Presentation Layer

    public lazy var recordingViewModel: RecordingViewModel = {
        RecordingViewModel(
            startRecordingUseCase: startRecordingUseCase,
            stopRecordingUseCase: stopRecordingUseCase,
            audioPlayer: audioPlayer
        )
    }()

    // MARK: - Setup

    private func setupInfrastructure() {
        // Configure audio session if needed
    }

    private func setupUseCases() {
        // Initialize use cases
    }
}