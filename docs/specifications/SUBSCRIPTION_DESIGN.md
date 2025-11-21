# 課金機能設計書

## 概要

Vocalis Studioの課金機能設計。Clean Architectureに準拠し、機能ごとの課金制御を柔軟に変更可能な設計。

**作成日**: 2025-10-21
**バージョン**: 1.0
**ステータス**: 設計フェーズ

## 課金モデル

### フリーミアムモデル

**無料機能**:
- 基本的な音声録音（時間制限あり: 30秒/回）
- 録音回数制限（1日3回まで）
- 基本的なピッチ表示（簡易版）

**有料機能（Premium）**:
- 無制限録音時間
- 無制限録音回数
- 高精度ピッチ検出（Phase 2D/3の改善版）
- 詳細なスペクトル分析
- 録音履歴のクラウド保存
- エクスポート機能（WAV/MP3）

### 課金プラン

**Phase 1（MVP）**:
- Free: 無料（基本機能のみ）
- Premium: 月額サブスクリプション

**Phase 2（拡張）**:
- Free: 無料
- Basic: 月額（中間プラン）
- Premium: 月額（全機能）

## アーキテクチャ設計

### ディレクトリ構造

```
VocalisStudio/
├── Domain/
│   ├── Entities/
│   │   └── SubscriptionStatus.swift       # 課金状態エンティティ
│   ├── ValueObjects/
│   │   ├── SubscriptionTier.swift         # 課金プラン（Free/Premium）
│   │   └── Feature.swift                  # 機能識別子
│   └── RepositoryProtocols/
│       └── SubscriptionRepositoryProtocol.swift
│
├── Application/
│   ├── UseCases/
│   │   ├── CheckFeatureAccessUseCase.swift     # 機能アクセス権チェック
│   │   ├── PurchaseSubscriptionUseCase.swift   # 購入処理
│   │   └── RestorePurchaseUseCase.swift        # 購入復元
│   └── Services/
│       └── FeatureGateService.swift            # 機能制限サービス
│
├── Infrastructure/
│   ├── Subscription/
│   │   ├── StoreKitSubscriptionRepository.swift  # StoreKit実装
│   │   └── MockSubscriptionRepository.swift      # テスト用モック
│   └── Persistence/
│       └── UserDefaultsSubscriptionCache.swift   # ローカルキャッシュ
│
└── Presentation/
    ├── Views/
    │   ├── PaywallView.swift                  # 課金画面
    │   └── FeatureLockedOverlay.swift         # 機能ロック表示
    └── ViewModels/
        └── SubscriptionViewModel.swift        # 課金状態管理
```

### レイヤー間依存関係

```
Presentation → Application → Domain ← Infrastructure
```

**依存ルール**:
- Domain層: 他のどの層にも依存しない
- Application層: Domainのみに依存
- Infrastructure層: Domainのインターフェースを実装
- Presentation層: ApplicationとDomainに依存

## コア実装

### Domain層

#### Feature（機能識別子）

```swift
// Domain/ValueObjects/Feature.swift
public enum Feature {
    case basicRecording          // 基本録音（30秒制限）
    case unlimitedRecording      // 無制限録音
    case limitedPitchDetection   // 簡易ピッチ検出
    case advancedPitchDetection  // 高精度ピッチ検出（Phase 2D/3）
    case spectrumAnalysis        // スペクトル分析
    case cloudStorage            // クラウド保存
    case exportFeature           // エクスポート
}
```

**拡張性**:
- 新機能追加: enumに1行追加
- 機能削除: enum定義を削除（コンパイラが使用箇所を検出）

#### SubscriptionTier（課金プラン）

```swift
// Domain/ValueObjects/SubscriptionTier.swift
public enum SubscriptionTier: String, Codable {
    case free
    case premium

    // Phase 2で追加予定
    // case basic
}
```

#### SubscriptionStatus（課金状態）

```swift
// Domain/Entities/SubscriptionStatus.swift
public struct SubscriptionStatus {
    public let tier: SubscriptionTier
    public let expirationDate: Date?
    public let isActive: Bool

    public func hasAccessTo(_ feature: Feature) -> Bool {
        switch (tier, feature) {
        // フリープランのアクセス権
        case (.free, .basicRecording):
            return true
        case (.free, .limitedPitchDetection):
            return true

        // プレミアムプランは全機能アクセス可能
        case (.premium, _):
            return isActive

        default:
            return false
        }
    }
}
```

