# アプリケーションアーキテクチャ設計書 - Vocalis Studio

## アーキテクチャ概要

Vocalis Studioは**クリーンアーキテクチャ**を基盤とし、**ドメイン駆動設計（DDD）**の原則に従って設計されています。**テスト駆動開発（TDD）**により高品質なコードを維持します。

### 採用アーキテクチャ・設計手法
- **Clean Architecture**: ビジネスロジックの独立性とテスタビリティを確保
- **Domain-Driven Design (DDD)**: ボイストレーニングドメインを正確にモデリング
- **Test-Driven Development (TDD)**: テストファーストによる堅牢な実装
- **MVVM Pattern**: Presentation層でのデータバインディング

## クリーンアーキテクチャ層構造

```
┌─────────────────────────────────────────────┐
│          Presentation Layer                 │
│     (SwiftUI Views, ViewModels)             │
│                    ↓                        │
├─────────────────────────────────────────────┤
│          Application Layer                  │
│        (Use Cases, Application Services)    │
│                    ↓                        │
├─────────────────────────────────────────────┤
│            Domain Layer                     │
│   (Entities, Value Objects, Domain Services,│
│         Repository Interfaces)              │
│                    ↑                        │
├─────────────────────────────────────────────┤
│         Infrastructure Layer                │
│   (Repositories, External Services,         │
│        Data Sources, Frameworks)            │
└─────────────────────────────────────────────┘

依存性の方向: 外側 → 内側（Domain Layerは他に依存しない）
```

## ディレクトリ構造（クリーンアーキテクチャ準拠）

