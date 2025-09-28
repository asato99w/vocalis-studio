import Foundation

public class DependencyContainer {
    public static let shared = DependencyContainer()
    
    private init() {}
    
    // Infrastructure
    public lazy var audioRecorder: AudioRecording = {
        AVAudioRecorderWrapper()
    }()
    
    public lazy var recordingRepository: RecordingRepository = {
        do {
            return try RecordingRepositoryImpl()
        } catch {
            fatalError("Failed to initialize RecordingRepository: \(error)")
        }
    }()
    
    public lazy var languageSettingsRepository: LanguageSettingsRepositoryProtocol = {
        UserDefaultsLanguageSettingsRepository()
    }()
    
    // Use Cases
    public lazy var startRecordingUseCase: StartRecordingUseCase = {
        StartRecordingUseCase(
            recordingRepository: recordingRepository,
            audioRecorder: audioRecorder
        )
    }()
    
    public lazy var stopRecordingUseCase: StopRecordingUseCase = {
        StopRecordingUseCase(
            recordingRepository: recordingRepository,
            audioRecorder: audioRecorder
        )
    }()
    
    public lazy var getLanguageSettingsUseCase: GetLanguageSettingsUseCase = {
        GetLanguageSettingsUseCase(repository: languageSettingsRepository)
    }()
    
    public lazy var changeLanguageUseCase: ChangeLanguageUseCase = {
        ChangeLanguageUseCase(repository: languageSettingsRepository)
    }()
    
    // ViewModels
    @MainActor
    public lazy var recordingViewModel: RecordingViewModel = {
        RecordingViewModel(
            startRecordingUseCase: startRecordingUseCase,
            stopRecordingUseCase: stopRecordingUseCase,
            recordingRepository: recordingRepository
        )
    }()
    
    @MainActor
    public lazy var settingsViewModel: SettingsViewModel = {
        SettingsViewModel(
            getLanguageSettingsUseCase: getLanguageSettingsUseCase,
            changeLanguageUseCase: changeLanguageUseCase
        )
    }()
}