**重要**: このロジックを変更するだけで、どの機能を課金対象にするかを制御可能

#### SubscriptionRepositoryProtocol

```swift
// Domain/RepositoryProtocols/SubscriptionRepositoryProtocol.swift
public protocol SubscriptionRepositoryProtocol {
    func getCurrentStatus() async throws -> SubscriptionStatus
    func purchase(tier: SubscriptionTier) async throws -> SubscriptionStatus
    func restorePurchases() async throws -> SubscriptionStatus
}
```

### Application層

#### CheckFeatureAccessUseCase

```swift
// Application/UseCases/CheckFeatureAccessUseCase.swift
public final class CheckFeatureAccessUseCase {
    private let subscriptionRepository: SubscriptionRepositoryProtocol

    public init(subscriptionRepository: SubscriptionRepositoryProtocol) {
        self.subscriptionRepository = subscriptionRepository
    }

    public func execute(feature: Feature) async throws -> Bool {
        let status = try await subscriptionRepository.getCurrentStatus()
        return status.hasAccessTo(feature)
    }
}
```

#### FeatureGateService

```swift
// Application/Services/FeatureGateService.swift
public final class FeatureGateService {
    private let checkAccessUseCase: CheckFeatureAccessUseCase

    public init(checkAccessUseCase: CheckFeatureAccessUseCase) {
        self.checkAccessUseCase = checkAccessUseCase
    }

    public func requireAccess(to feature: Feature) async throws {
        let hasAccess = try await checkAccessUseCase.execute(feature: feature)
        if !hasAccess {
            throw FeatureAccessError.subscriptionRequired(feature: feature)
        }
    }
}

public enum FeatureAccessError: Error {
    case subscriptionRequired(feature: Feature)
}
```

#### PurchaseSubscriptionUseCase

```swift
// Application/UseCases/PurchaseSubscriptionUseCase.swift
public final class PurchaseSubscriptionUseCase {
    private let subscriptionRepository: SubscriptionRepositoryProtocol

    public init(subscriptionRepository: SubscriptionRepositoryProtocol) {
        self.subscriptionRepository = subscriptionRepository
    }

    public func execute(tier: SubscriptionTier) async throws -> SubscriptionStatus {
        return try await subscriptionRepository.purchase(tier: tier)
    }
}
```

#### RestorePurchaseUseCase

```swift
// Application/UseCases/RestorePurchaseUseCase.swift
public final class RestorePurchaseUseCase {
    private let subscriptionRepository: SubscriptionRepositoryProtocol

    public init(subscriptionRepository: SubscriptionRepositoryProtocol) {
        self.subscriptionRepository = subscriptionRepository
    }

    public func execute() async throws -> SubscriptionStatus {
        return try await subscriptionRepository.restorePurchases()
    }
}
```

### Infrastructure層

#### StoreKitSubscriptionRepository

```swift
// Infrastructure/Subscription/StoreKitSubscriptionRepository.swift
import StoreKit

public final class StoreKitSubscriptionRepository: SubscriptionRepositoryProtocol {
    private let productIdentifier = "com.vocalisstudio.premium.monthly"

    public func getCurrentStatus() async throws -> SubscriptionStatus {
        // StoreKit 2でサブスクリプション状態を確認
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == productIdentifier {
                    return SubscriptionStatus(
                        tier: .premium,
                        expirationDate: transaction.expirationDate,
                        isActive: true
                    )
                }
            }
        }
        return SubscriptionStatus(tier: .free, expirationDate: nil, isActive: true)
    }

    public func purchase(tier: SubscriptionTier) async throws -> SubscriptionStatus {
        guard tier == .premium else {
            return SubscriptionStatus(tier: .free, expirationDate: nil, isActive: true)
        }

        let products = try await Product.products(for: [productIdentifier])
        guard let product = products.first else {
            throw SubscriptionError.productNotFound
        }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                await transaction.finish()
                return try await getCurrentStatus()
            }
            throw SubscriptionError.verificationFailed
        case .userCancelled:
            throw SubscriptionError.userCancelled
        case .pending:
            throw SubscriptionError.pending
        @unknown default:
            throw SubscriptionError.unknown
        }
    }

    public func restorePurchases() async throws -> SubscriptionStatus {
        try await AppStore.sync()
        return try await getCurrentStatus()
    }
}

public enum SubscriptionError: Error {
    case productNotFound
    case verificationFailed
    case userCancelled
    case pending
    case unknown
}
```