```
VocalisStudio/
├── App/
│   ├── VocalisStudioApp.swift              # アプリエントリーポイント
│   ├── AppDelegate.swift
│   └── DependencyContainer.swift           # DI Container
│
├── Domain/                                 # ドメイン層（最内層）
│   ├── Entities/
│   │   ├── Recording.swift                # 録音エンティティ
│   │   ├── TrainingSession.swift          # トレーニングセッション
│   │   └── User.swift                     # ユーザー
│   │
│   ├── ValueObjects/
│   │   ├── Pitch.swift                    # 音程
│   │   ├── AudioLevel.swift               # 音量レベル
│   │   ├── Duration.swift                 # 時間長
│   │   ├── ScalePattern.swift             # 音階パターン
│   │   └── AudioQuality.swift             # 音質設定
│   │
│   ├── DomainServices/
│   │   ├── AudioProcessingService.swift   # 音声処理ドメインサービス
│   │   └── PitchAnalysisService.swift     # ピッチ分析サービス
│   │
│   ├── RepositoryInterfaces/              # リポジトリインターフェース
│   │   ├── RecordingRepository.swift
│   │   ├── TrainingSessionRepository.swift
│   │   └── UserRepository.swift
│   │
│   └── DomainErrors/
│       └── DomainError.swift               # ドメイン固有エラー
│
├── Application/                            # アプリケーション層
│   ├── UseCases/
│   │   ├── Recording/
│   │   │   ├── StartRecordingUseCase.swift
│   │   │   ├── StopRecordingUseCase.swift
│   │   │   └── PlaybackRecordingUseCase.swift
│   │   │
│   │   ├── Training/
│   │   │   ├── StartTrainingSessionUseCase.swift
│   │   │   ├── RecordWithScaleUseCase.swift
│   │   │   └── AnalyzePitchUseCase.swift
│   │   │
│   │   └── History/
│   │       ├── GetRecordingHistoryUseCase.swift
│   │       └── DeleteRecordingUseCase.swift
│   │
│   ├── Services/                          # アプリケーションサービス
│   │   ├── AudioSessionService.swift
│   │   └── PermissionService.swift
│   │
│   └── DTOs/                              # Data Transfer Objects
│       ├── RecordingDTO.swift
│       └── TrainingResultDTO.swift
│
├── Infrastructure/                        # インフラストラクチャ層
│   ├── Repositories/                      # リポジトリ実装
│   │   ├── RecordingRepositoryImpl.swift
│   │   ├── TrainingSessionRepositoryImpl.swift
│   │   └── UserRepositoryImpl.swift
│   │
│   ├── DataSources/
│   │   ├── Local/
│   │   │   ├── FileDataSource.swift      # ファイルシステム
│   │   │   ├── CoreDataStack.swift       # Core Data
│   │   │   └── UserDefaultsDataSource.swift
│   │   │
│   │   └── Remote/                       # 将来のAPI連携用
│   │       └── APIClient.swift
│   │
│   ├── ExternalServices/                 # 外部サービス連携
│   │   ├── AVFoundation/
│   │   │   ├── AVAudioRecorderWrapper.swift
│   │   │   ├── AVAudioPlayerWrapper.swift
│   │   │   └── AVAudioSessionManager.swift
│   │   │
│   │   └── AudioProcessing/
│   │       └── AudioEngineManager.swift
│   │
│   └── Mappers/                          # データマッピング
│       ├── RecordingMapper.swift
│       └── TrainingSessionMapper.swift
│
├── Presentation/                          # プレゼンテーション層
│   ├── Views/
│   │   ├── Recording/
│   │   │   ├── RecordingView.swift
│   │   │   └── RecordingControlsView.swift
│   │   │
│   │   ├── Training/
│   │   │   ├── TrainingView.swift
│   │   │   └── ScalePlayerView.swift
│   │   │
│   │   └── History/
│   │       ├── HistoryListView.swift
│   │       └── HistoryDetailView.swift
│   │
│   ├── ViewModels/
│   │   ├── RecordingViewModel.swift
│   │   ├── TrainingViewModel.swift
│   │   └── HistoryViewModel.swift
│   │
│   └── UIComponents/                     # 共通UIコンポーネント
│       ├── AudioWaveformView.swift
│       ├── VolumeIndicator.swift
│       └── CircularProgressView.swift
│
├── Resources/
│   ├── Assets.xcassets/
│   ├── Sounds/
│   └── Localizable.strings
│
└── Tests/
    ├── DomainTests/                      # ドメイン層テスト
    │   ├── Entities/
    │   │   └── RecordingTests.swift
    │   ├── ValueObjects/
    │   │   └── PitchTests.swift
    │   └── DomainServices/
    │       └── AudioProcessingServiceTests.swift
    │
    ├── ApplicationTests/                 # アプリケーション層テスト
    │   └── UseCases/
    │       └── StartRecordingUseCaseTests.swift
    │
    ├── InfrastructureTests/              # インフラ層テスト
    │   └── Repositories/
    │       └── RecordingRepositoryTests.swift
    │
    ├── PresentationTests/                # プレゼンテーション層テスト
    │   └── ViewModels/
    │       └── RecordingViewModelTests.swift
    │
    └── IntegrationTests/                 # 統合テスト
        └── RecordingFlowTests.swift
```

## ドメインモデル設計（DDD）

### エンティティ

```swift
// Domain/Entities/Recording.swift
struct Recording: Entity {
    let id: RecordingId              // Value Object
    let sessionId: TrainingSessionId // Value Object
    let audioFileUrl: URL
    let startTime: Date
    let endTime: Date
    let audioQuality: AudioQuality   // Value Object
    let averagePitch: Pitch?         // Value Object
    
    var duration: Duration {          // Value Object
        Duration(seconds: endTime.timeIntervalSince(startTime))
    }
    
    // ドメインロジック
    func isValidForAnalysis() -> Bool {
        duration.seconds >= 5.0
    }
}

// Domain/Entities/TrainingSession.swift
struct TrainingSession: Entity {
    let id: TrainingSessionId
    let userId: UserId
    let scalePattern: ScalePattern   // Value Object
    let tempo: Tempo                 // Value Object
    let recordings: [Recording]
    let startedAt: Date
    let completedAt: Date?
    
    // ドメインロジック
    func calculateProgress() -> TrainingProgress {
        // トレーニング進捗計算
    }
    
    func isCompleted() -> Bool {
        completedAt != nil && !recordings.isEmpty
    }
}
```

### バリューオブジェクト

