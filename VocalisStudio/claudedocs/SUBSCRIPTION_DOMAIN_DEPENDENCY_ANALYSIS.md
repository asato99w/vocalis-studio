# Subscription Domain Dependencies Analysis

## 調査日時
2025-10-24

## サマリー

**総参照数**: 99箇所 (Application/Infrastructure/Presentation layers)
**影響ファイル数**: 約20ファイル
**テストファイル数**: 7ファイル

## 1. Domain Layer (移行対象)

### 現在地: `VocalisStudio/Domain/`

#### Entities (1)
- `SubscriptionStatus.swift` - サブスクリプションステータスエンティティ

#### ValueObjects (6)
- `SubscriptionTier.swift` - サブスクリプションティア (.free, .premium, .premiumPlus)
- `RecordingLimit.swift` - 録音制限 (dailyCount, maxDuration)
- `RecordingLimitConfig.swift` - 録音制限設定インターフェース
- `Feature.swift` - 機能フラグ
- `AdPolicy.swift` - 広告ポリシー
- `UserCohort.swift` - ユーザーコホート

#### RepositoryProtocols (1)
- `SubscriptionRepositoryProtocol.swift` - サブスクリプションリポジトリインターフェース

#### Errors (1)
- `SubscriptionError.swift` - サブスクリプションエラー定義

## 2. Application Layer Dependencies

### UseCases (4 files)

#### Use Case Implementations
1. **`GetSubscriptionStatusUseCase.swift`**
   - 依存: `SubscriptionRepositoryProtocol`, `SubscriptionStatus`
   - 責務: サブスクリプションステータス取得

2. **`PurchaseSubscriptionUseCase.swift`**
   - 依存: `SubscriptionRepositoryProtocol`, `SubscriptionTier`
   - 責務: サブスクリプション購入処理

#### Use Case Protocols
3. **`Subscription/GetSubscriptionStatusUseCaseProtocol.swift`**
   - 依存: `SubscriptionStatus`
   - 責務: GetSubscriptionStatusUseCase のインターフェース定義

4. **`Subscription/PurchaseSubscriptionUseCaseProtocol.swift`**
   - 依存: `SubscriptionTier`
   - 責務: PurchaseSubscriptionUseCase のインターフェース定義

## 3. Infrastructure Layer Dependencies

### Repository Implementations (3 files)

#### StoreKit Integration
1. **`Infrastructure/Subscription/StoreKitSubscriptionRepository.swift`**
   - 依存: `SubscriptionRepositoryProtocol`, `SubscriptionStatus`, `SubscriptionTier`, `UserCohort`
   - 責務: StoreKit を使用したサブスクリプション管理の実装
   - 主要メソッド:
     - `getCurrentStatus() async throws -> SubscriptionStatus`
     - `purchase(tier:) async throws`
     - `restorePurchases() async throws`
   - StoreKit API依存:
     - `Product.SubscriptionInfo.Status`
     - `Transaction`
     - `AppStore`

2. **`Infrastructure/Subscription/StoreKitProtocol.swift`**
   - 依存: `SubscriptionTier`
   - 責務: StoreKit APIのプロトコル定義 (テスト容易性のため)

3. **`Infrastructure/Subscription/` (ディレクトリ)**
   - StoreKit関連の実装を集約

## 4. Presentation Layer Dependencies

### ViewModels (3 files)

1. **`SubscriptionViewModel.swift`**
   - 依存:
     - `SubscriptionStatus` (@Published property)
     - `SubscriptionTier` (purchase parameter)
     - `GetSubscriptionStatusUseCaseProtocol`
     - `PurchaseSubscriptionUseCaseProtocol`
   - 責務: サブスクリプション管理UI の状態管理
   - 主要メソッド:
     - `loadCurrentStatus() async`
     - `purchase(tier:) async`
     - `restorePurchases() async`
     - `setDebugTier(_:)` (デバッグ用)

2. **`RecordingStateViewModel.swift`**
   - 依存:
     - `SubscriptionTier` (@Published property: currentTier)
     - `RecordingLimit` (録音制限チェック)
     - `RecordingLimitConfig` (ティア別制限取得)
   - 責務: 録音機能の状態管理 (サブスクリプションティアに応じた制限適用)
   - 主要ロジック:
     - `startRecording()` - 録音制限チェック
     - `checkRecordingLimit()` - ティア別制限検証

3. **`RecordingViewModel.swift`**
   - 依存:
     - `SubscriptionTier` (@Published property: currentTier)
   - 責務: 録音ViewModelとサブスクリプションティア連携 (RecordingStateViewModel への移行済み)

4. **`PaywallViewModel.swift`**
   - 依存:
     - `SubscriptionStatus` (@Published property)
     - `SubscriptionTier` (ティア選択)
     - `Feature` (ティア別機能表示)
     - `GetSubscriptionStatusUseCaseProtocol`
   - 責務: ペイウォール画面の状態管理
   - 主要メソッド:
     - `selectTier(_:)`
     - `availableTiers: [SubscriptionTier]`
     - `features(for:) -> [Feature]`

## 5. Test Layer Dependencies

### Domain Tests (2 files)
1. **`SubscriptionStatusTests.swift`**
   - テスト対象: `SubscriptionStatus` entity
   - テストケース数: 初期化、デフォルト値、tier取得等

2. **`SubscriptionRepositoryProtocolTests.swift`**
   - テスト対象: `SubscriptionRepositoryProtocol` interface