#### MockSubscriptionRepository

```swift
// Infrastructure/Subscription/MockSubscriptionRepository.swift
public final class MockSubscriptionRepository: SubscriptionRepositoryProtocol {
    public var mockStatus: SubscriptionStatus

    public init(mockStatus: SubscriptionStatus = SubscriptionStatus(tier: .free, expirationDate: nil, isActive: true)) {
        self.mockStatus = mockStatus
    }

    public func getCurrentStatus() async throws -> SubscriptionStatus {
        return mockStatus
    }

    public func purchase(tier: SubscriptionTier) async throws -> SubscriptionStatus {
        mockStatus = SubscriptionStatus(tier: tier, expirationDate: nil, isActive: true)
        return mockStatus
    }

    public func restorePurchases() async throws -> SubscriptionStatus {
        return mockStatus
    }
}
```

### Presentation層

#### SubscriptionViewModel

```swift
// Presentation/ViewModels/SubscriptionViewModel.swift
import Combine

@MainActor
public final class SubscriptionViewModel: ObservableObject {
    @Published public private(set) var subscriptionStatus: SubscriptionStatus
    @Published public private(set) var isLoading = false
    @Published public private(set) var error: Error?

    private let purchaseUseCase: PurchaseSubscriptionUseCase
    private let restoreUseCase: RestorePurchaseUseCase
    private let checkAccessUseCase: CheckFeatureAccessUseCase

    public init(
        purchaseUseCase: PurchaseSubscriptionUseCase,
        restoreUseCase: RestorePurchaseUseCase,
        checkAccessUseCase: CheckFeatureAccessUseCase,
        initialStatus: SubscriptionStatus = SubscriptionStatus(tier: .free, expirationDate: nil, isActive: true)
    ) {
        self.purchaseUseCase = purchaseUseCase
        self.restoreUseCase = restoreUseCase
        self.checkAccessUseCase = checkAccessUseCase
        self.subscriptionStatus = initialStatus
    }

    public func loadSubscriptionStatus() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Note: CheckFeatureAccessUseCaseは内部でgetCurrentStatus()を呼ぶため、
            // ここでは直接repositoryにアクセスせず、UseCaseを通じて状態を取得する設計も可能
            // 現状はシンプルにするため、この関数は省略可能
        } catch {
            self.error = error
        }
    }

    public func purchasePremium() async {
        isLoading = true
        defer { isLoading = false }

        do {
            subscriptionStatus = try await purchaseUseCase.execute(tier: .premium)
        } catch {
            self.error = error
        }
    }

    public func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            subscriptionStatus = try await restoreUseCase.execute()
        } catch {
            self.error = error
        }
    }

    public func hasAccess(to feature: Feature) -> Bool {
        subscriptionStatus.hasAccessTo(feature)
    }
}
```

## 既存機能への統合

### 録音機能への統合

```swift
// Application/UseCases/StartRecordingUseCase.swift（修正版）
public final class StartRecordingUseCase {
    private let audioRecorder: AudioRecorderProtocol
    private let recordingRepository: RecordingRepositoryProtocol
    private let featureGateService: FeatureGateService  // 追加

    public init(
        audioRecorder: AudioRecorderProtocol,
        recordingRepository: RecordingRepositoryProtocol,
        featureGateService: FeatureGateService  // 追加
    ) {
        self.audioRecorder = audioRecorder
        self.recordingRepository = recordingRepository
        self.featureGateService = featureGateService
    }

    public func execute(maxDuration: TimeInterval? = nil) async throws -> Recording {
        // 無制限録音を使用する場合はPremium必要
        if maxDuration == nil || maxDuration! > 30 {
            try await featureGateService.requireAccess(to: .unlimitedRecording)
        }

        // 既存の録音ロジック
        let recordingId = RecordingId()
        try await audioRecorder.startRecording()

        let recording = Recording(
            id: recordingId,
            duration: Duration(seconds: 0),
            createdAt: Date()
        )

        try await recordingRepository.save(recording)
        return recording
    }
}
```

### ピッチ検出への統合

