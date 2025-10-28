# 設計問題分析レポート

## 概要

録音再生停止時にターゲットピッチ表示が消えないバグの調査中に発見された設計上の問題点をマーティン・ファウラーの「リファクタリング」における「コードの不吉な臭い(Code Smells)」の観点から分析したドキュメント。

**作成日**: 2025-10-28
**対象バグ**: UIテスト `testTargetPitchShouldDisappearAfterStoppingPlayback` の失敗
**影響範囲**: `RecordingStateViewModel`, `PitchDetectionViewModel`, `AVAudioEngineScalePlayer`

---

## エグゼクティブサマリー

単純に見えるバグ（再生停止時のターゲットピッチ表示クリア）が複雑な非同期競合問題になっている根本原因は以下の3つの設計問題:

1. **共有状態の問題**: 2つのViewModelが同じ`scalePlayer`インスタンスを異なる目的で操作
2. **責任の分散**: スケール再生管理が複数のコンポーネントに分散
3. **非同期処理の複雑さ**: Task.isCancelledの非決定性とMainActorの順序保証なし

---

## 🔴 重大な設計問題

### 1. 責任の分散 (Divergent Change)

**問題箇所**:
- `RecordingStateViewModel.playLastRecording()` (lines 208-249)
- `PitchDetectionViewModel.startTargetPitchMonitoring()`

**問題の詳細**:

2つの異なるViewModelが同じ`scalePlayer`インスタンスを異なる目的で操作している:

```swift
// RecordingStateViewModel.swift:223-236
// 目的: 録音再生時のミュート付きスケール再生
if let settings = lastRecordingSettings {
    let scaleElements = settings.generateScaleWithKeyChange()
    try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)

    Task { [weak self] in
        try await self.scalePlayer.play(muted: true)
    }
}

// PitchDetectionViewModel.swift
// 目的: 録音中のターゲットピッチ監視
public func startTargetPitchMonitoring(settings: ScaleSettings) async throws {
    let scaleElements = settings.generateScaleWithKeyChange()
    try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)
    // + 監視ループでcurrentScaleElementを参照
}
```

**バグへの影響**:

1. `RecordingStateViewModel.stopPlayback()`が`scalePlayer.stop()`を呼ぶ
2. `scalePlayer._isPlaying = false`になる
3. `PitchDetectionViewModel`の監視ループが`currentScaleElement`を参照
4. `currentScaleElement`の実装:
   ```swift
   public var currentScaleElement: ScaleElement? {
       guard _isPlaying else { return nil }  // ← nilを返す
       // ...
   }
   ```
5. しかし`targetPitch`のクリアは別のタイミングで行われる
6. **レースコンディション発生**

**重大度**: 🔴 最高
**修正難易度**: 高
**バグへの寄与度**: ★★★★★

---

### 2. 機能の重複 (Duplicated Code)

**重複箇所**:

スケールロードと再生のロジックが2箇所に存在:

```swift
// RecordingStateViewModel.swift:223-225
let scaleElements = settings.generateScaleWithKeyChange()
try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)

// PitchDetectionViewModel.swift:76-77
let scaleElements = settings.generateScaleWithKeyChange()
try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)
```

**問題点**:
- 同じロジックが2箇所に存在 → メンテナンス負債
- 一方を変更してももう一方に反映されない
- テストが困難（両方をテストする必要）

**重大度**: 🟡 中
**修正難易度**: 中
**バグへの寄与度**: ★★★☆☆

---

### 3. 非同期処理の複雑さ (Temporal Coupling)

**問題箇所**: `PitchDetectionViewModel.stopTargetPitchMonitoring()`

**問題の詳細**:

現在の実装:
```swift
// PitchDetectionViewModel.swift:138-143
public func stopTargetPitchMonitoring() async {
    progressMonitorTask?.cancel()
    _ = await progressMonitorTask?.value  // タスク完了待ち
    progressMonitorTask = nil
    targetPitch = nil
}
```

監視ループ:
```swift
while !Task.isCancelled {
    if let currentElement = self.scalePlayer.currentScaleElement {
        await self.updateTargetPitchFromScaleElement(currentElement)
        // ↑ targetPitch が再度設定される可能性
    }
}
```

**タイミング依存の問題**:

1. `stopTargetPitchMonitoring()`がタスクをキャンセル
2. タスク完了を待つ
3. `targetPitch = nil`を設定
4. しかし、`Task.isCancelled`のチェックは非決定的
5. ループが1回余分に実行される可能性
6. `targetPitch`が再度設定される