```swift
// Domain/ValueObjects/Pitch.swift
struct Pitch: ValueObject {
    let frequency: Double // Hz
    
    init?(frequency: Double) {
        guard frequency > 0 && frequency < 20000 else { return nil }
        self.frequency = frequency
    }
    
    var note: Note {
        // 周波数から音階を計算
        Note.fromFrequency(frequency)
    }
    
    func distanceFrom(_ other: Pitch) -> Cents {
        // セント値での差分計算
    }
}

// Domain/ValueObjects/ScalePattern.swift
enum ScalePattern: ValueObject {
    case fiveTone
    case majorScale
    case minorScale
    case chromatic
    case custom([Note])
    
    var notes: [Note] {
        switch self {
        case .fiveTone:
            return [.c4, .d4, .e4, .f4, .g4]
        case .majorScale:
            return [.c4, .d4, .e4, .f4, .g4, .a4, .b4, .c5]
        // ...
        }
    }
}
```

### ドメインサービス

```swift
// Domain/DomainServices/AudioProcessingService.swift
protocol AudioProcessingService {
    func analyzePitch(from audioData: Data) -> Result<[Pitch], DomainError>
    func calculateAveragePitch(pitches: [Pitch]) -> Pitch?
    func detectOnsets(in audioData: Data) -> [TimeInterval]
}

// Domain/DomainServices/PitchAnalysisService.swift
class PitchAnalysisService {
    func compareWithTarget(
        recorded: [Pitch],
        target: ScalePattern
    ) -> PitchAccuracy {
        // ピッチ精度の分析
    }
}
```

### リポジトリインターフェース

```swift
// Domain/RepositoryInterfaces/RecordingRepository.swift
protocol RecordingRepository {
    func save(_ recording: Recording) async throws
    func findById(_ id: RecordingId) async throws -> Recording?
    func findBySessionId(_ sessionId: TrainingSessionId) async throws -> [Recording]
    func delete(_ id: RecordingId) async throws
}
```

## アプリケーション層の設計

### ユースケース

```swift
// Application/UseCases/Recording/StartRecordingUseCase.swift
class StartRecordingUseCase {
    private let recordingRepository: RecordingRepository
    private let audioService: AudioSessionService
    
    init(
        recordingRepository: RecordingRepository,
        audioService: AudioSessionService
    ) {
        self.recordingRepository = recordingRepository
        self.audioService = audioService
    }
    
    func execute(
        sessionId: TrainingSessionId,
        quality: AudioQuality
    ) async throws -> Recording {
        // 1. 音声録音開始
        let url = try await audioService.startRecording(quality: quality)
        
        // 2. Recording エンティティ生成
        let recording = Recording(
            id: RecordingId.generate(),
            sessionId: sessionId,
            audioFileUrl: url,
            startTime: Date(),
            audioQuality: quality
        )
        
        // 3. リポジトリに保存
        try await recordingRepository.save(recording)
        
        return recording
    }
}
```

## インフラストラクチャ層の実装

### リポジトリ実装

```swift
// Infrastructure/Repositories/RecordingRepositoryImpl.swift
class RecordingRepositoryImpl: RecordingRepository {
    private let fileDataSource: FileDataSource
    private let mapper: RecordingMapper
    
    func save(_ recording: Recording) async throws {
        let data = mapper.toData(recording)
        try await fileDataSource.save(data, id: recording.id.value)
    }
    
    func findById(_ id: RecordingId) async throws -> Recording? {
        guard let data = try await fileDataSource.load(id: id.value) else {
            return nil
        }
        return mapper.toDomain(data)
    }
}
```

## プレゼンテーション層（MVVM）

### ViewModel

```swift
// Presentation/ViewModels/RecordingViewModel.swift
@MainActor
class RecordingViewModel: ObservableObject {
    @Published var state: RecordingState = .idle
    @Published var currentRecording: Recording?
    @Published var audioLevel: Float = 0.0
    
    private let startRecordingUseCase: StartRecordingUseCase
    private let stopRecordingUseCase: StopRecordingUseCase
    
    init(
        startRecordingUseCase: StartRecordingUseCase,
        stopRecordingUseCase: StopRecordingUseCase
    ) {
        self.startRecordingUseCase = startRecordingUseCase
        self.stopRecordingUseCase = stopRecordingUseCase
    }
    
    func startRecording() async {
        state = .recording
        do {
            currentRecording = try await startRecordingUseCase.execute(
                sessionId: currentSessionId,
                quality: .high
            )
        } catch {
            state = .error(error)
        }
    }
}
```