```swift
// Infrastructure/Audio/RealtimePitchDetector.swift（修正版）
public final class RealtimePitchDetector: ObservableObject {
    @Published public private(set) var detectedPitch: Double?
    @Published public private(set) var confidence: Double = 0.0
    @Published public private(set) var spectrum: [Float]?

    private let featureGateService: FeatureGateService
    private var useAdvancedDetection: Bool = false

    public init(featureGateService: FeatureGateService) {
        self.featureGateService = featureGateService
        // 既存の初期化処理
    }

    public func enableAdvancedDetection() async throws {
        try await featureGateService.requireAccess(to: .advancedPitchDetection)
        useAdvancedDetection = true
    }

    private func detectPitchFromSamples(_ samples: [Float]) {
        if useAdvancedDetection {
            // Phase 2D/3の高精度検出
            detectWithAdvancedAlgorithm(samples)
        } else {
            // 簡易版（HPS harmonics=3, buffer=4096）
            detectWithBasicAlgorithm(samples)
        }
    }

    private func detectWithAdvancedAlgorithm(_ samples: [Float]) {
        // 既存のPhase 2D/3実装（buffer=8192, harmonics=7, Quinn's estimator, etc.）
    }

    private func detectWithBasicAlgorithm(_ samples: [Float]) {
        // 簡易版実装（buffer=4096, harmonics=3, parabolic interpolation）
    }
}
```

## DependencyContainerへの統合

```swift
// App/DependencyContainer.swift（修正版）
public final class DependencyContainer {
    // 既存のプロパティ
    public let recordingRepository: RecordingRepositoryProtocol
    public let audioRecorder: AudioRecorderProtocol

    // 課金関連の追加
    public let subscriptionRepository: SubscriptionRepositoryProtocol
    public let checkFeatureAccessUseCase: CheckFeatureAccessUseCase
    public let featureGateService: FeatureGateService
    public let purchaseSubscriptionUseCase: PurchaseSubscriptionUseCase
    public let restorePurchaseUseCase: RestorePurchaseUseCase

    public init() {
        // 課金リポジトリ初期化
        #if DEBUG
        self.subscriptionRepository = MockSubscriptionRepository()
        #else
        self.subscriptionRepository = StoreKitSubscriptionRepository()
        #endif

        // UseCase初期化
        self.checkFeatureAccessUseCase = CheckFeatureAccessUseCase(
            subscriptionRepository: subscriptionRepository
        )
        self.featureGateService = FeatureGateService(
            checkAccessUseCase: checkFeatureAccessUseCase
        )
        self.purchaseSubscriptionUseCase = PurchaseSubscriptionUseCase(
            subscriptionRepository: subscriptionRepository
        )
        self.restorePurchaseUseCase = RestorePurchaseUseCase(
            subscriptionRepository: subscriptionRepository
        )

        // 既存の初期化（featureGateServiceを注入）
        self.recordingRepository = InMemoryRecordingRepository()
        self.audioRecorder = AVAudioRecorderWrapper()

        // 既存UseCaseにfeatureGateServiceを注入
        // self.startRecordingUseCase = StartRecordingUseCase(
        //     audioRecorder: audioRecorder,
        //     recordingRepository: recordingRepository,
        //     featureGateService: featureGateService  // 追加
        // )
    }
}
```

## テスト戦略

### Unit Tests

```swift
// VocalisStudioTests/Application/CheckFeatureAccessUseCaseTests.swift
import XCTest
@testable import VocalisStudio

final class CheckFeatureAccessUseCaseTests: XCTestCase {
    func testFreeUserCanAccessBasicFeatures() async throws {
        // Arrange
        let mockRepo = MockSubscriptionRepository()
        mockRepo.mockStatus = SubscriptionStatus(tier: .free, expirationDate: nil, isActive: true)
        let useCase = CheckFeatureAccessUseCase(subscriptionRepository: mockRepo)

        // Act
        let hasAccess = try await useCase.execute(feature: .basicRecording)

        // Assert
        XCTAssertTrue(hasAccess)
    }

    func testFreeUserCannotAccessPremiumFeatures() async throws {
        // Arrange
        let mockRepo = MockSubscriptionRepository()
        mockRepo.mockStatus = SubscriptionStatus(tier: .free, expirationDate: nil, isActive: true)
        let useCase = CheckFeatureAccessUseCase(subscriptionRepository: mockRepo)

        // Act
        let hasAccess = try await useCase.execute(feature: .advancedPitchDetection)

        // Assert
        XCTAssertFalse(hasAccess)
    }

    func testPremiumUserCanAccessAllFeatures() async throws {
        // Arrange
        let mockRepo = MockSubscriptionRepository()
        mockRepo.mockStatus = SubscriptionStatus(tier: .premium, expirationDate: nil, isActive: true)
        let useCase = CheckFeatureAccessUseCase(subscriptionRepository: mockRepo)

        // Act & Assert
        XCTAssertTrue(try await useCase.execute(feature: .basicRecording))
        XCTAssertTrue(try await useCase.execute(feature: .advancedPitchDetection))
        XCTAssertTrue(try await useCase.execute(feature: .spectrumAnalysis))
    }
}
```

