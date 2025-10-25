# SubscriptionDomain パッケージ分離 - 進捗サマリー

## 📊 現在の状態

### ✅ 完了済みフェーズ (Phase 1-6)

#### Phase 1: パッケージ構造の作成
- ✅ `Packages/SubscriptionDomain/` ディレクトリ作成
- ✅ `Package.swift` マニフェスト作成
- ✅ `README.md` ドキュメント作成
- ✅ Sources/Tests ディレクトリ構造作成

#### Phase 2: ドメインテストの移行 (TDD: テストファースト)
- ✅ `SubscriptionStatusTests.swift` 移行
- ✅ `SubscriptionRepositoryProtocolTests.swift` 移行
- ✅ テストファイルのインポート文更新 (`@testable import SubscriptionDomain`)

#### Phase 3: ドメインオブジェクトの移行 (9ファイル)
```
VocalisStudio/Domain/ → Packages/SubscriptionDomain/Sources/SubscriptionDomain/

移行済みファイル:
- Entities/SubscriptionStatus.swift
- ValueObjects/SubscriptionTier.swift
- ValueObjects/RecordingLimit.swift
- ValueObjects/RecordingLimitConfig.swift
- ValueObjects/Feature.swift
- ValueObjects/AdPolicy.swift
- ValueObjects/UserCohort.swift
- RepositoryProtocols/SubscriptionRepositoryProtocol.swift
- Errors/SubscriptionError.swift
```

#### Phase 4-5: インポート文の更新 (16ファイル)
- ✅ Application層: 5ファイル
- ✅ Infrastructure層: 3ファイル
- ✅ Presentation層: 8ファイル

すべてのファイルに `import SubscriptionDomain` を追加完了。

---

## ⏳ 次のステップ (Phase 6-9)

### Phase 6: Xcodeプロジェクトへのパッケージ依存関係追加 ⚠️ 手動作業必要

**方法1: Xcode GUI (推奨)**
1. Xcode で `VocalisStudio.xcodeproj` を開く
2. Project Navigator で `VocalisStudio` プロジェクトを選択
3. `VocalisStudio` ターゲットを選択
4. "Frameworks, Libraries, and Embedded Content" セクションに移動
5. "+" ボタンをクリック
6. "Add Other..." → "Add Package Dependency..."
7. ローカルパッケージから `Packages/SubscriptionDomain` を選択
8. "Add Package" をクリック

**方法2: Package.swift経由 (代替案)**
```swift
// もしプロジェクトがSPMベースなら (現在はXcodeプロジェクト)
.target(
    name: "VocalisStudio",
    dependencies: [
        "VocalisDomain",
        "SubscriptionDomain"  // 追加
    ]
)
```

**確認コマンド**:
```bash
# パッケージがビルドできることを確認
cd Packages/SubscriptionDomain
swift build

# テストが実行できることを確認
swift test
```

### Phase 7: テストの実行とGREEN状態の確認

**全テスト実行**:
```bash
# Xcode でのテスト実行
⌘+U

# またはコマンドラインから
xcodebuild test \
  -project VocalisStudio.xcodeproj \
  -scheme VocalisStudio \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -allowProvisioningUpdates
```

**期待される結果**:
- ✅ すべてのテストがパス (GREEN状態)
- ❌ エラーが出る場合: インポート文の追加漏れや依存関係の問題

**トラブルシューティング**:
```bash
# ビルドエラーがある場合、影響範囲を確認
grep -r "SubscriptionTier\|SubscriptionStatus\|Feature\|RecordingLimit" VocalisStudio/ \
  --include="*.swift" \
  | grep -v "import SubscriptionDomain"
```

### Phase 8: 内部Domainディレクトリの削除

**⚠️ 重要**: テストがすべてパスしてから実行してください。

```bash
# バックアップ作成 (念のため)
cp -r VocalisStudio/Domain VocalisStudio/Domain.backup

# 削除実行
rm -rf VocalisStudio/Domain

# Git での確認
git status
git add .
git commit -m "Remove internal Domain directory after package migration"
```

### Phase 9: ドメイン充実化プランの設計

**ユーザーからの要望**:
> "ドメインが軽薄すぎることがあります。インフラの機能に依存したアプリなので仕方ない部分もあるかもしれませんが、もう少しドメインの方にロジックを移していくということは検討できませんか"

**設計プランで検討する項目**:
1. **Recording関連のドメインロジック充実化**
   - 現状: Infrastructure層に録音ロジックが集中
   - 改善案: ドメインサービス、ビジネスルールの抽出

2. **ビジネスルールのドメイン層への移行**
   - 録音時間制限のバリデーション
   - サブスクリプションティアごとの機能制限
   - ユーザーコホートに基づいた振る舞い

3. **ドメインサービスの導入**
   - RecordingPolicyService
   - SubscriptionValidationService
   - UserPermissionService

4. **Value Objectsの充実**
   - 型安全性の向上
   - ビジネス制約のカプセル化

---

## 📋 完了チェックリスト

### ✅ 完了済み
- [x] Package.swift 作成
- [x] README.md 作成
- [x] ディレクトリ構造作成
- [x] ドメインテスト移行 (2ファイル)
- [x] ドメインオブジェクト移行 (9ファイル)
- [x] テストファイルのインポート更新
- [x] Application/Infrastructure/Presentationレイヤーのインポート更新 (16ファイル)

### ⏳ 残作業
- [ ] Xcodeプロジェクトにパッケージ依存関係を追加
- [ ] パッケージのビルド確認 (`swift build`)
- [ ] 全テスト実行とGREEN状態確認 (`⌘+U`)
- [ ] 内部 `VocalisStudio/Domain/` ディレクトリの削除
- [ ] ドメイン充実化プランの設計

---

## 📊 依存関係分析サマリー

**影響範囲**: 99箇所の参照、20ファイル

### レイヤー別の影響
| レイヤー | ファイル数 | 参照数 |
|---------|-----------|--------|
| Application | 5 | ~30 |
| Infrastructure | 3 | ~20 |
| Presentation | 8 | ~40 |
| Tests | 7 | ~9 |

### 移行リスク評価
- **リスクレベル**: 🟢 低
- **理由**: 純粋なドメインロジック、外部依存なし、インターフェース変更なし
- **推定作業時間**: 2.5時間 (Phase 1-6完了、残り0.5時間)

---

## 🔍 次の作業を始める前に

1. **Phase 6の手動作業**: Xcodeでパッケージ依存関係を追加してください
2. **ビルド確認**: `swift build` でパッケージが正しくビルドできることを確認
3. **テスト実行**: `⌘+U` ですべてのテストがパスすることを確認
4. **完了報告**: GREEN状態を確認したら、続行を指示してください

その後、Phase 8-9 (内部Domain削除とドメイン充実化プラン設計) に進みます。
