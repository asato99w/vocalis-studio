# Code Problems Detailed Analysis - Mapped to Code Smells

## 目次

1. [Divergent Change（変更の分散）](#1-divergent-change変更の分散)
2. [Duplicated Code（重複コード）](#2-duplicated-code重複コード)
3. [Long Method（長いメソッド）](#3-long-method長いメソッド)
4. [Temporal Coupling（時間的結合）](#4-temporal-coupling時間的結合)
5. [Feature Envy（機能への嫉妬）](#5-feature-envy機能への嫉妬)
6. [Data Clumps（データの群れ）](#6-data-clumps データの群れ)
7. [Middle Man（仲介者）](#7-middle-man仲介者)
8. [Shotgun Surgery（散弾銃手術）](#8-shotgun-surgery散弾銃手術)
9. [Primitive Obsession（基本型への執着）](#9-primitive-obsession基本型への執着)
10. [Comments（コメント）](#10-commentsコメント)
11. [その他の設計問題](#11-その他の設計問題)

---

## 1. Divergent Change（変更の分散）

### 定義
1つのクラスが異なる理由で頻繁に変更される状態。Single Responsibility Principle（単一責任の原則）の違反。

### Vocalis Studioでの具体的問題

#### 問題1: RecordingStateViewModel - 2つの責任を持つ

**場所**: `RecordingStateViewModel.swift`

**問題コード**:
```swift
@MainActor
public class RecordingStateViewModel: ObservableObject {
    // 責任1: 録音制御
    private let startRecordingUseCase: StartRecordingUseCaseProtocol
    private let stopRecordingUseCase: StopRecordingUseCaseProtocol
    private let audioPlayer: AudioPlayerProtocol

    // 責任2: スケール再生制御
    private let scalePlayer: ScalePlayerProtocol

    public func startRecording(settings: ScaleSettings? = nil) async {
        // 録音制御ロジック
    }

    public func playLastRecording() async {
        // スケール再生ロジックも含まれる (lines 223-237)
        if let settings = lastRecordingSettings {
            let scaleElements = settings.generateScaleWithKeyChange()
            try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)

            Task { [weak self] in
                try await self.scalePlayer.play(muted: true)
            }
        }

        // 録音再生ロジック
        try await audioPlayer.play(url: url)
    }
}
```

**変更理由の分散**:
1. **録音機能の変更**: 録音開始/停止、セッション管理、ファイル保存
2. **スケール再生の変更**: スケール読み込み、テンポ制御、ミュート制御

**影響**:
- 録音機能の変更でスケール再生コードも触れてしまうリスク
- テストが複雑（2つの責任を同時にテストする必要）
- 変更の影響範囲が不明確

**変更履歴の証拠**:
- Commit c1ff0ad: UI test実行サポート追加
- Commit e8dcaed: ピッチ検出のリアルタイム同期修正（スケール再生に関連）
- Commit 82563e8: ピッチ検出バグ修正（録音とスケール再生の両方に影響）

---

#### 問題2: PitchDetectionViewModel - 2つの責任を持つ

**場所**: `PitchDetectionViewModel.swift`

**問題コード**:
```swift
@MainActor
public class PitchDetectionViewModel: ObservableObject {
    // 責任1: ピッチ検出
    private let pitchDetector: PitchDetectorProtocol
    private var pitchDetectionTask: Task<Void, Never>?

    // 責任2: スケール進行監視
    private let scalePlayer: ScalePlayerProtocol
    private var progressMonitorTask: Task<Void, Never>?

    public func startTargetPitchMonitoring(settings: ScaleSettings) async throws {
        // スケール読み込み（責任2）
        let scaleElements = settings.generateScaleWithKeyChange()
        try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)

        // 監視ループ（責任1と2が混在）
        progressMonitorTask = Task { [weak self] in
            while !Task.isCancelled {
                // スケール進行取得（責任2）
                if let currentElement = self.scalePlayer.currentScaleElement {
                    await self.updateTargetPitchFromScaleElement(currentElement)
                }

                // ピッチ検出は Combine で自動更新（責任1）
                try? await Task.sleep(nanoseconds: pollingInterval)
            }
        }
    }
}
```

**変更理由の分散**:
1. **ピッチ検出の変更**: アルゴリズム改善、精度調整、信頼度計算
2. **スケール進行監視の変更**: ポーリング間隔、currentElement取得、進行状態管理

**影響**:
- ピッチ検出アルゴリズムの変更でスケール進行コードに影響
- スケールプレイヤーの変更でピッチ検出ロジックに影響
- 両方の責任に対するテストが必要

---

#### 問題3: AVAudioEngineScalePlayer - 3つの責任を持つ

**場所**: `AVAudioEngineScalePlayer.swift`

**問題コード**:
```swift
public class AVAudioEngineScalePlayer: ScalePlayerProtocol {
    // 責任1: AVAudioEngine管理
    private let engine: AVAudioEngine
    private let sampler: AVAudioUnitSampler

    // 責任2: 再生状態管理
    private var _isPlaying: Bool = false
    private var _currentNoteIndex: Int = 0
    private var playbackTask: Task<Void, Error>?

    // 責任3: スケールデータ管理
    private var scale: [MIDINote] = []  // Legacy support
    private var scaleElements: [ScaleElement] = []  // New format
    private var tempo: Tempo?

    public var currentScaleElement: ScaleElement? {
        // 状態とデータの混在
        guard _isPlaying else { return nil }
        guard _currentNoteIndex >= 0 else { return nil }

        if !scaleElements.isEmpty {
            guard _currentNoteIndex < scaleElements.count else { return nil }
            return scaleElements[_currentNoteIndex]
        }
        // ...
    }
}
```

**変更理由の分散**:
1. **AVFoundation統合の変更**: エンジン設定、サンプラー設定、音源読み込み
2. **再生制御の変更**: 再生/停止、Task管理、状態遷移
3. **スケールフォーマットの変更**: レガシー対応、新フォーマット対応、データ変換

**影響**:
- AVFoundationの変更でスケールフォーマット処理に影響
- スケールフォーマットの変更で再生制御に影響
- 3つの責任すべてをテストする必要がある

---

### 推奨リファクタリング

#### Extract Class（クラスの抽出）

**Before**:
```swift
class RecordingStateViewModel {
    // 録音 + スケール再生
}
```

**After**:
```swift
class RecordingStateViewModel {
    // 録音のみ
    private let scalePlaybackCoordinator: ScalePlaybackCoordinator
}

class ScalePlaybackCoordinator {
    // スケール再生の責任を集約
    func startScalePlayback(settings: ScaleSettings, muted: Bool) async throws
    func stopScalePlayback() async
}
```

---

## 2. Duplicated Code（重複コード）

### 定義
同じコード構造が複数箇所に存在する状態。DRY（Don't Repeat Yourself）原則の違反。

### Vocalis Studioでの具体的問題

#### 問題1: スケール読み込みロジックの重複

**場所1**: `RecordingStateViewModel.swift:224-225`
```swift
let scaleElements = settings.generateScaleWithKeyChange()
try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)
```

**場所2**: `PitchDetectionViewModel.swift:67-68`
```swift
let scaleElements = settings.generateScaleWithKeyChange()
try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)
```

**問題点**:
- まったく同じロジックが2箇所に存在
- `generateScaleWithKeyChange()` の呼び出しタイミングが両方同じ
- `loadScaleElements()` のパラメータも同じ

**変更時のリスク**:
```swift
// 例: スケール生成にトランスポーズパラメータを追加する場合
// ❌ 両方の箇所を変更する必要がある（変更漏れのリスク）

// RecordingStateViewModel.swift
let scaleElements = settings.generateScaleWithKeyChange(transpose: +2)  // 変更1
try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)

// PitchDetectionViewModel.swift
let scaleElements = settings.generateScaleWithKeyChange(transpose: +2)  // 変更2
try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)
```

**影響**:
- バグのリスク: 片方だけ変更してもう片方を忘れる
- 保守コスト: 2箇所を常に同期させる必要
- テストコスト: 両方の箇所に対する同じテストが必要

---

#### 問題2: Task sleep パターンの重複

**場所1**: `AVAudioEngineScalePlayer.swift:206`
```swift
try await Task.sleep(nanoseconds: UInt64(self.tempo!.secondsPerNote * 0.9 * 1_000_000_000))
```

**場所2**: `AVAudioEngineScalePlayer.swift:211`
```swift
try await Task.sleep(nanoseconds: UInt64(self.tempo!.secondsPerNote * 0.1 * 1_000_000_000))
```

**場所3**: `AVAudioEngineScalePlayer.swift:235`
```swift
try await Task.sleep(nanoseconds: UInt64(duration * 0.9 * 1_000_000_000))
```

**場所4**: `AVAudioEngineScalePlayer.swift:241`
```swift
try await Task.sleep(nanoseconds: UInt64(duration * 0.1 * 1_000_000_000))
```

**場所5**: `AVAudioEngineScalePlayer.swift:252`
```swift
try await Task.sleep(nanoseconds: UInt64(duration * 0.9 * 1_000_000_000))
```

**場所6**: `AVAudioEngineScalePlayer.swift:260`
```swift
try await Task.sleep(nanoseconds: UInt64(duration * 0.1 * 1_000_000_000))
```

**問題点**:
- 同じ計算式が6箇所に重複
- Magic Number（0.9と0.1）が埋め込まれている
- 計算式の意図が不明確（なぜ0.9と0.1なのか？）

**変更時のリスク**:
```swift
// 例: レガート比率を調整する場合
// ❌ 6箇所すべてを変更する必要がある

// Before: 0.9 / 0.1
// After: 0.85 / 0.15
// → 6箇所の変更が必要、変更漏れのリスク大
```

---

#### 問題3: SubscriptionDomain import の重複

**場所**: `RecordingStateViewModel.swift:2-8`
```swift
import Foundation
import SubscriptionDomain  // 1回目
import VocalisDomain
import SubscriptionDomain  // 2回目
import Combine
import SubscriptionDomain  // 3回目
import OSLog
import SubscriptionDomain  // 4回目
```

**問題点**:
- 同じimport文が4回出現
- コピー&ペーストのミスの証拠
- コンパイラは警告を出すが、コードの品質を示している

**影響**:
- コードの信頼性低下
- レビュー時の印象悪化
- 注意力不足を示唆

---

### 推奨リファクタリング

#### Extract Method（メソッドの抽出）

**Before**:
```swift
// RecordingStateViewModel.swift
let scaleElements = settings.generateScaleWithKeyChange()
try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)

// PitchDetectionViewModel.swift
let scaleElements = settings.generateScaleWithKeyChange()
try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)
```

**After**:
```swift
// ScalePlaybackCoordinator.swift
func loadScaleForPlayback(settings: ScaleSettings) async throws {
    let scaleElements = settings.generateScaleWithKeyChange()
    try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)
}

// RecordingStateViewModel.swift
try await scalePlaybackCoordinator.loadScaleForPlayback(settings: settings)

// PitchDetectionViewModel.swift
try await scalePlaybackCoordinator.loadScaleForPlayback(settings: settings)
```

---

#### Extract Constant（定数の抽出）

**Before**:
```swift
try await Task.sleep(nanoseconds: UInt64(duration * 0.9 * 1_000_000_000))
try await Task.sleep(nanoseconds: UInt64(duration * 0.1 * 1_000_000_000))
```

**After**:
```swift
private struct NoteDuration {
    static let legatoRatio: Double = 0.9
    static let gapRatio: Double = 0.1
    static let nanosecondsPerSecond: Double = 1_000_000_000

    static func legato(duration: TimeInterval) -> UInt64 {
        UInt64(duration * legatoRatio * nanosecondsPerSecond)
    }

    static func gap(duration: TimeInterval) -> UInt64 {
        UInt64(duration * gapRatio * nanosecondsPerSecond)
    }
}

// 使用箇所
try await Task.sleep(nanoseconds: NoteDuration.legato(duration: duration))
try await Task.sleep(nanoseconds: NoteDuration.gap(duration: duration))
```

---

## 3. Long Method（長いメソッド）

### 定義
メソッドが長すぎて理解が困難な状態。メソッドの責任が多すぎる証拠。

### Vocalis Studioでの具体的問題

#### 問題1: playLastRecording() - 42行

**場所**: `RecordingStateViewModel.swift:208-249`

**問題コード**:
```swift
public func playLastRecording() async {
    // 行1-5: ガード節
    guard let url = lastRecordingURL else {
        Logger.viewModel.warning("Play recording failed: no recording available")
        errorMessage = "No recording available"
        return
    }
    guard !isPlayingRecording else { return }

    // 行8: ログ
    Logger.viewModel.info("Starting playback: \(url.lastPathComponent)")

    // 行10-42: 複雑な処理
    do {
        isPlayingRecording = true

        // スケール設定がある場合の処理（14行）
        if let settings = lastRecordingSettings {
            let scaleElements = settings.generateScaleWithKeyChange()
            try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)

            // バックグラウンドでミュートスケール再生
            Task { [weak self] in
                guard let self = self else { return }
                do {
                    try await self.scalePlayer.play(muted: true)
                } catch {
                    // Silently handle muted scale playback errors
                }
            }
        }

        // 録音の再生
        try await audioPlayer.play(url: url)

        // 完了処理
        isPlayingRecording = false
        Logger.viewModel.info("Playback completed")

    } catch {
        // エラー処理（5行）
        Logger.viewModel.logError(error)
        errorMessage = error.localizedDescription
        isPlayingRecording = false
    }
}
```

**責任の分析**:
1. **バリデーション**: URL存在確認、再生中チェック（5行）
2. **スケール読み込み**: スケール要素生成、プレイヤー読み込み（3行）
3. **バックグラウンド再生制御**: Taskの起動、ミュート再生（9行）
4. **録音再生制御**: audioPlayer制御（1行）
5. **状態管理**: isPlayingRecording フラグ制御（3行）
6. **エラー処理**: catch ブロック（5行）
7. **ログ出力**: 開始・完了・エラーログ（3行）

**問題点**:
- 7つの異なる責任が1つのメソッドに混在
- ネストが深い（do-catch, if-let, Task）
- テストが困難（モックが複雑）
- デバッグが困難（どの部分で問題が起きたか不明確）

**長いメソッドの証拠**:
- 行数: 42行
- 責任の数: 7つ
- ネストレベル: 4階層（do > if > Task > do）
- コメント依存: コメントなしでは理解困難

---

#### 問題2: startTargetPitchMonitoring() - 52行

**場所**: `PitchDetectionViewModel.swift:65-117`

**問題コード**:
```swift
public func startTargetPitchMonitoring(settings: ScaleSettings) async throws {
    // スケール読み込み（3行）
    let scaleElements = settings.generateScaleWithKeyChange()
    try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)

    // ログ（5行）
    FileLogger.shared.log(
        level: "INFO",
        category: "pitch_monitoring",
        message: "🔵 Target pitch monitoring started (polling interval: \(targetPitchPollingIntervalNanoseconds / 1_000_000)ms)"
    )

    // 監視タスク起動（44行）
    progressMonitorTask = Task { [weak self] in
        guard let self = self else { return }
        let pollingInterval = await self.targetPitchPollingIntervalNanoseconds
        var loopCount = 0
        var lastDebugLogTime = Date()

        while !Task.isCancelled {
            loopCount += 1
            let now = Date()

            // デバッグログ（10行）
            if loopCount % 10 == 0 {
                let interval = now.timeIntervalSince(lastDebugLogTime) * 1000
                FileLogger.shared.log(
                    level: "DEBUG",
                    category: "pitch_monitoring",
                    message: "🔄 Monitor loop iteration #\(loopCount) (last 10 loops took \(String(format: \"%.0f\", interval))ms)"
                )
                lastDebugLogTime = now
            }

            // スケール要素取得（6行）
            if let currentElement = self.scalePlayer.currentScaleElement {
                await self.updateTargetPitchFromScaleElement(currentElement)
            } else {
                await MainActor.run { self.targetPitch = nil }
            }

            // コメント（2行）
            // Note: Detected pitch is now automatically updated via Combine subscription
            // No manual polling needed here

            try? await Task.sleep(nanoseconds: pollingInterval)
        }

        // 終了ログ（5行）
        FileLogger.shared.log(
            level: "INFO",
            category: "pitch_monitoring",
            message: "🛑 Monitor loop terminated after \(loopCount) iterations"
        )
    }
}
```

**責任の分析**:
1. **スケール読み込み**: 3行
2. **ログ出力**: 20行（開始5行 + ループ内10行 + 終了5行）
3. **Task管理**: 3行
4. **ポーリングループ**: 10行
5. **状態監視**: 6行
6. **Sleep制御**: 1行

**問題点**:
- ログ出力が20行（全体の38%）を占める
- ループ内にデバッグロジックが混在
- 本質的なロジック（状態監視）が埋もれている
- ログレベルの判定がない（常にデバッグログを出力）

---

#### 問題3: playScaleElements() - 47行

**場所**: `AVAudioEngineScalePlayer.swift:137-184`

**問題コード**:
```swift
private func playScaleElements() async throws {
    _isPlaying = true

    do {
        // オーディオセッション有効化（2行）
        try AudioSessionManager.shared.activateIfNeeded()
        try engine.start()

        // 再生タスク（38行）
        playbackTask = Task { [weak self] in
            guard let self = self else { return }
            for (index, element) in scaleElements.enumerated() {
                try Task.checkCancellation()
                self._currentNoteIndex = index

                // 要素タイプによる分岐（17行）
                switch element {
                case .chordShort(let notes):
                    try await self.playChord(notes, duration: 0.3)

                case .chordLong(let notes):
                    try await self.playChord(notes, duration: 1.0)

                case .scaleNote(let note):
                    try await self.playNote(note, duration: self.tempo!.secondsPerNote)

                case .silence(let duration):
                    try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                }
            }

            // 完了処理（4行）
            self._currentNoteIndex = scaleElements.count
            self._isPlaying = false
            self.engine.stop()
        }

        try await playbackTask?.value

    } catch is CancellationError {
        _isPlaying = false
    } catch {
        _isPlaying = false
        throw ScalePlayerError.playbackFailed(error.localizedDescription)
    }
}
```

**責任の分析**:
1. **状態初期化**: `_isPlaying = true`
2. **オーディオエンジン起動**: `AudioSessionManager`, `engine.start()`
3. **Task生成**: `playbackTask = Task { ... }`
4. **ループ制御**: `for (index, element) in ...`
5. **要素タイプ分岐**: `switch element`
6. **完了処理**: インデックス更新、フラグクリア、エンジン停止
7. **エラー処理**: CancellationError と 一般エラー

**問題点**:
- 7つの責任が混在
- switchによる分岐が長い（17行）
- エラー処理が複雑（2種類のcatch）
- Taskの中にループがネスト

---

### 推奨リファクタリング

#### Extract Method（メソッドの抽出）

**Before**:
```swift
public func playLastRecording() async {
    // 42行の長いメソッド
}
```

**After**:
```swift
public func playLastRecording() async {
    guard let url = lastRecordingURL else {
        handleNoRecordingError()
        return
    }
    guard !isPlayingRecording else { return }

    await startPlayback(url: url)
}

private func handleNoRecordingError() {
    Logger.viewModel.warning("Play recording failed: no recording available")
    errorMessage = "No recording available"
}

private func startPlayback(url: URL) async {
    Logger.viewModel.info("Starting playback: \(url.lastPathComponent)")

    do {
        isPlayingRecording = true

        if let settings = lastRecordingSettings {
            try await startMutedScalePlayback(settings: settings)
        }

        try await playRecordingAudio(url: url)

        completePlayback()
    } catch {
        handlePlaybackError(error)
    }
}

private func startMutedScalePlayback(settings: ScaleSettings) async throws {
    let scaleElements = settings.generateScaleWithKeyChange()
    try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)

    Task { [weak self] in
        try await self?.scalePlayer.play(muted: true)
    }
}

private func playRecordingAudio(url: URL) async throws {
    try await audioPlayer.play(url: url)
}

private func completePlayback() {
    isPlayingRecording = false
    Logger.viewModel.info("Playback completed")
}

private func handlePlaybackError(_ error: Error) {
    Logger.viewModel.logError(error)
    errorMessage = error.localizedDescription
    isPlayingRecording = false
}
```

**改善点**:
- 各メソッドが1つの責任を持つ
- 各メソッドが5-10行程度に収まる
- メソッド名が意図を明確に表現
- テストが容易（各メソッドを個別にテスト可能）

---

## 4. Temporal Coupling（時間的結合）

### 定義
コードの実行順序が暗黙的に依存している状態。順序を変更するとバグが発生する脆弱性。

### Vocalis Studioでの具体的問題

#### 問題1: stopTargetPitchMonitoring() の実行順序依存

**場所**: `PitchDetectionViewModel.swift:120-125`

**問題コード**:
```swift
public func stopTargetPitchMonitoring() async {
    // ⚠️ 順序1: Taskをキャンセル
    progressMonitorTask?.cancel()

    // ⚠️ 順序2: Task完了を待つ（この順序が重要）
    _ = await progressMonitorTask?.value

    // ⚠️ 順序3: nilにする（順序2の後でないとダメ）
    progressMonitorTask = nil

    // ⚠️ 順序4: targetPitchをクリア（最後でないとレースコンディション）
    targetPitch = nil
}
```

**問題点**:
```swift
// ❌ NGパターン1: 順序2と3を入れ替えると
progressMonitorTask?.cancel()
progressMonitorTask = nil  // 先にnilにすると
_ = await progressMonitorTask?.value  // これが何もしない
targetPitch = nil

// ❌ NGパターン2: 順序4を先頭に持ってくると
targetPitch = nil  // 先にクリアすると
progressMonitorTask?.cancel()
// ↓ この間に監視ループが実行されるとtargetPitchが再設定される（レースコンディション）
_ = await progressMonitorTask?.value
progressMonitorTask = nil

// ❌ NGパターン3: await を省略すると
progressMonitorTask?.cancel()
// progressMonitorTask?.value の await を省略
progressMonitorTask = nil
targetPitch = nil
// ↓ Taskがまだ実行中でtargetPitchを再設定する可能性
```

**現在のバグとの関連**:
- UIテスト失敗の根本原因がこれ
- `stopPlayback()` 呼び出し後も `targetPitch` が残る
- 実行順序の微妙なタイミング依存

**影響**:
- 非決定的なバグ（再現が困難）
- テストが不安定（タイミング依存）
- コードレビューで見逃しやすい

---

#### 問題2: RecordingStateViewModel.stopPlayback() の欠落した順序

**場所**: `RecordingStateViewModel.swift:252-256`

**問題コード**:
```swift
public func stopPlayback() async {
    await audioPlayer.stop()  // 録音停止
    isPlayingRecording = false  // フラグクリア
    // ⚠️ scalePlayer.stop() の呼び出しが欠落！
}
```

**期待される順序**:
```swift
public func stopPlayback() async {
    // 順序1: スケールプレイヤーを停止（TargetPitch をクリアするため）
    await scalePlayer.stop()

    // 順序2: 録音プレイヤーを停止
    await audioPlayer.stop()

    // 順序3: フラグをクリア
    isPlayingRecording = false
}
```

**問題点**:
- `scalePlayer.stop()` が呼ばれないため、`currentScaleElement` が nil にならない
- `PitchDetectionViewModel` の監視ループが `currentScaleElement` を取得し続ける
- `targetPitch` がクリアされない

**バグとの直接的関連**:
```
User clicks StopPlayback button
↓
stopPlayback() called
↓
audioPlayer.stop() → OK
↓
isPlayingRecording = false → OK
↓
scalePlayer.stop() → ❌ NOT CALLED
↓
scalePlayer._isPlaying = true のまま
↓
currentScaleElement returns non-nil
↓
PitchDetectionViewModel監視ループ実行中
↓
targetPitch が更新される
↓
UIに targetPitch が表示され続ける
↓
UIテスト失敗
```

---

#### 問題3: playLastRecording() の暗黙的な順序依存

**場所**: `RecordingStateViewModel.swift:223-237`

**問題コード**:
```swift
do {
    // 順序1: フラグをセット
    isPlayingRecording = true

    // 順序2: スケール読み込み
    if let settings = lastRecordingSettings {
        let scaleElements = settings.generateScaleWithKeyChange()
        try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)

        // 順序3: バックグラウンドでスケール再生開始
        Task { [weak self] in
            try await self.scalePlayer.play(muted: true)
        }
    }

    // 順序4: 録音再生（⚠️ スケール再生の完了を待たない）
    try await audioPlayer.play(url: url)

    // 順序5: 完了フラグ（⚠️ バックグラウンドTaskは無視）
    isPlayingRecording = false
}
```

**問題点**:
```swift
// スケール再生タスク（バックグラウンド）
Task {
    try await self.scalePlayer.play(muted: true)  // 非同期実行
}

// この時点でスケール再生が開始されているか不明
try await audioPlayer.play(url: url)

// スケール再生が完了しているか不明
isPlayingRecording = false

// ⚠️ スケール再生タスクは放置される（誰も await していない）
```

**タイミング問題**:
1. スケール再生が完全に開始される前に録音再生が始まる可能性
2. 録音再生が終わってもスケール再生が続いている可能性
3. スケール再生のエラーが報告されない（silently handle）

---

#### 問題4: AVAudioEngineScalePlayer.stop() の順序問題

**場所**: `AVAudioEngineScalePlayer.swift:263-275`

**問題コード**:
```swift
public func stop() async {
    // 順序1: Taskをキャンセル
    playbackTask?.cancel()
    playbackTask = nil

    // 順序2: フラグをクリア（⚠️ currentScaleElement が即座に nil を返す）
    _isPlaying = false

    // 順序3: エンジン停止
    engine.stop()

    // 順序4: すべてのノートを停止（16チャンネル × 128ノート）
    for channel in 0..<16 {
        for note in 0..<128 {
            sampler.stopNote(UInt8(note), onChannel: UInt8(channel))
        }
    }
}
```

**問題点**:
```swift
// この順序だと：
_isPlaying = false  // ← ここで currentScaleElement が nil を返す

public var currentScaleElement: ScaleElement? {
    guard _isPlaying else { return nil }  // ← 即座に nil
    // ...
}

// しかし PitchDetectionViewModel の監視ループが：
if let currentElement = self.scalePlayer.currentScaleElement {
    // Task.isCancelled がまだ false の可能性
    await self.updateTargetPitchFromScaleElement(currentElement)  // 実行されない
} else {
    await MainActor.run { self.targetPitch = nil }  // これが実行される
}

// しかし次のループ実行で：
if let currentElement = self.scalePlayer.currentScaleElement {
    // _isPlaying = false なので nil
    // でもまだ targetPitch がセットされている場合がある（タイミング依存）
}
```

---

### 推奨リファクタリング

#### State Machine Pattern（状態機械パターン）

**Before**:
```swift
// 暗黙的な順序依存
func stop() async {
    task?.cancel()
    task = nil
    isPlaying = false
}
```

**After**:
```swift
enum PlaybackState {
    case idle
    case loading
    case playing(task: Task<Void, Error>)
    case stopping
    case stopped
}

private var state: PlaybackState = .idle

func stop() async {
    // 明示的な状態遷移
    switch state {
    case .playing(let task):
        state = .stopping
        task.cancel()
        await task.value
        state = .stopped
        // ここで初めて currentScaleElement が nil を返す
    default:
        // 他の状態では何もしない
        break
    }
}

var currentScaleElement: ScaleElement? {
    switch state {
    case .playing:
        return currentElement
    default:
        return nil
    }
}
```

**改善点**:
- 状態遷移が明示的
- 不正な遷移を防げる
- タイミング問題が発生しにくい

---

#### Explicit Coordination（明示的な調整）

**Before**:
```swift
// RecordingStateViewModel
func stopPlayback() async {
    await audioPlayer.stop()
    isPlayingRecording = false
    // scalePlayer.stop() 忘れ
}

// PitchDetectionViewModel
func stopTargetPitchMonitoring() async {
    // 自分で stop するしかない
}
```

**After**:
```swift
// ScalePlaybackCoordinator
func stopPlayback() async {
    // 1. スケール再生を停止
    await scalePlayer.stop()

    // 2. ピッチ監視を停止
    await pitchDetectionViewModel.stopTargetPitchMonitoring()

    // 3. 録音再生を停止
    await audioPlayer.stop()

    // 4. 状態をクリア
    isPlayingRecording = false
}
```

**改善点**:
- 停止順序が明示的
- 忘れることがない
- 1箇所で管理

---

## 5. Feature Envy（機能への嫉妬）

### 定義
あるメソッドが自分のクラスよりも他のクラスのデータに興味を持っている状態。カプセル化の破壊。

### Vocalis Studioでの具体的問題

#### 問題1: PitchDetectionViewModel が scalePlayer の内部状態に強く依存

**場所**: `PitchDetectionViewModel.swift:65-117`

**問題コード**:
```swift
public func startTargetPitchMonitoring(settings: ScaleSettings) async throws {
    // ⚠️ scalePlayer のデータを直接操作
    let scaleElements = settings.generateScaleWithKeyChange()
    try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)

    progressMonitorTask = Task { [weak self] in
        while !Task.isCancelled {
            // ⚠️ scalePlayer の内部状態に頻繁にアクセス
            if let currentElement = self.scalePlayer.currentScaleElement {
                await self.updateTargetPitchFromScaleElement(currentElement)
            }
        }
    }
}
```

**Feature Envyの証拠**:
```swift
// PitchDetectionViewModel が scalePlayer に依存している箇所
1. scalePlayer.loadScaleElements()  // 読み込み
2. scalePlayer.currentScaleElement  // 状態取得（ポーリングループ内）
3. scalePlayer の実行タイミングを知る必要がある
4. scalePlayer の状態変化を監視する必要がある
```

**カプセル化の破壊**:
```swift
// scalePlayer の内部実装を知っている
public var currentScaleElement: ScaleElement? {
    guard _isPlaying else { return nil }  // ← PitchDetectionViewModel がこれを知っている
    // ...
}

// PitchDetectionViewModel は _isPlaying の存在を暗黙的に前提としている
while !Task.isCancelled {
    // _isPlaying が false になったら nil が返ることを期待
    if let currentElement = self.scalePlayer.currentScaleElement {
        // ...
    }
}
```

**問題点**:
- `scalePlayer` の実装を変更すると `PitchDetectionViewModel` に影響
- `currentScaleElement` のロジックを `PitchDetectionViewModel` が理解している必要
- テスト時に `scalePlayer` の内部状態をモックする必要

---

#### 問題2: RecordingStateViewModel が scalePlayer を直接操作

**場所**: `RecordingStateViewModel.swift:223-237`

**問題コード**:
```swift
public func playLastRecording() async {
    if let settings = lastRecordingSettings {
        // ⚠️ scalePlayer のデータ準備を自分でやっている
        let scaleElements = settings.generateScaleWithKeyChange()
        try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)

        // ⚠️ scalePlayer の再生制御を自分でやっている
        Task { [weak self] in
            try await self.scalePlayer.play(muted: true)
        }
    }
}
```

**Feature Envyの証拠**:
```swift
// RecordingStateViewModel が scalePlayer の実装を知っている
1. scaleElements の生成方法（generateScaleWithKeyChange()）
2. loadScaleElements() のパラメータ（elements, tempo）
3. play(muted:) の存在とパラメータ
4. ミュート再生が必要であること（ドメイン知識）
```

**問題点**:
```swift
// このコードは "どうやって" に焦点を当てている（実装詳細）
let scaleElements = settings.generateScaleWithKeyChange()
try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)
try await self.scalePlayer.play(muted: true)

// 本来は "何を" に焦点を当てるべき（意図）
try await scalePlaybackCoordinator.startMutedPlayback(settings: settings)
```

---

#### 問題3: updateTargetPitchFromScaleElement() が ScaleElement の内部に依存

**場所**: `PitchDetectionViewModel.swift:167-191`

**問題コード**:
```swift
private func updateTargetPitchFromScaleElement(_ element: ScaleElement) {
    switch element {
    // ⚠️ ScaleElement の内部構造を知りすぎている
    case .scaleNote(let note):
        let pitch = DetectedPitch.fromFrequency(
            note.frequency,
            confidence: 1.0
        )
        targetPitch = pitch

    case .chordLong(let notes), .chordShort(let notes):
        // ⚠️ コードの "最初の音" が root note という知識を持っている
        if let rootNote = notes.first {
            let pitch = DetectedPitch.fromFrequency(
                rootNote.frequency,
                confidence: 1.0
            )
            targetPitch = pitch
        }

    case .silence:
        targetPitch = nil
    }
}
```

**Feature Envyの証拠**:
```swift
// PitchDetectionViewModel が ScaleElement のドメイン知識を持っている
1. scaleNote には frequency がある
2. chordLong/chordShort には複数の notes がある
3. notes.first が root note である
4. silence の場合は targetPitch を nil にする

// これらは ScaleElement が提供すべき知識
```

**カプセル化の破壊**:
```swift
// ScaleElement の実装を変更すると PitchDetectionViewModel に影響
// 例: root note の定義を変更したい場合

// Before: notes.first
case .chordLong(let notes):
    if let rootNote = notes.first { ... }

// After: notes に rootNoteIndex を追加？
// → PitchDetectionViewModel のコードも変更が必要
case .chordLong(let notes, let rootNoteIndex):
    if rootNoteIndex < notes.count {
        let rootNote = notes[rootNoteIndex]
        // ...
    }
```

---

### 推奨リファクタリング

#### Move Method（メソッドの移動）

**Before**:
```swift
// PitchDetectionViewModel.swift
private func updateTargetPitchFromScaleElement(_ element: ScaleElement) {
    switch element {
    case .scaleNote(let note):
        let pitch = DetectedPitch.fromFrequency(note.frequency, confidence: 1.0)
        targetPitch = pitch
    case .chordLong(let notes), .chordShort(let notes):
        if let rootNote = notes.first {
            let pitch = DetectedPitch.fromFrequency(rootNote.frequency, confidence: 1.0)
            targetPitch = pitch
        }
    case .silence:
        targetPitch = nil
    }
}
```

**After**:
```swift
// ScaleElement.swift（Domain層）
extension ScaleElement {
    var targetPitch: DetectedPitch? {
        switch self {
        case .scaleNote(let note):
            return DetectedPitch.fromFrequency(note.frequency, confidence: 1.0)

        case .chordLong(let notes), .chordShort(let notes):
            guard let rootNote = notes.first else { return nil }
            return DetectedPitch.fromFrequency(rootNote.frequency, confidence: 1.0)

        case .silence:
            return nil
        }
    }
}

// PitchDetectionViewModel.swift
private func updateTargetPitch(from element: ScaleElement) {
    targetPitch = element.targetPitch
}
```

**改善点**:
- ドメイン知識が Domain 層に移動
- PitchDetectionViewModel が実装詳細を知らない
- ScaleElement の変更が PitchDetectionViewModel に影響しない

---

#### Introduce Gateway（ゲートウェイの導入）

**Before**:
```swift
// RecordingStateViewModel が scalePlayer を直接操作
let scaleElements = settings.generateScaleWithKeyChange()
try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)
try await self.scalePlayer.play(muted: true)
```

**After**:
```swift
// ScalePlaybackCoordinator（Application層）
class ScalePlaybackCoordinator {
    private let scalePlayer: ScalePlayerProtocol

    func startMutedPlayback(settings: ScaleSettings) async throws {
        let scaleElements = settings.generateScaleWithKeyChange()
        try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)
        try await scalePlayer.play(muted: true)
    }
}

// RecordingStateViewModel
try await scalePlaybackCoordinator.startMutedPlayback(settings: settings)
```

**改善点**:
- RecordingStateViewModel が "何を" に集中
- "どうやって" は Coordinator に委譲
- scalePlayer の変更が RecordingStateViewModel に影響しない

---

## 6. Data Clumps （データの群れ）

### 定義
同じデータ項目が複数箇所で一緒に出現する状態。データの関係性が不明確。

### Vocalis Studioでの具体的問題

#### 問題1: settings, scaleElements, tempo が常に一緒

**場所1**: `RecordingStateViewModel.swift:224-225`
```swift
let scaleElements = settings.generateScaleWithKeyChange()
try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)
```

**場所2**: `PitchDetectionViewModel.swift:67-68`
```swift
let scaleElements = settings.generateScaleWithKeyChange()
try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)
```

**場所3**: `AVAudioEngineScalePlayer.swift:70-74`
```swift
public func loadScaleElements(_ elements: [ScaleElement], tempo: Tempo) async throws {
    self.scaleElements = elements
    self.scale = []
    self.tempo = tempo
    self._currentNoteIndex = 0
}
```

**Data Clumpの証拠**:
```swift
// これらのデータは常に一緒に扱われる
1. scaleElements: [ScaleElement]
2. tempo: Tempo
3. settings: ScaleSettings（元データ）

// どこに行っても3つセット
func loadScaleElements(_ elements: [ScaleElement], tempo: Tempo)
func generateScaleWithKeyChange() -> [ScaleElement]
settings.tempo
```

**問題点**:
- パラメータリストが長い
- データの関係性が不明確（なぜ一緒なのか？）
- 変更時に複数箇所を修正（例: Key を追加する場合）

**変更時のリスク**:
```swift
// 例: Key（調）を追加したい場合
// ❌ 3箇所すべてに追加する必要がある

// 場所1
let scaleElements = settings.generateScaleWithKeyChange()
try await scalePlayer.loadScaleElements(
    scaleElements,
    tempo: settings.tempo,
    key: settings.key  // 追加1
)

// 場所2
let scaleElements = settings.generateScaleWithKeyChange()
try await scalePlayer.loadScaleElements(
    scaleElements,
    tempo: settings.tempo,
    key: settings.key  // 追加2
)

// 場所3
public func loadScaleElements(
    _ elements: [ScaleElement],
    tempo: Tempo,
    key: Key  // 追加3
) async throws
```

---

#### 問題2: recording URL, settings, isPlaying が常に一緒

**場所**: `RecordingStateViewModel.swift:193-195`
```swift
lastRecordingURL = recordingURL
lastRecordingSettings = recordingSettings
```

**場所**: `RecordingStateViewModel.swift:208-210`
```swift
guard let url = lastRecordingURL else { return }
// ...
if let settings = lastRecordingSettings {
```

**Data Clumpの証拠**:
```swift
// これらのデータは常にペアで扱われる
1. lastRecordingURL: URL?
2. lastRecordingSettings: ScaleSettings?

// 一緒に保存
lastRecordingURL = recordingURL
lastRecordingSettings = recordingSettings

// 一緒に読み込み
if let url = lastRecordingURL, let settings = lastRecordingSettings {
    // ...
}
```

**問題点**:
- 2つのプロパティの同期が必要
- nil の組み合わせが3パターン存在（URLだけnil、Settingsだけnil、両方nil）
- 不正な状態を防げない（URLはあるがSettingsがない、など）

---

#### 問題3: loopCount, lastDebugLogTime が常に一緒

**場所**: `PitchDetectionViewModel.swift:80-81`
```swift
var loopCount = 0
var lastDebugLogTime = Date()
```

**場所**: `PitchDetectionViewModel.swift:84-95`
```swift
loopCount += 1
let now = Date()

if loopCount % 10 == 0 {
    let interval = now.timeIntervalSince(lastDebugLogTime) * 1000
    // ...
    lastDebugLogTime = now
}
```

**Data Clumpの証拠**:
```swift
// デバッグ用のメトリクス
1. loopCount: Int
2. lastDebugLogTime: Date

// 常に一緒に更新
loopCount += 1
lastDebugLogTime = now
```

**問題点**:
- デバッグ用のコードがビジネスロジックに混在
- 関連するデータの意図が不明確

---

### 推奨リファクタリング

#### Introduce Parameter Object（パラメータオブジェクトの導入）

**Before**:
```swift
func loadScaleElements(_ elements: [ScaleElement], tempo: Tempo) async throws
```

**After**:
```swift
struct ScalePlaybackConfiguration {
    let elements: [ScaleElement]
    let tempo: Tempo
    let key: Key?
    let transpose: Int

    init(settings: ScaleSettings) {
        self.elements = settings.generateScaleWithKeyChange()
        self.tempo = settings.tempo
        self.key = settings.key
        self.transpose = settings.transpose
    }
}

func loadScale(configuration: ScalePlaybackConfiguration) async throws {
    self.scaleElements = configuration.elements
    self.tempo = configuration.tempo
    // ...
}

// 使用箇所
let config = ScalePlaybackConfiguration(settings: settings)
try await scalePlayer.loadScale(configuration: config)
```

**改善点**:
- 関連するデータをまとめて管理
- パラメータリストが短くなる
- 新しいパラメータの追加が容易

---

#### Extract Class（クラスの抽出）

**Before**:
```swift
@Published public private(set) var lastRecordingURL: URL?
@Published public private(set) var lastRecordingSettings: ScaleSettings?
```

**After**:
```swift
struct LastRecording {
    let url: URL
    let settings: ScaleSettings
    let recordedAt: Date
}

@Published public private(set) var lastRecording: LastRecording?

// 使用箇所
if let recording = lastRecording {
    try await playRecording(recording)
}

func playRecording(_ recording: LastRecording) async throws {
    // URL と Settings が常に揃っている保証
    let url = recording.url
    let settings = recording.settings
    // ...
}
```

**改善点**:
- データの不整合を防げる（URLとSettingsが常にペア）
- nil チェックが1回で済む
- 将来的な拡張が容易（recordedAt など）

---

## 7. Middle Man（仲介者）

### 定義
クラスが他のクラスへの単純な委譲ばかりしている状態。不要な間接層の存在。

### Vocalis Studioでの具体的問題

#### 問題1: PitchDetectionViewModel が scalePlayer への薄いラッパー

**場所**: `PitchDetectionViewModel.swift:65-125`

**問題コード**:
```swift
public class PitchDetectionViewModel: ObservableObject {
    private let scalePlayer: ScalePlayerProtocol

    // ⚠️ 単純な委譲: スケール読み込み
    public func startTargetPitchMonitoring(settings: ScaleSettings) async throws {
        let scaleElements = settings.generateScaleWithKeyChange()
        try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)
        // + ポーリングループ
    }

    // ⚠️ 単純な委譲: 停止
    public func stopTargetPitchMonitoring() async {
        progressMonitorTask?.cancel()
        _ = await progressMonitorTask?.value
        progressMonitorTask = nil
        targetPitch = nil
    }
}
```

**Middle Manの証拠**:
```swift
// PitchDetectionViewModel の責任分析
1. scalePlayer への委譲: loadScaleElements()
2. Task の管理: progressMonitorTask
3. ポーリングループ: while !Task.isCancelled
4. targetPitch の更新: updateTargetPitchFromScaleElement()
5. detectedPitch の更新: Combine subscription

// このうち、独自のロジックは？
→ ポーリングループとpitch更新のみ
→ その他は単純な委譲または薄いラッパー
```

**責任の薄さ**:
```swift
// startTargetPitchMonitoring() の中身
let scaleElements = settings.generateScaleWithKeyChange()  // 委譲
try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)  // 委譲

// 独自ロジックはループだけ
while !Task.isCancelled {
    if let currentElement = self.scalePlayer.currentScaleElement {  // 委譲
        await self.updateTargetPitchFromScaleElement(currentElement)
    }
}
```

**問題点**:
- PitchDetectionViewModel の存在意義が不明確
- scalePlayer を直接使った方がシンプル
- 不要な間接層がデバッグを困難にする

---

#### 問題2: RecordingStateViewModel.playLastRecording() の薄いラッパー

**場所**: `RecordingStateViewModel.swift:223-237`

**問題コード**:
```swift
public func playLastRecording() async {
    // ...
    do {
        isPlayingRecording = true

        // ⚠️ 単純な委譲: スケール再生
        if let settings = lastRecordingSettings {
            let scaleElements = settings.generateScaleWithKeyChange()
            try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)

            Task {
                try await self.scalePlayer.play(muted: true)  // 委譲
            }
        }

        // ⚠️ 単純な委譲: 録音再生
        try await audioPlayer.play(url: url)  // 委譲

        isPlayingRecording = false
    }
}
```

**Middle Manの証拠**:
```swift
// playLastRecording() の責任
1. scalePlayer への委譲: loadScaleElements(), play()
2. audioPlayer への委譲: play()
3. フラグ管理: isPlayingRecording

// 独自のロジックは？
→ フラグ管理のみ
→ スケールと録音の調整ロジックがない（単に両方を呼ぶだけ）
```

---

### 推奨リファクタリング

#### Remove Middle Man（仲介者の除去）

**Before**:
```swift
// PitchDetectionViewModel（仲介者）
public func startTargetPitchMonitoring(settings: ScaleSettings) async throws {
    let scaleElements = settings.generateScaleWithKeyChange()
    try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)
    // ...
}

// RecordingViewModel（クライアント）
try await pitchDetectionViewModel.startTargetPitchMonitoring(settings: settings)
```

**After**:
```swift
// ScalePlaybackCoordinator（統合）
class ScalePlaybackCoordinator {
    private let scalePlayer: ScalePlayerProtocol

    func startMonitoring(settings: ScaleSettings) async throws {
        let scaleElements = settings.generateScaleWithKeyChange()
        try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)

        startPollingLoop()
    }

    private func startPollingLoop() {
        // ポーリングロジック
    }
}

// RecordingViewModel（クライアント）
try await scalePlaybackCoordinator.startMonitoring(settings: settings)
```

**改善点**:
- 不要な間接層を削除
- 責任が明確になる
- コードがシンプルになる

---

## 8. Shotgun Surgery（散弾銃手術）

### 定義
1つの変更のために多くのクラスを修正する必要がある状態。責任の分散。

### Vocalis Studioでの具体的問題

#### 問題1: スケール再生ロジックの変更

**影響範囲**:
スケール再生のテンポを変更したい場合：

**修正箇所1**: `RecordingStateViewModel.swift:224-225`
```swift
// Before
try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)

// After
try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo * 1.2)  // 20%速く
```

**修正箇所2**: `PitchDetectionViewModel.swift:67-68`
```swift
// Before
try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)

// After
try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo * 1.2)  // 20%速く
```

**修正箇所3**: テストコード `RecordingStateViewModelTests.swift`
```swift
// Before
XCTAssertEqual(mockScalePlayer.loadedTempo, expectedTempo)

// After
XCTAssertEqual(mockScalePlayer.loadedTempo, expectedTempo * 1.2)
```

**修正箇所4**: テストコード `PitchDetectionViewModelTests.swift`
```swift
// Before
XCTAssertEqual(mockScalePlayer.loadedTempo, expectedTempo)

// After
XCTAssertEqual(mockScalePlayer.loadedTempo, expectedTempo * 1.2)
```

**Shotgun Surgeryの証拠**:
- 1つの概念的な変更（テンポ調整）
- 4箇所のコード修正が必要
- 変更漏れのリスク大

---

#### 問題2: スケール停止ロジックの追加

**影響範囲**:
`stopPlayback()` に `scalePlayer.stop()` を追加する場合：

**修正箇所1**: `RecordingStateViewModel.swift:252-256`
```swift
public func stopPlayback() async {
    await scalePlayer.stop()  // 追加
    await audioPlayer.stop()
    isPlayingRecording = false
}
```

**修正箇所2**: `PitchDetectionViewModel.swift` の連携
```swift
// stopPlayback() が呼ばれたことを検知する必要がある
// → 通知メカニズムを追加？
// → Coordinator パターン？
```

**修正箇所3**: テストコード `RecordingStateViewModelTests.swift`
```swift
func testStopPlayback() async {
    // ...
    XCTAssertTrue(mockScalePlayer.stopCalled)  // アサーション追加
}
```

**修正箇所4**: モックオブジェクト `MockScalePlayer.swift`
```swift
class MockScalePlayer: ScalePlayerProtocol {
    var stopCalled = false  // プロパティ追加

    func stop() async {
        stopCalled = true  // 実装追加
    }
}
```

**Shotgun Surgeryの証拠**:
- 1つのバグ修正（scalePlayer.stop()の呼び忘れ）
- 4箇所のコード修正が必要
- テストインフラの変更も必要

---

#### 問題3: ピッチ検出精度の改善

**影響範囲**:
ピッチ検出の信頼度閾値を変更したい場合：

**修正箇所1**: `PitchDetectionViewModel.swift` （信頼度フィルタ）
```swift
// Before
if pitch.confidence > 0.5 { ... }

// After
if pitch.confidence > 0.7 { ... }
```

**修正箇所2**: `RealtimeDisplayArea.swift` （UI表示ロジック）
```swift
// Before
if let detected = detectedPitch { ... }

// After
if let detected = detectedPitch, detected.confidence > 0.7 { ... }
```

**修正箇所3**: テストコード `PitchDetectionViewModelTests.swift`
```swift
// Before
let pitch = DetectedPitch(..., confidence: 0.6)

// After
let pitch = DetectedPitch(..., confidence: 0.8)
```

**Shotgun Surgeryの証拠**:
- 1つの概念的な変更（精度閾値）
- 3箇所のコード修正が必要
- ドメイン知識（閾値）が複数箇所に分散

---

### 推奨リファクタリング

#### Move Method + Introduce Coordinator（メソッドの移動 + Coordinatorの導入）

**Before**:
```swift
// RecordingStateViewModel
try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)

// PitchDetectionViewModel
try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)
```

**After**:
```swift
// ScalePlaybackCoordinator（責任の集約）
class ScalePlaybackCoordinator {
    func loadScale(settings: ScaleSettings) async throws {
        let scaleElements = settings.generateScaleWithKeyChange()
        let adjustedTempo = settings.tempo * 1.2  // 調整ロジックを1箇所に
        try await scalePlayer.loadScaleElements(scaleElements, tempo: adjustedTempo)
    }
}

// RecordingStateViewModel
try await scalePlaybackCoordinator.loadScale(settings: settings)

// PitchDetectionViewModel
try await scalePlaybackCoordinator.loadScale(settings: settings)
```

**改善点**:
- テンポ調整ロジックが1箇所に集約
- 変更箇所が1箇所で済む
- テストも1箇所で済む

---

## 9. Primitive Obsession（基本型への執着）

### 定義
ドメイン概念を基本型で表現している状態。型安全性の欠如。

### Vocalis Studioでの具体的問題

#### 問題1: _isPlaying: Bool による状態表現

**場所**: `AVAudioEngineScalePlayer.swift:15`

**問題コード**:
```swift
private var _isPlaying: Bool = false
```

**問題点**:
```swift
// Bool では2状態しか表現できない
_isPlaying = true   // "再生中"
_isPlaying = false  // "再生していない"

// しかし実際の状態はもっと複雑
1. idle（アイドル）
2. loading（読み込み中）
3. playing（再生中）
4. paused（一時停止）
5. stopping（停止中）
6. stopped（停止完了）
7. error（エラー）

// Bool では表現できない
```

**型安全性の欠如**:
```swift
// ❌ 不正な状態遷移を防げない
_isPlaying = false
// いきなり true にできてしまう
_isPlaying = true

// ❌ 現在の状態が不明確
if _isPlaying {
    // これは "再生開始直後" なのか "再生中" なのか不明
}

// ❌ 状態遷移のロジックが分散
func play() {
    _isPlaying = true  // 状態遷移1
}

func stop() {
    _isPlaying = false  // 状態遷移2
}
```

---

#### 問題2: _currentNoteIndex: Int による進行状態表現

**場所**: `AVAudioEngineScalePlayer.swift:14`

**問題コード**:
```swift
private var _currentNoteIndex: Int = 0
```

**問題点**:
```swift
// Int では意味が不明確
_currentNoteIndex = 0   // "最初の音" なのか "未開始" なのか？
_currentNoteIndex = -1  // "無効" を表す特殊な値（Magic Number）

// 不正な値を防げない
_currentNoteIndex = -100  // コンパイルエラーにならない
_currentNoteIndex = 9999  // 範囲外チェックが必要

// 状態との組み合わせで意味が変わる
if _isPlaying && _currentNoteIndex == 0 {
    // "最初の音を再生中"
}

if !_isPlaying && _currentNoteIndex == 0 {
    // "まだ開始していない" OR "最後まで再生して停止した"？
}
```

**Magic Numberの存在**:
```swift
guard _currentNoteIndex >= 0 else { return nil }  // -1 が "無効" を意味する
```

---

#### 問題3: pollingInterval: UInt64 による時間表現

**場所**: `PitchDetectionViewModel.swift:29-30`

**問題コード**:
```swift
private let targetPitchPollingIntervalNanoseconds: UInt64
private let playbackPitchPollingIntervalNanoseconds: UInt64
```

**問題点**:
```swift
// UInt64 ではナノ秒であることが不明確
targetPitchPollingIntervalNanoseconds: UInt64 = 100_000_000  // これは何ミリ秒？

// 計算が複雑
try? await Task.sleep(nanoseconds: pollingInterval)  // そのまま使える
// vs
try? await Task.sleep(for: .milliseconds(100))  // 意図が明確

// 単位変換エラーのリスク
let seconds = pollingInterval / 1_000_000  // ❌ マイクロ秒になってしまう
let seconds = pollingInterval / 1_000_000_000  // ✅ 正しい
```

---

#### 問題4: String による音名表現

**場所**: `DetectedPitch.swift`（推測）

**問題コード**:
```swift
struct DetectedPitch {
    let noteName: String  // "A4", "C#5", etc.
    let frequency: Double
    let confidence: Double
    let cents: Int?
}
```

**問題点**:
```swift
// String では不正な値を防げない
let pitch = DetectedPitch(noteName: "X99", ...)  // コンパイルエラーにならない
let pitch = DetectedPitch(noteName: "あ", ...)  // 日本語も入る

// パースが必要
let octave = Int(noteName.last!)  // ❌ クラッシュのリスク

// 型安全性がない
func transpose(pitch: DetectedPitch, semitones: Int) -> DetectedPitch {
    // noteName を手動でパースして計算する必要がある
}
```

---

### 推奨リファクタリング

#### Replace Data Value with Object（値オブジェクトへの置き換え）

**Before**:
```swift
private var _isPlaying: Bool = false
private var _currentNoteIndex: Int = 0
```

**After**:
```swift
enum PlaybackState {
    case idle
    case loading
    case playing(currentIndex: Int)
    case paused(currentIndex: Int)
    case stopping
    case stopped
    case error(Error)

    var isPlaying: Bool {
        if case .playing = self {
            return true
        }
        return false
    }

    var currentIndex: Int? {
        switch self {
        case .playing(let index), .paused(let index):
            return index
        default:
            return nil
        }
    }
}

private var state: PlaybackState = .idle
```

**改善点**:
- 状態が明示的
- 不正な遷移を防げる（コンパイラがチェック）
- currentIndex が状態に紐づく

---

#### Replace Type Code with Class（型コードのクラスへの置き換え）

**Before**:
```swift
struct DetectedPitch {
    let noteName: String
    let frequency: Double
}
```

**After**:
```swift
struct NoteName {
    let note: Note
    let octave: Int

    enum Note: String {
        case c = "C"
        case cSharp = "C#"
        case d = "D"
        // ...
    }

    var description: String {
        "\(note.rawValue)\(octave)"
    }

    init?(string: String) {
        // パース処理（失敗時は nil）
    }

    func transposed(by semitones: Int) -> NoteName {
        // 型安全なトランスポーズ
    }
}

struct DetectedPitch {
    let noteName: NoteName
    let frequency: Double
}
```

**改善点**:
- 不正な値を防げる
- トランスポーズなどの操作が型安全
- ドメイン知識がカプセル化される

---

#### Replace Primitive with Duration（基本型をDurationへ置き換え）

**Before**:
```swift
private let targetPitchPollingIntervalNanoseconds: UInt64 = 100_000_000
try? await Task.sleep(nanoseconds: pollingInterval)
```

**After**:
```swift
private let targetPitchPollingInterval: Duration = .milliseconds(100)
try? await Task.sleep(for: targetPitchPollingInterval)
```

**改善点**:
- 意図が明確（100ミリ秒）
- 単位変換エラーがない
- Swift 5.7+ の標準型

---

## 10. Comments（コメント）

### 定義
コメントが多いのは、コードが複雑すぎる証拠。コードで意図を表現すべき。

### Vocalis Studioでの具体的問題

#### 問題1: 実装説明コメント

**場所**: `RecordingStateViewModel.swift:223`

**問題コード**:
```swift
// If we have scale settings, play muted scale for target pitch tracking
if let settings = lastRecordingSettings {
    let scaleElements = settings.generateScaleWithKeyChange()
    try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)

    // Start muted scale playback in background
    Task { [weak self] in
        guard let self = self else { return }
        do {
            try await self.scalePlayer.play(muted: true)
        } catch {
            // Silently handle muted scale playback errors
        }
    }
}
```

**問題点**:
```swift
// コメントがないと意図が不明
// → コメントに依存している証拠

// コメントを削除してもコードで意図が伝わるべき
try await startMutedScaleForTargetPitchTracking(settings: settings)

// "muted" や "target pitch tracking" という概念が
// メソッド名やパラメータで表現されるべき
```

---

#### 問題2: 状態説明コメント

**場所**: `AVAudioEngineScalePlayer.swift:35`

**問題コード**:
```swift
public var currentScaleElement: ScaleElement? {
    guard _isPlaying else { return nil }  // Returns nil when stopped
    guard _currentNoteIndex >= 0 else { return nil }
    // ...
}
```

**問題点**:
```swift
// "Returns nil when stopped" というコメント
// → Bool フラグの意味が不明確な証拠

// State Machine パターンなら
switch state {
case .stopped, .idle:
    return nil
case .playing(let index):
    return scaleElements[index]
}
// コメント不要で意図が明確
```

---

#### 問題3: 実装詳細コメント

**場所**: `PitchDetectionViewModel.swift:105-106`

**問題コード**:
```swift
// Note: Detected pitch is now automatically updated via Combine subscription
// No manual polling needed here
```

**問題点**:
```swift
// このコメントは以下を示唆：
1. 以前は手動ポーリングしていた（履歴）
2. 現在は Combine で自動更新（現状）
3. ここでポーリングする必要がない（注意事項）

// しかし：
// - 履歴はGitで管理すべき
// - 現状はコードから読み取れるべき
// - 注意事項はコードで表現すべき

// コメントなしで意図が伝わるコード：
private func startMonitoringLoop() {
    // Detected pitch is updated via Combine subscription (setupPitchDetectorSubscription)
    // This loop only monitors target pitch from scale player
}
```

---

#### 問題4: TODO コメント

**場所**: （現在は存在しないが、過去に存在した可能性）

**問題コード例**:
```swift
// TODO: Add error handling for scalePlayer.stop()
public func stopPlayback() async {
    await audioPlayer.stop()
    isPlayingRecording = false
}
```

**問題点**:
```swift
// TODO コメントは：
1. 未完成のコードを示す
2. 忘れ去られる可能性が高い
3. コードレビューで見逃される

// 対処法：
1. 即座に実装する
2. Issue/チケットを作成する
3. テストで仕様を明確にする

// テストで表現
func testStopPlayback_shouldStopScalePlayer() async {
    // Given
    await viewModel.playLastRecording()

    // When
    await viewModel.stopPlayback()

    // Then
    XCTAssertTrue(mockScalePlayer.stopCalled)  // 仕様を明確に
}
```

---

### 推奨リファクタリング

#### Extract Method（メソッドの抽出）

**Before**:
```swift
// If we have scale settings, play muted scale for target pitch tracking
if let settings = lastRecordingSettings {
    let scaleElements = settings.generateScaleWithKeyChange()
    try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)

    Task {
        try await self.scalePlayer.play(muted: true)
    }
}
```

**After**:
```swift
if let settings = lastRecordingSettings {
    try await startMutedScaleForTargetPitchTracking(settings: settings)
}

private func startMutedScaleForTargetPitchTracking(settings: ScaleSettings) async throws {
    let configuration = ScalePlaybackConfiguration(settings: settings)
    try await scalePlayer.loadScale(configuration: configuration)

    Task { [weak self] in
        try await self?.scalePlayer.playMuted()
    }
}
```

**改善点**:
- メソッド名が意図を表現
- コメント不要
- テストが容易

---

#### Rename Method（メソッドのリネーム）

**Before**:
```swift
public func stopTargetPitchMonitoring() async {
    progressMonitorTask?.cancel()
    _ = await progressMonitorTask?.value
    progressMonitorTask = nil
    targetPitch = nil
}
```

**After**:
```swift
public func stopTargetPitchMonitoringAndClearState() async {
    await cancelMonitoringTask()
    clearTargetPitch()
}

private func cancelMonitoringTask() async {
    progressMonitorTask?.cancel()
    await progressMonitorTask?.value
    progressMonitorTask = nil
}

private func clearTargetPitch() {
    targetPitch = nil
}
```

**改善点**:
- メソッド名が処理内容を明確に表現
- 各メソッドが1つの責任を持つ
- コメント不要

---

## 11. その他の設計問題

### 問題1: Shared Mutable State（共有された可変状態）

**場所**: `DependencyContainer`（推測）

**問題コード**:
```swift
// 同じ scalePlayer インスタンスが2つのViewModelに注入される
let scalePlayer = AVAudioEngineScalePlayer()

let recordingStateViewModel = RecordingStateViewModel(
    // ...
    scalePlayer: scalePlayer  // 共有1
)

let pitchDetectionViewModel = PitchDetectionViewModel(
    // ...
    scalePlayer: scalePlayer  // 共有2
)
```

**問題点**:
```swift
// RecordingStateViewModel が scalePlayer を操作
await scalePlayer.play(muted: true)

// 同時に PitchDetectionViewModel も scalePlayer にアクセス
let element = scalePlayer.currentScaleElement

// ⚠️ レースコンディション
// - RecordingStateViewModel が stop() を呼ぶ
// - PitchDetectionViewModel がまだ currentScaleElement を読んでいる
// - タイミング依存のバグ
```

**現在のバグとの関連**:
- これが今回のバグの根本原因
- `stopPlayback()` で `scalePlayer.stop()` が呼ばれない
- `PitchDetectionViewModel` が古い状態を読み続ける

---

### 問題2: God Object（神オブジェクト）

**場所**: `RecordingStateViewModel`

**問題の兆候**:
```swift
@MainActor
public class RecordingStateViewModel: ObservableObject {
    // 録音関連（6プロパティ）
    @Published public private(set) var recordingState: RecordingState = .idle
    @Published public private(set) var currentSession: RecordingSession?
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var progress: Double = 0.0
    @Published public private(set) var countdownValue: Int = 3
    @Published public private(set) var lastRecordingURL: URL?

    // サブスクリプション関連（3プロパティ）
    @Published public private(set) var currentTier: SubscriptionTier = .free
    @Published public private(set) var dailyRecordingCount: Int = 0
    @Published public private(set) var recordingLimit: RecordingLimit

    // 再生関連（2プロパティ）
    @Published public private(set) var lastRecordingSettings: ScaleSettings?
    @Published public private(set) var isPlayingRecording: Bool = false

    // 依存関係（8つ）
    private let startRecordingUseCase: StartRecordingUseCaseProtocol
    private let startRecordingWithScaleUseCase: StartRecordingWithScaleUseCaseProtocol
    private let stopRecordingUseCase: StopRecordingUseCaseProtocol
    private let audioPlayer: AudioPlayerProtocol
    private let scalePlayer: ScalePlayerProtocol
    private let subscriptionViewModel: SubscriptionViewModel
    private let usageTracker: RecordingUsageTracker
    private let limitConfig: RecordingLimitConfigProtocol
}
```

**God Objectの証拠**:
- プロパティ数: 11個（Published）+ 8個（依存）= 19個
- メソッド数: 10個以上
- 責任: 録音制御、サブスクリプション管理、再生制御、スケール制御
- ファイルサイズ: 358行

---

### 問題3: Inappropriate Intimacy（不適切な親密さ）

**場所**: `PitchDetectionViewModel` と `AVAudioEngineScalePlayer`

**問題コード**:
```swift
// PitchDetectionViewModel が AVAudioEngineScalePlayer の内部実装を知っている
public var currentScaleElement: ScaleElement? {
    guard _isPlaying else { return nil }  // ← この実装を知っている
    // ...
}

// PitchDetectionViewModel がこれに依存
if let currentElement = self.scalePlayer.currentScaleElement {
    // _isPlaying が false になったら nil が返ることを前提としている
}
```

**問題点**:
- カプセル化の破壊
- 実装の詳細への依存
- 変更の影響が大きい

---

## まとめ

### Code Smellsの相互関係

```
Divergent Change
    ↓
Duplicated Code
    ↓
Long Method
    ↓
Temporal Coupling
    ↓
Feature Envy
    ↓
Shared Mutable State
    ↓
現在のバグ（UI test failure）
```

### 優先順位

1. **🔴 最優先**: Shared Mutable State（今回のバグの直接原因）
2. **🔴 高優先度**: Temporal Coupling（stopPlayback()の実装漏れ）
3. **🟡 中優先度**: Divergent Change, Duplicated Code
4. **🟢 低優先度**: Comments, Primitive Obsession

### 推奨アクション

1. **短期（Phase 1）**: バグ修正
   - `stopPlayback()` に `scalePlayer.stop()` を追加
   - 実行順序を明確化

2. **中期（Phase 2）**: リファクタリング
   - ScalePlaybackCoordinator の導入
   - 責任の再配置

3. **長期（Phase 3）**: アーキテクチャ改善
   - State Machine パターン
   - 型安全性の向上
   - ドメインモデルの充実