### Integration Tests

```swift
// VocalisStudioTests/Infrastructure/StoreKitSubscriptionRepositoryTests.swift
// Note: StoreKitのテストはSandbox環境で実施
import XCTest
import StoreKit
@testable import VocalisStudio

final class StoreKitSubscriptionRepositoryTests: XCTestCase {
    func testGetCurrentStatusForFreeUser() async throws {
        // Sandbox環境でのテスト実装
    }

    func testPurchaseFlow() async throws {
        // Sandbox環境でのテスト実装
    }
}
```

## 課金対象の変更方法

### ケース1: 既存機能を無料→有料に変更

**例**: 「スペクトル分析」を有料化

```swift
// Domain/Entities/SubscriptionStatus.swift

// Before（無料）
public func hasAccessTo(_ feature: Feature) -> Bool {
    switch (tier, feature) {
    case (.free, .spectrumAnalysis):  // この行を削除
        return true
    // ...
    }
}

// After（有料）
public func hasAccessTo(_ feature: Feature) -> Bool {
    switch (tier, feature) {
    // case (.free, .spectrumAnalysis):  削除
    //     return true
    // ...
    }
}
```

**変更箇所**: 1ファイル、1ケース削除
**影響範囲**: 自動的にすべての使用箇所で課金チェックが働く
**リリース**: アプリ更新が必要

### ケース2: 新機能を追加して課金対象に

**例**: 「AIボイスコーチ」機能を追加（Premium限定）

```swift
// Step 1: Featureに追加
public enum Feature {
    // 既存の機能
    case basicRecording
    case advancedPitchDetection

    // 新機能を追加
    case aiVoiceCoach  // 追加
}

// Step 2: アクセス制御（追加不要、デフォルトでPremium限定）
// SubscriptionStatus.hasAccessTo()で、
// case (.premium, _): return isActive
// により、自動的にPremium限定になる

// Step 3: 使用箇所で課金チェック
public func startAICoaching() async throws {
    try await featureGateService.requireAccess(to: .aiVoiceCoach)
    // AIコーチング開始
}
```

### ケース3: 中間プランを追加

**例**: Basicプランを追加（一部機能のみ使用可能）

```swift
// Step 1: SubscriptionTierに追加
public enum SubscriptionTier {
    case free
    case basic      // 追加
    case premium
}

// Step 2: アクセス制御ロジック更新
public func hasAccessTo(_ feature: Feature) -> Bool {
    switch (tier, feature) {
    case (.free, .basicRecording),
         (.free, .limitedPitchDetection):
        return true

    // Basicプランのアクセス権を定義
    case (.basic, .basicRecording),
         (.basic, .unlimitedRecording),
         (.basic, .advancedPitchDetection):
        return isActive

    // Premiumは全機能
    case (.premium, _):
        return isActive

    default:
        return false
    }
}

// Step 3: StoreKitに商品ID追加
// "com.vocalisstudio.basic.monthly"
```

## 実装スケジュール

### Phase 1: 基盤構築（1-2週間）

**目標**: テスト可能な課金システムの基礎を構築

1. **Domain層実装**（2日）
   - [ ] Feature.swift
   - [ ] SubscriptionTier.swift
   - [ ] SubscriptionStatus.swift
   - [ ] SubscriptionRepositoryProtocol.swift

2. **Application層実装**（2日）
   - [ ] CheckFeatureAccessUseCase.swift
   - [ ] FeatureGateService.swift
   - [ ] PurchaseSubscriptionUseCase.swift
   - [ ] RestorePurchaseUseCase.swift

3. **Infrastructure層（Mock）**（1日）
   - [ ] MockSubscriptionRepository.swift

