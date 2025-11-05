import Foundation
import VocalisDomain
import SubscriptionDomain

@MainActor
public class DependencyContainer {
    public static let shared = DependencyContainer()

    private init() {
        // Initialize dependencies
        setupInfrastructure()
        setupUseCases()
    }

    // MARK: - Infrastructure Layer

    private lazy var logger: LoggerProtocol = {
        OSLogAdapter.useCase
    }()

    public lazy var scalePlayer: ScalePlayerProtocol = {
        AVAudioEngineScalePlayer()
    }()

    public lazy var scalePlaybackCoordinator: ScalePlaybackCoordinator = {
        ScalePlaybackCoordinator(scalePlayer: scalePlayer)
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

    public lazy var pitchDetector: RealtimePitchDetector = {
        // Load audio detection settings from repository
        let settings = audioSettingsRepository.get()

        return RealtimePitchDetector(
            rmsSilenceThreshold: settings.rmsSilenceThreshold,
            confidenceThreshold: settings.confidenceThreshold
        )
    }()

    private lazy var audioFileAnalyzer: AudioFileAnalyzerProtocol = {
        AudioFileAnalyzer()
    }()

    private lazy var analysisCache: AnalysisCacheProtocol = {
        AnalysisCache(maxCacheSize: 10)
    }()

    // Subscription Infrastructure
    private lazy var storeKitProductService: StoreKitProductServiceProtocol = {
        StoreKitProductService()
    }()

    private lazy var storeKitPurchaseService: StoreKitPurchaseServiceProtocol = {
        StoreKitPurchaseService()
    }()

    private lazy var userCohortStore: UserCohortStoreProtocol = {
        UserDefaultsCohortStore()
    }()

    public lazy var subscriptionRepository: SubscriptionRepositoryProtocol = {
        StoreKitSubscriptionRepository(
            productService: storeKitProductService,
            purchaseService: storeKitPurchaseService,
            cohortStore: userCohortStore
        )
    }()

    public lazy var audioSettingsRepository: AudioSettingsRepositoryProtocol = {
        UserDefaultsAudioSettingsRepository()
    }()

    // MARK: - Application Layer

    // Domain Services
    private lazy var recordingPolicyService: RecordingPolicyService = {
        RecordingPolicyServiceImpl()
    }()

    private lazy var startRecordingUseCase: StartRecordingUseCaseProtocol = {
        StartRecordingUseCase(
            audioRecorder: audioRecorder,
            recordingPolicyService: recordingPolicyService
        )
    }()

    private lazy var startRecordingWithScaleUseCase: StartRecordingWithScaleUseCaseProtocol = {
        StartRecordingWithScaleUseCase(
            scalePlayer: scalePlayer,
            audioRecorder: audioRecorder,
            recordingPolicyService: recordingPolicyService,
            logger: logger
        )
    }()

    private lazy var stopRecordingUseCase: StopRecordingUseCaseProtocol = {
        StopRecordingUseCase(
            audioRecorder: audioRecorder,
            scalePlayer: scalePlayer,
            recordingRepository: recordingRepository
        )
    }()

    public lazy var analyzeRecordingUseCase: AnalyzeRecordingUseCase = {
        AnalyzeRecordingUseCase(
            audioFileAnalyzer: audioFileAnalyzer,
            analysisCache: analysisCache,
            logger: logger
        )
    }()

    // Subscription Use Cases
    private lazy var getSubscriptionStatusUseCase: GetSubscriptionStatusUseCaseProtocol = {
        GetSubscriptionStatusUseCase(repository: subscriptionRepository)
    }()

    private lazy var purchaseSubscriptionUseCase: PurchaseSubscriptionUseCaseProtocol = {
        PurchaseSubscriptionUseCase(repository: subscriptionRepository)
    }()

    private lazy var restorePurchasesUseCase: RestorePurchasesUseCaseProtocol = {
        RestorePurchasesUseCase(repository: subscriptionRepository)
    }()

    // MARK: - Presentation Layer

    public lazy var recordingViewModel: RecordingViewModel = {
        RecordingViewModel(
            startRecordingUseCase: startRecordingUseCase,
            startRecordingWithScaleUseCase: startRecordingWithScaleUseCase,
            stopRecordingUseCase: stopRecordingUseCase,
            audioPlayer: audioPlayer,
            pitchDetector: pitchDetector,
            scalePlaybackCoordinator: scalePlaybackCoordinator,
            subscriptionViewModel: subscriptionViewModel
        )
    }()

    // Subscription ViewModels
    public lazy var subscriptionViewModel: SubscriptionViewModel = {
        SubscriptionViewModel(
            getStatusUseCase: getSubscriptionStatusUseCase,
            purchaseUseCase: purchaseSubscriptionUseCase,
            restoreUseCase: restorePurchasesUseCase
        )
    }()

    public lazy var paywallViewModel: PaywallViewModel = {
        PaywallViewModel(
            getStatusUseCase: getSubscriptionStatusUseCase,
            purchaseUseCase: purchaseSubscriptionUseCase,
            restoreUseCase: restorePurchasesUseCase
        )
    }()

    // Audio Settings ViewModel Factory
    func makeAudioSettingsViewModel() -> AudioSettingsViewModel {
        AudioSettingsViewModel(repository: audioSettingsRepository)
    }

    // MARK: - Setup

    private func setupInfrastructure() {
        // Configure audio session if needed
    }

    private func setupUseCases() {
        // Initialize use cases
    }
}