### Application Tests (2 files)
3. **`GetSubscriptionStatusUseCaseTests.swift`**
   - テスト対象: `GetSubscriptionStatusUseCase`
   - モック: `MockSubscriptionRepository`

4. **`PurchaseSubscriptionUseCaseTests.swift`**
   - テスト対象: `PurchaseSubscriptionUseCase`
   - モック: `MockSubscriptionRepository`

### Infrastructure Tests (1 file)
5. **`StoreKitSubscriptionRepositoryTests.swift`**
   - テスト対象: `StoreKitSubscriptionRepository`
   - モック: StoreKit APIのモック

### Presentation Tests (2 files)
6. **`SubscriptionViewModelTests.swift`**
   - テスト対象: `SubscriptionViewModel`
   - モック: UseCase mocks

7. **`SubscriptionViewModelDebugTests.swift`**
   - テスト対象: `SubscriptionViewModel` debug features
   - テストケース: デバッグティア設定機能

## 6. Migration Impact Analysis

### 高影響 (High Impact)

**ViewModels (4 files)**
- `SubscriptionViewModel.swift`
- `RecordingStateViewModel.swift`
- `RecordingViewModel.swift`
- `PaywallViewModel.swift`

**変更内容**: すべての `import` 文を更新
```swift
// Before
(no explicit import - same module)

// After
import SubscriptionDomain
```

### 中影響 (Medium Impact)

**UseCases (4 files)**
- `GetSubscriptionStatusUseCase.swift`
- `PurchaseSubscriptionUseCase.swift`
- `GetSubscriptionStatusUseCaseProtocol.swift`
- `PurchaseSubscriptionUseCaseProtocol.swift`

**変更内容**: import文追加
```swift
// After
import SubscriptionDomain
```

**Infrastructure (2 files)**
- `StoreKitSubscriptionRepository.swift`
- `StoreKitProtocol.swift`

**変更内容**: import文追加
```swift
// After
import SubscriptionDomain
```

### 低影響 (Low Impact)

**Tests (7 files)**
- すべてのテストファイル

**変更内容**: import文追加
```swift
// After
@testable import SubscriptionDomain
```

## 7. Migration Strategy

### Phase 1: Package Creation ✅
- [ ] Create `Packages/SubscriptionDomain/` directory
- [ ] Create `Package.swift` with proper configuration
- [ ] Create directory structure (Entities, ValueObjects, RepositoryProtocols, Errors)

### Phase 2: Tests Migration (TDD: Tests First) ✅
- [ ] Move domain tests to `SubscriptionDomain/Tests/`
- [ ] Add `@testable import SubscriptionDomain` to tests
- [ ] Verify tests compile (will fail - RED state expected)

### Phase 3: Domain Objects Migration ✅
- [ ] Move Entities (`SubscriptionStatus`)
- [ ] Move ValueObjects (6 files)
- [ ] Move RepositoryProtocols (`SubscriptionRepositoryProtocol`)
- [ ] Move Errors (`SubscriptionError`)
- [ ] Verify tests pass (GREEN state)

### Phase 4: Import Statement Updates ✅
- [ ] Update Application layer imports (4 files)
- [ ] Update Infrastructure layer imports (2 files)
- [ ] Update Presentation layer imports (4 files)
- [ ] Update all test imports (7 files)

### Phase 5: Project Configuration ✅
- [ ] Add `SubscriptionDomain` package dependency to VocalisStudio.xcodeproj
- [ ] Update scheme settings if necessary
- [ ] Verify project builds

### Phase 6: Validation ✅
- [ ] Run all tests (GREEN state required)
- [ ] Build VocalisStudio target
- [ ] Verify no circular dependencies

### Phase 7: Cleanup ✅
- [ ] Delete `VocalisStudio/Domain/` directory
- [ ] Remove references from Xcode project
- [ ] Final test run

## 8. Risk Assessment

### 低リスク (Low Risk)
- **ドメインオブジェクトの移動**: 純粋なビジネスロジック、外部依存なし
- **テストの移動**: 既存テストをそのまま移行可能

### 中リスク (Medium Risk)
- **Import文の一括更新**: 20ファイル程度、手作業エラーの可能性
- **Xcodeプロジェクト設定**: パッケージ依存関係の追加

### 高リスク (High Risk)
なし

### リスク軽減策
1. **TDD準拠**: テストを先に移行し、各ステップでGREEN状態を維持
2. **段階的移行**: 一度に1つのファイルグループを移行
3. **自動検証**: 各ステップ後にビルド・テスト実行

## 9. Estimated Effort

- **Phase 1 (Package Creation)**: 15分
- **Phase 2 (Tests Migration)**: 30分
- **Phase 3 (Domain Migration)**: 30分
- **Phase 4 (Import Updates)**: 30分
- **Phase 5 (Project Config)**: 15分
- **Phase 6 (Validation)**: 15分
- **Phase 7 (Cleanup)**: 15分

**合計見積もり**: 約2.5時間

## 10. Success Criteria

✅ **完了条件**:
1. すべてのテストがGREEN状態
2. VocalisStudioターゲットがビルド成功
3. `VocalisStudio/Domain/` ディレクトリが存在しない
4. `Packages/SubscriptionDomain/` が完全に独立
5. Clean Architectureの依存関係ルール準拠

## 11. Next Steps

**Task 1完了** ✅: 依存関係調査完了
**Task 2開始準備** ✅: SubscriptionDomainパッケージ作成の詳細設計完了

**次のアクション**: SubscriptionDomainパッケージの `Package.swift` と ディレクトリ構造を作成