**根本原因**:
- `Task.isCancelled`の非決定性
- MainActorの順序保証なし
- 2つの非同期処理（タスクキャンセルとプロパティ設定）の競合

**重大度**: 🔴 最高
**修正難易度**: 高
**バグへの寄与度**: ★★★★★

---

### 4. 共有可変状態 (Shared Mutable State)

**問題箇所**: `DependencyContainer`での依存注入

**現状の構造**:
```
DependencyContainer
  ↓ 同じインスタンス注入
  ├─→ RecordingStateViewModel.scalePlayer
  └─→ PitchDetectionViewModel.scalePlayer
```

**問題点**:
- 2つのViewModelが同じ可変オブジェクトを操作
- 一方の変更がもう一方に予期しない影響を与える
- デバッグが困難（どちらが状態を変更したか追跡できない）

**具体例**:
```swift
// RecordingStateViewModel
await scalePlayer.stop()  // _isPlaying = false

// PitchDetectionViewModel (別スレッド)
let element = scalePlayer.currentScaleElement  // nil を返す
```

**重大度**: 🔴 最高
**修正難易度**: 高
**バグへの寄与度**: ★★★★★

---

## 🟡 中程度の設計問題

### 5. 過度に長いメソッド (Long Method)

**問題箇所**: `RecordingStateViewModel.playLastRecording()` (42行)

**問題の詳細**:
- スケールロード
- バックグラウンドタスク起動
- 録音再生
- エラーハンドリング
- すべてが1つのメソッドに集約

**推奨**:
```swift
private func loadMutedScaleForPlayback(settings: ScaleSettings) async throws
private func startRecordingPlayback(url: URL) async throws
private func cleanupAfterPlayback()
```

**重大度**: 🟡 中
**修正難易度**: 低
**バグへの寄与度**: ★☆☆☆☆

---

### 6. 中間者 (Middle Man)

**問題箇所**: `PitchDetectionViewModel`

**問題の詳細**:
```swift
// PitchDetectionViewModel が scalePlayer の薄いラッパーになっている
public func startTargetPitchMonitoring(settings: ScaleSettings) async throws {
    try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)
    // + 監視ループ起動のみ
}
```

**疑問点**:
- `scalePlayer`を直接操作すべきか？
- ViewModelを介すべきか？
- どちらの責任か不明確

**重大度**: 🟡 中
**修正難易度**: 中
**バグへの寄与度**: ★★☆☆☆

---

### 7. データのかたまり (Data Clumps)

**問題箇所**: 複数箇所

**常に一緒に渡されるデータ**:
```swift
settings: ScaleSettings
scaleElements: [ScaleElement]
tempo: Tempo
```

**推奨**: 構造体にまとめる
```swift
struct ScalePlaybackContext {
    let settings: ScaleSettings
    let elements: [ScaleElement]
    let tempo: Tempo
}
```

**重大度**: 🟢 低
**修正難易度**: 低
**バグへの寄与度**: ★☆☆☆☆

---

## 🟢 軽微だが気になる点

### 8. マジックナンバー

**問題箇所**:
```swift
// RecordingStateViewModel.swift:241
Thread.sleep(forTimeInterval: 0.5)  // なぜ0.5秒?

// PitchDetectionViewModel.swift
targetPitchPollingIntervalNanoseconds: UInt64 = 100_000_000  // なぜ100ms?
```

**推奨**: 定数化して理由を明記
```swift
private static let playbackStartDelaySeconds = 0.5  // Wait for scale playback to start
private static let targetPitchPollingIntervalMs = 100  // Balance between responsiveness and performance
```

---

### 9. 重複したインポート

**問題箇所**: `RecordingStateViewModel.swift:2-8`

```swift
import SubscriptionDomain  // 4回も重複！
import SubscriptionDomain
import SubscriptionDomain
import SubscriptionDomain
```

**推奨**: 1回のみにする

---

### 10. 状態フラグの増殖

**問題箇所**: `AVAudioEngineScalePlayer.swift`

```swift
private var _isPlaying: Bool = false
private var _currentNoteIndex: Int = 0

// この2つの整合性管理が複雑
```

**問題点**:
- `_isPlaying`と`_currentNoteIndex`の整合性を常に保つ必要
- 不変条件: `_isPlaying == true` ならば `0 <= _currentNoteIndex < elements.count`
- しかし明示的にチェックされていない

