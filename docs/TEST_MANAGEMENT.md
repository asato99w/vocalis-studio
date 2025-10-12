# テスト管理ガイドライン

## テストディレクトリ構造

```
VocalisStudioTests/
├── Domain/
│   ├── Entities/
│   │   ├── RecordingTests.swift
│   │   └── ScaleSettingsTests.swift
│   └── ValueObjects/
│       ├── MIDINoteTests.swift
│       ├── NotePatternTests.swift
│       ├── TempoTests.swift
│       ├── DurationTests.swift
│       └── RecordingIdTests.swift (作成予定)
├── Infrastructure/
│   ├── Audio/
│   │   ├── ScalePlayerTests.swift (作成予定)
│   │   ├── AudioRecorderTests.swift (作成予定)
│   │   └── AudioPlayerTests.swift (作成予定)
│   └── Repositories/
│       ├── RecordingRepositoryTests.swift (作成予定)
│       └── AudioFileRepositoryTests.swift (作成予定)
├── Application/
│   └── UseCases/
│       ├── StartRecordingWithScaleUseCaseTests.swift (作成予定)
│       ├── StopRecordingUseCaseTests.swift (作成予定)
│       ├── GetAllRecordingsUseCaseTests.swift (作成予定)
│       ├── DeleteRecordingUseCaseTests.swift (作成予定)
│       └── PlayRecordingUseCaseTests.swift (作成予定)
├── Presentation/
│   └── ViewModels/
│       ├── RecordingViewModelTests.swift (作成予定)
│       └── RecordingListViewModelTests.swift (作成予定)
└── Mocks/
    ├── MockScalePlayer.swift (作成予定)
    ├── MockAudioRecorder.swift (作成予定)
    ├── MockAudioPlayer.swift (作成予定)
    ├── MockRecordingRepository.swift (作成予定)
    └── MockAudioFileRepository.swift (作成予定)
```

## テスト命名規則

### ファイル名
```
{対象クラス名}Tests.swift
```

### テストメソッド名
```swift
func test{機能}_{条件}_{期待結果}() {
    // Given - When - Then
}
```

**例**:
```swift
func testInit_ValidValue_Success()
func testInit_OutOfRange_ThrowsError()
func testGenerateScale_SingleOctave_Returns117Notes()
```

## テストフレームワーク

**使用するフレームワーク**: XCTest（標準）

```swift
import XCTest
@testable import VocalisStudio

final class MIDINoteTests: XCTestCase {
    // テストメソッド
}
```

❌ **使用しない**: Swift Testing framework
- 理由: XCTestが標準で広く使われている
- iOS 15.0サポートのため

## テストの実行方法

### 全テスト実行
```bash
⌘+U in Xcode
```

### 特定のテストクラスのみ
```bash
xcodebuild test -only-testing:VocalisStudioTests/MIDINoteTests
```

### 特定のテストメソッドのみ
```bash
xcodebuild test -only-testing:VocalisStudioTests/MIDINoteTests/testInit_ValidValue_Success
```

### レイヤー別実行（推奨）
```bash
# ドメイン層のみ
xcodebuild test -only-testing:VocalisStudioTests/Domain

# インフラ層のみ
xcodebuild test -only-testing:VocalisStudioTests/Infrastructure
```

## テスト実行のベストプラクティス

### 1. 小さい単位で頻繁に実行
```
変更したクラスのテストのみ → 数秒
レイヤー全体のテスト → 数秒〜十数秒
全テスト → 数十秒（commit前のみ）
```

### 2. TDDサイクル中
```
1テストメソッドを実行 → Red確認 → 実装 → Green確認
```

### 3. Commit前
```
全テスト実行 → All Green確認 → Commit
```

## Mock管理

### Mocksディレクトリ
- 各層で共通使用するMockオブジェクトを配置
- プロトコルごとに1ファイル

### Mock命名規則
```swift
Mock{プロトコル名（ProtocolなしSuffix）}.swift
```

**例**:
- `MockScalePlayer.swift` ← `ScalePlayerProtocol`
- `MockRecordingRepository.swift` ← `RecordingRepositoryProtocol`

### Mock実装例
```swift
final class MockScalePlayer: ScalePlayerProtocol {
    var loadScaleCalled = false
    var playCalledまたは = false
    var stubbedError: Error?

    func loadScale(_ notes: [MIDINote], tempo: Tempo) async throws {
        loadScaleCalled = true
        if let error = stubbedError {
            throw error
        }
    }

    func play() async throws {
        playCalled = true
    }

    // その他の実装...
}
```

## テストカバレッジ目標

- **全体**: 80%以上
- **Domain層**: 90%以上（ビジネスロジックの中核）
- **Application層**: 85%以上（ユースケース）
- **Infrastructure層**: 70%以上（外部依存が多い）
- **Presentation層**: 75%以上（ViewModelのみ、Viewは除外）

## 削除すべきファイル

以下のファイルは削除推奨:
- `VocalisStudioTests.swift` - 空のサンプルテスト
- UITestsは当面不要（MVPでは使用しない）

## テスト実行時間の目安

| テストスコープ | 目標時間 |
|-------------|---------|
| 単一テストメソッド | < 0.01秒 |
| 単一テストクラス | < 0.1秒 |
| Domain層全体 | < 1秒 |
| 全Unit Tests | < 5秒 |
| Integration Tests | < 10秒 |
| 全テスト | < 15秒 |

※ シミュレータ起動時間は除く

## クリーンアップタスク

### 即座に実行
1. `VocalisStudio/VocalisStudioTests/VocalisStudioTests.swift` を削除
2. 不要なUITestsの確認

### 今後の運用
- 新しいテストは適切なディレクトリに配置
- XCTest frameworkを使用
- TDD原則に従ってテストファースト