## 依存性注入（DI Container）

```swift
// App/DependencyContainer.swift
class DependencyContainer {
    static let shared = DependencyContainer()
    
    // Domain Services
    lazy var audioProcessingService: AudioProcessingService = {
        AudioProcessingServiceImpl()
    }()
    
    // Repositories
    lazy var recordingRepository: RecordingRepository = {
        RecordingRepositoryImpl(
            fileDataSource: FileDataSource(),
            mapper: RecordingMapper()
        )
    }()
    
    // Use Cases
    func makeStartRecordingUseCase() -> StartRecordingUseCase {
        StartRecordingUseCase(
            recordingRepository: recordingRepository,
            audioService: audioSessionService
        )
    }
    
    // ViewModels
    func makeRecordingViewModel() -> RecordingViewModel {
        RecordingViewModel(
            startRecordingUseCase: makeStartRecordingUseCase(),
            stopRecordingUseCase: makeStopRecordingUseCase()
        )
    }
}
```

## TDD実践例

### ドメイン層のテスト

```swift
// Tests/DomainTests/Entities/RecordingTests.swift
class RecordingTests: XCTestCase {
    func testRecordingDuration() {
        // Given
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(30)
        
        // When
        let recording = Recording(
            id: RecordingId.generate(),
            sessionId: TrainingSessionId.generate(),
            audioFileUrl: URL(fileURLWithPath: "/test"),
            startTime: startTime,
            endTime: endTime,
            audioQuality: .high
        )
        
        // Then
        XCTAssertEqual(recording.duration.seconds, 30)
    }
    
    func testRecordingValidation() {
        // Given: 短すぎる録音
        let recording = makeRecording(duration: 3)
        
        // When & Then
        XCTAssertFalse(recording.isValidForAnalysis())
    }
}
```

### ユースケースのテスト

```swift
// Tests/ApplicationTests/UseCases/StartRecordingUseCaseTests.swift
class StartRecordingUseCaseTests: XCTestCase {
    var useCase: StartRecordingUseCase!
    var mockRepository: MockRecordingRepository!
    var mockAudioService: MockAudioSessionService!
    
    override func setUp() {
        mockRepository = MockRecordingRepository()
        mockAudioService = MockAudioSessionService()
        useCase = StartRecordingUseCase(
            recordingRepository: mockRepository,
            audioService: mockAudioService
        )
    }
    
    func testStartRecording() async throws {
        // Given
        let sessionId = TrainingSessionId.generate()
        mockAudioService.stubRecordingUrl = URL(fileURLWithPath: "/audio.m4a")
        
        // When
        let recording = try await useCase.execute(
            sessionId: sessionId,
            quality: .high
        )
        
        // Then
        XCTAssertEqual(recording.sessionId, sessionId)
        XCTAssertTrue(mockRepository.saveCalled)
        XCTAssertTrue(mockAudioService.startRecordingCalled)
    }
}
```

## エラーハンドリング戦略

```swift
// Domain/DomainErrors/DomainError.swift
enum DomainError: Error {
    case invalidPitch(frequency: Double)
    case recordingTooShort(duration: Duration)
    case sessionNotFound(id: TrainingSessionId)
    
    var localizedDescription: String {
        switch self {
        case .invalidPitch(let frequency):
            return "無効な音程です: \(frequency)Hz"
        case .recordingTooShort(let duration):
            return "録音が短すぎます: \(duration.seconds)秒"
        case .sessionNotFound(let id):
            return "セッションが見つかりません: \(id)"
        }
    }
}
```

## まとめ

このクリーンアーキテクチャ設計により：

1. **ビジネスロジックの独立性**: ドメイン層は外部フレームワークに依存しない
2. **高いテスタビリティ**: 各層が独立してテスト可能
3. **変更への柔軟性**: UIやデータソースの変更がビジネスロジックに影響しない
4. **DDDによる表現力**: ボイストレーニングドメインを正確にモデリング
5. **TDDによる品質保証**: テストファーストで堅牢なコード