4. **テスト実装**（2日）
   - [ ] CheckFeatureAccessUseCaseTests.swift
   - [ ] FeatureGateServiceTests.swift
   - [ ] SubscriptionStatusTests.swift

5. **DI Container統合**（1日）
   - [ ] DependencyContainer.swift更新

### Phase 2: StoreKit統合（2-3週間）

**目標**: 実際の購入フローを実装

1. **StoreKit実装**（3日）
   - [ ] StoreKitSubscriptionRepository.swift
   - [ ] エラーハンドリング
   - [ ] トランザクション処理

2. **App Store Connect設定**（2日）
   - [ ] 商品ID設定（com.vocalisstudio.premium.monthly）
   - [ ] サブスクリプション設定
   - [ ] 価格設定

3. **永続化実装**（2日）
   - [ ] UserDefaultsSubscriptionCache.swift
   - [ ] オフライン対応

4. **Sandbox テスト**（3日）
   - [ ] 購入フローテスト
   - [ ] 復元フローテスト
   - [ ] エラーケーステスト

### Phase 3: 機能制限統合（1-2週間）

**目標**: 既存機能に課金チェックを統合

1. **録音機能統合**（2日）
   - [ ] StartRecordingUseCaseにfeatureGateService注入
   - [ ] 時間制限ロジック実装
   - [ ] テスト更新

2. **ピッチ検出統合**（3日）
   - [ ] RealtimePitchDetectorに簡易版/高精度版の切り替え実装
   - [ ] featureGateService統合
   - [ ] テスト更新

3. **UI層実装**（3日）
   - [ ] PaywallView.swift
   - [ ] FeatureLockedOverlay.swift
   - [ ] SubscriptionViewModel.swift

### Phase 4: テスト・リリース（1週間）

**目標**: 本番リリース

1. **E2Eテスト**（2日）
   - [ ] フリーユーザー体験フロー
   - [ ] 購入フロー
   - [ ] 機能制限動作確認

2. **TestFlight**（3日）
   - [ ] ベータ版配信
   - [ ] フィードバック収集
   - [ ] バグフィックス

3. **本番リリース**（2日）
   - [ ] App Store審査
   - [ ] リリースノート準備
   - [ ] リリース

## セキュリティ考慮事項

### トランザクション検証

- StoreKit 2の`Transaction.currentEntitlements`を使用
- サーバーサイド検証は将来的に検討（Phase 2以降）

### ローカルキャッシュ

- UserDefaultsで課金状態をキャッシュ
- アプリ起動時に必ずStoreKitと同期
- 改ざん対策: StoreKitが真実の情報源

### エラーハンドリング

- ネットワークエラー時はキャッシュを使用
- キャッシュもない場合はフリープランとして扱う
- ユーザーに復元ボタンを表示

## 拡張可能性

### Remote Config対応（将来）

```swift
// Infrastructure/Configuration/RemoteFeatureConfiguration.swift
public final class RemoteFeatureConfiguration {
    public func loadConfiguration() async throws -> [Feature: SubscriptionTier] {
        // Firebase Remote Configから取得
        // アプリ更新なしで課金対象を変更可能
    }
}

// Domain/Entities/SubscriptionStatus.swift（動的版）
public struct SubscriptionStatus {
    private let configurations: [Feature: SubscriptionTier]

    public func hasAccessTo(_ feature: Feature) -> Bool {
        if let requiredTier = configurations[feature] {
            return tier >= requiredTier && isActive
        }
        // フォールバック: コードベースの設定
        return hasAccessToDefault(feature)
    }
}
```

### A/Bテスト対応（将来）

- ユーザーグループごとに異なる課金設定
- コンバージョン率の測定
- 最適な価格・機能セットの発見

## 参考資料

- [Apple StoreKit Documentation](https://developer.apple.com/documentation/storekit)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- Clean Architecture（Robert C. Martin）
- Domain-Driven Design（Eric Evans）

## 変更履歴

| 日付 | バージョン | 変更内容 | 担当者 |
|------|-----------|---------|--------|
| 2025-10-21 | 1.0 | 初版作成 | Claude |

## 承認

| 役割 | 氏名 | 承認日 | 署名 |
|------|------|--------|------|
| プロダクトオーナー | | | |
| テックリード | | | |
| アーキテクト | | | |