**推奨**: 状態を列挙型にまとめる
```swift
enum PlaybackState {
    case idle
    case playing(currentIndex: Int)
    case completed
}
```

---

## 🎯 根本的な設計課題

### 11. 単一責任原則違反 (Single Responsibility Principle)

**現状の責務マッピング**:

```
RecordingStateViewModel:
- ✓ 録音状態管理 (適切)
- ✓ 録音再生管理 (適切)
- ❌ スケール再生管理 (越境 - PitchDetectionViewModelの責務と重複)

PitchDetectionViewModel:
- ✓ ピッチ検出管理 (適切)
- ✓ ターゲットピッチ監視 (適切)
- ❌ スケール進行追跡 (ScalePlayerに過度に依存)
```

**問題の可視化**:

```
         RecordingStateViewModel
                 ↓ play(muted: true)
            ScalePlayer (共有)
                 ↑ loadScaleElements()
         PitchDetectionViewModel
```

両方が同じオブジェクトを制御 → 競合発生

---

## 📊 影響度マトリクス

| 問題 | 重大度 | 修正難易度 | バグへの寄与度 | 優先度 |
|------|--------|------------|----------------|--------|
| 共有可変状態 | 🔴 高 | 高 | ★★★★★ | 1 |
| 責任の分散 | 🔴 高 | 高 | ★★★★★ | 1 |
| 非同期の複雑さ | 🔴 高 | 高 | ★★★★★ | 1 |
| 機能の重複 | 🟡 中 | 中 | ★★★☆☆ | 2 |
| 長いメソッド | 🟡 中 | 低 | ★☆☆☆☆ | 3 |
| 中間者 | 🟡 中 | 中 | ★★☆☆☆ | 3 |
| データのかたまり | 🟢 低 | 低 | ★☆☆☆☆ | 4 |
| マジックナンバー | 🟢 低 | 低 | ☆☆☆☆☆ | 4 |

---

## 🔧 推奨される修正戦略

### Phase 1: 短期的対処（現バグ修正）

**目的**: UIテストを通す

**アプローチ**:

#### Option A: 明示的な連携
```swift
// RecordingStateViewModel.swift
public func stopPlayback() async {
    await audioPlayer.stop()

    // PitchDetectionViewModelに停止を通知
    await pitchDetectionViewModel.stopTargetPitchMonitoring()

    isPlayingRecording = false
}
```

**メリット**:
- 実装が単純
- すぐに修正可能

**デメリット**:
- ViewModelの依存関係が増える
- 根本的な設計問題は未解決

#### Option B: 通知ベース
```swift
// ScalePlayerProtocol に追加
var isPlayingPublisher: AnyPublisher<Bool, Never> { get }

// PitchDetectionViewModel.swift
scalePlayer.isPlayingPublisher
    .sink { [weak self] isPlaying in
        if !isPlaying {
            self?.targetPitch = nil
        }
    }
    .store(in: &cancellables)
```

**メリット**:
- 疎結合
- 拡張性がある

**デメリット**:
- Combineの複雑さが増す
- デバッグが難しい

#### Option C: ステートフラグ
```swift
// PitchDetectionViewModel.swift
private nonisolated(unsafe) var isMonitoring: Bool = false

public func stopTargetPitchMonitoring() async {
    isMonitoring = false  // 即座に反映
    progressMonitorTask?.cancel()
    // ...
}

// 監視ループ
while !Task.isCancelled && isMonitoring {
    // ...
}
```

**メリット**:
- 決定的な動作
- レースコンディション回避

**デメリット**:
- `nonisolated(unsafe)`はSwift 6推奨ではない
- 根本的な設計問題は未解決

**推奨**: Option B（通知ベース）

---

### Phase 2: 中期的リファクタリング

**目的**: 設計問題の解消

#### Step 1: ScalePlaybackCoordinatorの導入

**新しいコンポーネント**:
```swift
@MainActor
public class ScalePlaybackCoordinator: ObservableObject {
    @Published public private(set) var currentTargetPitch: DetectedPitch?
    @Published public private(set) var isPlaying: Bool = false

    private let scalePlayer: ScalePlayerProtocol
    private var monitoringTask: Task<Void, Never>?

    // 録音中のスケール再生（音あり）
    public func startRecordingScale(settings: ScaleSettings) async throws {
        // ...
    }

    // 再生中のスケール再生（ミュート）
    public func startPlaybackScale(settings: ScaleSettings) async throws {
        // ...
    }

    public func stop() async {
        await scalePlayer.stop()
        currentTargetPitch = nil
        isPlaying = false
    }
}
```

**責務の再配分**:
```
RecordingStateViewModel:
- 録音状態管理
- 録音再生管理
- ❌ スケール再生管理 → ScalePlaybackCoordinatorへ移譲

PitchDetectionViewModel:
- ピッチ検出管理
- ❌ ターゲットピッチ監視 → ScalePlaybackCoordinatorから購読

ScalePlaybackCoordinator (NEW):
- スケール再生のライフサイクル管理
- 録音中/再生中の切り替え
- ターゲットピッチの供給
```

**メリット**:
- 単一責任原則に準拠
- スケール再生の状態が一元管理される
- テストが容易

#### Step 2: ViewModels間の依存を疎結合化

**Before**:
```
RecordingStateViewModel ─→ ScalePlayer ←─ PitchDetectionViewModel
                                          (共有状態)
```

**After**:
```
RecordingStateViewModel ─→ ScalePlaybackCoordinator
PitchDetectionViewModel ─→ ScalePlaybackCoordinator
                           (単方向データフロー)
```

---

### Phase 3: 長期的アーキテクチャ改善

**目的**: 堅牢で拡張性のあるアーキテクチャ

#### 改善1: 状態機械パターンの導入

**現状の問題**:
```swift
// 状態の組み合わせ爆発
recordingState: .idle | .countdown | .recording
isPlayingRecording: Bool
_isPlaying: Bool
```

**改善案**:
```swift
enum AppState {
    case idle
    case recordingCountdown(remaining: Int)
    case recording(session: RecordingSession, scalePlayback: ScalePlaybackState)
    case playback(url: URL, scalePlayback: ScalePlaybackState?)
}

enum ScalePlaybackState {
    case playing(currentElement: ScaleElement, progress: Double)
    case completed
}
```

**メリット**:
- 不正な状態遷移を型システムで防止
- 状態の可視化が容易
- テストが網羅的

#### 改善2: Combine Publisherによる状態変化の伝播

```swift
// ScalePlaybackCoordinator
@Published public private(set) var playbackState: ScalePlaybackState?

// PitchDetectionViewModel
coordinator.$playbackState
    .compactMap { $0?.currentTargetPitch }
    .assign(to: &$detectedPitch)
```

**メリット**:
- リアクティブな設計
- 自動的な状態同期
- メモリリークの心配なし

#### 改善3: 依存性注入の改善

**現状**: 同じインスタンスを複数のViewModelに注入

**改善案**: ファクトリーパターン
```swift
protocol ScalePlayerFactory {
    func create() -> ScalePlayerProtocol
}

// ViewModelごとに別インスタンスを使用
let recordingScalePlayer = factory.create()
let monitoringScalePlayer = factory.create()
```

---

## 📝 学んだ教訓

### 1. 単純なバグ ≠ 単純な原因

- UIテストの失敗: 「ターゲットピッチが消えない」
- 根本原因: 3つの重大な設計問題の組み合わせ

### 2. 共有状態は危険

- 2つのコンポーネントが同じ可変オブジェクトを操作
- → 予測不可能な動作
- → デバッグ困難

### 3. 責任の明確化が重要

- 「どのコンポーネントがスケール再生を管理するか」が不明確
- → 責務の分散
- → メンテナンス困難

### 4. 非同期処理には明示的な制御が必要

- `Task.isCancelled`は非決定的
- → ステートフラグなどの明示的な制御が必要

---

## 次のアクション

### 即座に実施すべき

1. [ ] Option B（通知ベース）でバグ修正
2. [ ] UIテストを通す
3. [ ] コミット

### 近いうちに実施すべき

1. [ ] `ScalePlaybackCoordinator`の設計
2. [ ] 責務の再配分計画
3. [ ] リファクタリングのPR作成

### 将来的に検討すべき

1. [ ] 状態機械パターンの導入
2. [ ] Combine Publisherベースの設計
3. [ ] アーキテクチャドキュメントの更新

---

## 参考文献

- Martin Fowler『リファクタリング（第2版）』
- Robert C. Martin『Clean Architecture』
- Swift Concurrency ドキュメント
- Combine フレームワーク ドキュメント

---

**最終更新**: 2025-10-28
**作成者**: Claude Code Analysis
**レビュー状態**: 未レビュー
