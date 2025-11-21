# SOLID Principles Analysis - Vocalis Studio

## 目次

1. [SOLID原則とは](#solid原則とは)
2. [S - Single Responsibility Principle（単一責任の原則）](#s---single-responsibility-principle単一責任の原則)
3. [O - Open/Closed Principle（開放閉鎖の原則）](#o---openclosed-principle開放閉鎖の原則)
4. [L - Liskov Substitution Principle（リスコフの置換原則）](#l---liskov-substitution-principleリスコフの置換原則)
5. [I - Interface Segregation Principle（インターフェース分離の原則）](#i---interface-segregation-principleインターフェース分離の原則)
6. [D - Dependency Inversion Principle（依存性逆転の原則）](#d---dependency-inversion-principle依存性逆転の原則)
7. [まとめ](#まとめ)

---

## SOLID原則とは

SOLID原則は、Robert C. Martin（Uncle Bob）が提唱した、オブジェクト指向設計における5つの基本原則です。これらの原則に従うことで、保守性が高く、拡張しやすく、理解しやすいコードを書くことができます。

### SOLID の頭字語

- **S**: Single Responsibility Principle（単一責任の原則）
- **O**: Open/Closed Principle（開放閉鎖の原則）
- **L**: Liskov Substitution Principle（リスコフの置換原則）
- **I**: Interface Segregation Principle（インターフェース分離の原則）
- **D**: Dependency Inversion Principle（依存性逆転の原則）

---

## S - Single Responsibility Principle（単一責任の原則）

### 原則の定義

> **"A class should have one, and only one, reason to change."**
>
> クラスは、変更される理由を1つだけ持つべきである。

**言い換え**: 1つのクラスは1つの責任だけを持つべきである。

### なぜ重要か

- **保守性**: 変更の影響範囲が明確になる
- **テスタビリティ**: 単一の責任だけをテストすれば良い
- **再利用性**: 責任が明確なクラスは再利用しやすい
- **理解しやすさ**: 責任が1つだと理解が容易

### 違反の兆候

- クラスが複数の理由で変更される
- クラス名に "And" や "Manager" が含まれる
- メソッド数やプロパティ数が多すぎる
- 異なるチームが同じクラスを変更する

---

### Vocalis Studioでの違反例

#### 違反1: RecordingStateViewModel - 4つの責任

**場所**: `RecordingStateViewModel.swift`

**問題コード**:
```swift
@MainActor
public class RecordingStateViewModel: ObservableObject {
    // 責任1: 録音制御
    @Published public private(set) var recordingState: RecordingState = .idle
    private let startRecordingUseCase: StartRecordingUseCaseProtocol
    private let stopRecordingUseCase: StopRecordingUseCaseProtocol

    public func startRecording(settings: ScaleSettings? = nil) async {
        // 録音開始ロジック
    }

    public func stopRecording() async {
        // 録音停止ロジック
    }

    // 責任2: スケール再生制御
    private let scalePlayer: ScalePlayerProtocol

    public func playLastRecording() async {
        // スケール再生ロジック
        if let settings = lastRecordingSettings {
            let scaleElements = settings.generateScaleWithKeyChange()
            try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)
            Task {
                try await self.scalePlayer.play(muted: true)
            }
        }
    }

    // 責任3: サブスクリプション管理
    @Published public private(set) var currentTier: SubscriptionTier = .free
    @Published public private(set) var dailyRecordingCount: Int = 0
    @Published public private(set) var recordingLimit: RecordingLimit

    private let subscriptionViewModel: SubscriptionViewModel
    private let usageTracker: RecordingUsageTracker
    private let limitConfig: RecordingLimitConfigProtocol

    // 責任4: カウントダウン管理
    @Published public private(set) var countdownValue: Int = 3
    private var countdownTask: Task<Void, Never>?

    public func cancelCountdown() async {
        // カウントダウンキャンセルロジック
    }
}
```

**変更理由の分析**:
1. **録音機能の変更**: 録音開始/停止の仕様変更、エラーハンドリング改善
2. **スケール再生の変更**: スケールのテンポ変更、ミュート制御の追加
3. **サブスクリプションの変更**: 新しいティアの追加、制限ロジックの変更
4. **カウントダウンの変更**: カウントダウン時間の変更、UI表示の改善

**影響**:
- ファイルサイズ: 358行（大きすぎる）
- 依存関係: 8つのプロトコルに依存
- テストの複雑さ: 4つの責任すべてをモックする必要がある

**SRP違反の証拠**:
```swift
// これらの変更はすべて同じクラスに影響する
1. "録音時間制限を30秒から60秒に変更" → RecordingStateViewModel を変更
2. "スケールのテンポを可変にする" → RecordingStateViewModel を変更
3. "新しいサブスクリプションティアを追加" → RecordingStateViewModel を変更
4. "カウントダウンを3秒から5秒に変更" → RecordingStateViewModel を変更
```

---

#### 違反2: PitchDetectionViewModel - 3つの責任

**場所**: `PitchDetectionViewModel.swift`

**問題コード**:
```swift
@MainActor
public class PitchDetectionViewModel: ObservableObject {
    // 責任1: ターゲットピッチ監視
    @Published public private(set) var targetPitch: DetectedPitch?
    private var progressMonitorTask: Task<Void, Never>?

    public func startTargetPitchMonitoring(settings: ScaleSettings) async throws {
        // スケール進行監視ロジック
    }

    public func stopTargetPitchMonitoring() async {
        // 監視停止ロジック
    }

    // 責任2: 検出ピッチ管理
    @Published public private(set) var detectedPitch: DetectedPitch?
    @Published public private(set) var pitchAccuracy: PitchAccuracy = .none
    private let pitchDetector: PitchDetectorProtocol

    private func setupPitchDetectorSubscription() {
        // Combine subscription setup
    }

    // 責任3: スケール読み込み調整
    private let scalePlayer: ScalePlayerProtocol

    public func startTargetPitchMonitoring(settings: ScaleSettings) async throws {
        let scaleElements = settings.generateScaleWithKeyChange()
        try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)
        // ...
    }
}
```

**変更理由の分析**:
1. **ターゲットピッチの変更**: ポーリング間隔の調整、監視アルゴリズムの改善
2. **検出ピッチの変更**: 精度計算の改善、信頼度フィルタの追加
3. **スケール読み込みの変更**: テンポ調整、スケール生成ロジックの変更

---

#### 違反3: AVAudioEngineScalePlayer - 5つの責任

**場所**: `AVAudioEngineScalePlayer.swift`

**問題コード**:
```swift
public class AVAudioEngineScalePlayer: ScalePlayerProtocol {
    // 責任1: AVAudioEngine管理
    private let engine: AVAudioEngine
    private let sampler: AVAudioUnitSampler

    public init() {
        engine = AVAudioEngine()
        sampler = AVAudioUnitSampler()
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
    }

    // 責任2: サウンドバンク読み込み
    private func loadSoundBank() async throws {
        #if targetEnvironment(simulator)
        try sampler.loadSoundBankInstrument(at: URL(...), ...)
        #elseif os(iOS)
        // Real device logic
        #endif
    }

    // 責任3: 再生制御
    private var playbackTask: Task<Void, Error>?
    private var _isPlaying: Bool = false

    public func play(muted: Bool = false) async throws {
        // 再生ロジック
    }

    public func stop() async {
        // 停止ロジック
    }

    // 責任4: スケールデータ管理
    private var scale: [MIDINote] = []  // Legacy
    private var scaleElements: [ScaleElement] = []  // New format
    private var tempo: Tempo?

    public func loadScale(_ notes: [MIDINote], tempo: Tempo) async throws {
        // Legacy format
    }

    public func loadScaleElements(_ elements: [ScaleElement], tempo: Tempo) async throws {
        // New format
    }

    // 責任5: 進行状態計算
    private var _currentNoteIndex: Int = 0

    public var progress: Double {
        let totalCount = scaleElements.isEmpty ? scale.count : scaleElements.count
        guard totalCount > 0 else { return 0.0 }
        return min(1.0, Double(_currentNoteIndex) / Double(totalCount))
    }

    public var currentScaleElement: ScaleElement? {
        guard _isPlaying else { return nil }
        // 複雑な分岐ロジック
    }
}
```

**変更理由の分析**:
1. **AVFoundation統合**: エンジン設定の変更、音量調整、チャンネル管理
2. **サウンドバンク**: iOS/Simulator対応の変更、音源ファイルの変更
3. **再生制御**: Task管理の改善、キャンセル処理の変更
4. **データフォーマット**: レガシー対応の削除、新フォーマットの追加
5. **進行状態**: インデックス計算の改善、進捗表示の変更

---

### 推奨リファクタリング

#### Extract Class（クラスの抽出）

**Before**:
```swift
class RecordingStateViewModel {
    // 録音 + スケール + サブスクリプション + カウントダウン
}
```

**After**:
```swift
// 責任1: 録音制御のみ
class RecordingStateViewModel {
    private let recordingCoordinator: RecordingCoordinator
    private let countdownManager: CountdownManager

    func startRecording() async {
        await countdownManager.startCountdown()
        await recordingCoordinator.startRecording()
    }
}

// 責任2: スケール再生
class ScalePlaybackCoordinator {
    func startScalePlayback(settings: ScaleSettings) async throws {
        let scaleElements = settings.generateScaleWithKeyChange()
        try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)
        try await scalePlayer.play(muted: true)
    }
}

// 責任3: サブスクリプション管理
class SubscriptionManager {
    func checkRecordingLimit() -> Bool {
        return dailyRecordingCount < recordingLimit.dailyCount
    }
}

// 責任4: カウントダウン管理
class CountdownManager {
    func startCountdown(duration: Int) async {
        // カウントダウンロジック
    }
}
```

**改善点**:
- 各クラスが1つの責任を持つ
- 変更の影響範囲が明確
- テストが容易（単一の責任をテスト）

---

## O - Open/Closed Principle（開放閉鎖の原則）

### 原則の定義

> **"Software entities should be open for extension, but closed for modification."**
>
> ソフトウェアエンティティは、拡張に対して開いており、修正に対して閉じているべきである。

**言い換え**: 既存のコードを変更せずに、新しい機能を追加できるべきである。

### なぜ重要か

- **安定性**: 既存のコードを変更しないため、バグが入りにくい
- **拡張性**: 新機能の追加が容易
- **保守性**: 既存機能への影響を最小限に抑える

### 違反の兆候

- 新機能追加のたびに既存コードを修正する
- switch文やif-else文が多い
- 型チェック（is, as?）が多い

---

### Vocalis Studioでの違反例

#### 違反1: ScaleElement の switch 文

**場所**: `AVAudioEngineScalePlayer.swift:152-168`

**問題コード**:
```swift
// playScaleElements() 内
for (index, element) in scaleElements.enumerated() {
    try Task.checkCancellation()
    self._currentNoteIndex = index

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
```

**OCP違反の証拠**:
```swift
// 新しいスケール要素タイプを追加したい場合
enum ScaleElement {
    case scaleNote(MIDINote)
    case chordShort([MIDINote])
    case chordLong([MIDINote])
    case silence(TimeInterval)
    case arpeggio([MIDINote])  // ← 新しいタイプを追加
}

// ❌ 既存コードを修正する必要がある
switch element {
case .chordShort(let notes):
    try await self.playChord(notes, duration: 0.3)
case .chordLong(let notes):
    try await self.playChord(notes, duration: 1.0)
case .scaleNote(let note):
    try await self.playNote(note, duration: self.tempo!.secondsPerNote)
case .silence(let duration):
    try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
case .arpeggio(let notes):  // ← ここを追加する必要がある
    try await self.playArpeggio(notes)  // ← 新しい処理
}

// この switch は3箇所に存在する可能性
// → すべての箇所を修正する必要がある（Shotgun Surgery）
```

**影響**:
- 新しいスケール要素タイプの追加が困難
- すべての switch 文を修正する必要がある
- 修正漏れのリスク

---

#### 違反2: PitchDetectionViewModel.updateTargetPitchFromScaleElement()

**場所**: `PitchDetectionViewModel.swift:167-191`

**問題コード**:
```swift
private func updateTargetPitchFromScaleElement(_ element: ScaleElement) {
    switch element {
    case .scaleNote(let note):
        let pitch = DetectedPitch.fromFrequency(
            note.frequency,
            confidence: 1.0
        )
        targetPitch = pitch

    case .chordLong(let notes), .chordShort(let notes):
        if let rootNote = notes.first {
            let pitch = DetectedPitch.fromFrequency(
                rootNote.frequency,
                confidence: 1.0
            )
            targetPitch = pitch
        } else {
            targetPitch = nil
        }

    case .silence:
        targetPitch = nil
    }
}
```

**OCP違反の証拠**:
```swift
// 新しいスケール要素タイプ（arpeggio）を追加
case .arpeggio(let notes):  // ← 既存メソッドを修正する必要がある
    if let rootNote = notes.first {
        let pitch = DetectedPitch.fromFrequency(
            rootNote.frequency,
            confidence: 1.0
        )
        targetPitch = pitch
    }
```

---

#### 違反3: プラットフォーム固有のサウンドバンク読み込み

**場所**: `AVAudioEngineScalePlayer.swift:80-110`

**問題コード**:
```swift
private func loadSoundBank() async throws {
    do {
        #if targetEnvironment(simulator)
        // iOS Simulator: use DLS sound bank
        try sampler.loadSoundBankInstrument(
            at: URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls"),
            program: 0,
            bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
            bankLSB: UInt8(kAUSampler_DefaultBankLSB)
        )
        #elseif os(iOS)
        // Real iOS device: use AUAudioUnit factory presets
        if let pianoPreset = sampler.auAudioUnit.factoryPresets?.first(where: { $0.name.contains("Piano") }) {
            sampler.auAudioUnit.currentPreset = pianoPreset
        } else if let firstPreset = sampler.auAudioUnit.factoryPresets?.first {
            sampler.auAudioUnit.currentPreset = firstPreset
        }
        #else
        // macOS: load DLS sound bank
        try sampler.loadSoundBankInstrument(
            at: URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls"),
            program: 0,
            bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
            bankLSB: UInt8(kAUSampler_DefaultBankLSB)
        )
        #endif
    } catch {
        // Continue anyway
    }
}
```

**OCP違反の証拠**:
```swift
// 新しいプラットフォーム（例: visionOS）を追加したい場合
#if targetEnvironment(simulator)
    // Simulator
#elseif os(iOS)
    // iOS
#elseif os(visionOS)  // ← 既存メソッドを修正する必要がある
    // visionOS specific
#else
    // macOS
#endif
```

---

### 推奨リファクタリング

#### Strategy Pattern（戦略パターン）

**Before**:
```swift
switch element {
case .scaleNote(let note):
    try await self.playNote(note, duration: self.tempo!.secondsPerNote)
case .chordShort(let notes):
    try await self.playChord(notes, duration: 0.3)
// ...
}
```

**After**:
```swift
// ScaleElement にプロトコルを追加
protocol Playable {
    func play(using player: ScalePlayerProtocol, tempo: Tempo) async throws
}

enum ScaleElement: Playable {
    case scaleNote(MIDINote)
    case chordShort([MIDINote])
    case chordLong([MIDINote])
    case silence(TimeInterval)

    func play(using player: ScalePlayerProtocol, tempo: Tempo) async throws {
        switch self {
        case .scaleNote(let note):
            try await player.playNote(note, duration: tempo.secondsPerNote)
        case .chordShort(let notes):
            try await player.playChord(notes, duration: 0.3)
        case .chordLong(let notes):
            try await player.playChord(notes, duration: 1.0)
        case .silence(let duration):
            try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        }
    }
}

// AVAudioEngineScalePlayer
for element in scaleElements {
    try await element.play(using: self, tempo: tempo!)
}

// 新しいタイプの追加（既存コードを変更しない）
enum ScaleElement: Playable {
    // ...
    case arpeggio([MIDINote])  // 新しいタイプ

    func play(using player: ScalePlayerProtocol, tempo: Tempo) async throws {
        switch self {
        // ... 既存のcase
        case .arpeggio(let notes):  // 新しいタイプの処理
            try await player.playArpeggio(notes, tempo: tempo)
        }
    }
}
```

**改善点**:
- 新しいスケール要素タイプの追加が容易
- AVAudioEngineScalePlayer を変更しない
- 各要素が自分の再生ロジックをカプセル化

---

#### Factory Pattern（ファクトリパターン）

**Before**:
```swift
#if targetEnvironment(simulator)
    // Simulator specific
#elseif os(iOS)
    // iOS specific
#else
    // macOS specific
#endif
```

**After**:
```swift
protocol SoundBankLoader {
    func loadSoundBank(into sampler: AVAudioUnitSampler) async throws
}

class SimulatorSoundBankLoader: SoundBankLoader {
    func loadSoundBank(into sampler: AVAudioUnitSampler) async throws {
        try sampler.loadSoundBankInstrument(
            at: URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls"),
            program: 0,
            bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
            bankLSB: UInt8(kAUSampler_DefaultBankLSB)
        )
    }
}

class iOSSoundBankLoader: SoundBankLoader {
    func loadSoundBank(into sampler: AVAudioUnitSampler) async throws {
        if let pianoPreset = sampler.auAudioUnit.factoryPresets?.first(where: { $0.name.contains("Piano") }) {
            sampler.auAudioUnit.currentPreset = pianoPreset
        }
    }
}

class SoundBankLoaderFactory {
    static func create() -> SoundBankLoader {
        #if targetEnvironment(simulator)
        return SimulatorSoundBankLoader()
        #elseif os(iOS)
        return iOSSoundBankLoader()
        #else
        return MacOSSoundBankLoader()
        #endif
    }
}

// 使用箇所
private let soundBankLoader: SoundBankLoader = SoundBankLoaderFactory.create()

private func loadSoundBank() async throws {
    try await soundBankLoader.loadSoundBank(into: sampler)
}
```

**改善点**:
- 新しいプラットフォームの追加が容易
- 各プラットフォームのロジックが分離
- テストが容易（モックが作りやすい）

---

## L - Liskov Substitution Principle（リスコフの置換原則）

### 原則の定義

> **"Objects of a superclass should be replaceable with objects of a subclass without breaking the application."**
>
> スーパークラスのオブジェクトは、サブクラスのオブジェクトで置き換え可能であるべきである。

**言い換え**: サブクラスは、親クラスの契約（インターフェース）を守るべきである。

### なぜ重要か

- **多態性**: ポリモーフィズムが正しく機能する
- **置換可能性**: 実装を変更しても動作が保証される
- **信頼性**: 予期しない動作を防ぐ

### 違反の兆候

- サブクラスがメソッドをオーバーライドして異なる動作をする
- サブクラスが親クラスの事前条件を強化する
- サブクラスが親クラスの事後条件を弱化する

---

### Vocalis Studioでの違反例

#### 違反1: ScalePlayerProtocol の実装による不整合

**場所**: `ScalePlayerProtocol.swift`（推測）と実装

**プロトコル定義**（推測）:
```swift
protocol ScalePlayerProtocol {
    var isPlaying: Bool { get }
    var currentScaleElement: ScaleElement? { get }

    func loadScale(_ notes: [MIDINote], tempo: Tempo) async throws
    func loadScaleElements(_ elements: [ScaleElement], tempo: Tempo) async throws
    func play(muted: Bool) async throws
    func stop() async
}
```

**問題コード**: `AVAudioEngineScalePlayer.swift`
```swift
public class AVAudioEngineScalePlayer: ScalePlayerProtocol {
    // ⚠️ currentScaleElement が _isPlaying に依存
    public var currentScaleElement: ScaleElement? {
        guard _isPlaying else { return nil }  // ← LSP違反の可能性
        // ...
    }

    // ⚠️ stop() が非同期だが状態はすぐにクリア
    public func stop() async {
        playbackTask?.cancel()
        playbackTask = nil
        _isPlaying = false  // ← 即座にfalseになる
        engine.stop()
        // ... 全ノート停止
    }
}
```

**LSP違反の証拠**:
```swift
// プロトコルの期待される契約:
// - currentScaleElement は「現在再生中の要素」を返す
// - stop() は「再生を停止する」

// しかし実装では:
// - stop() を呼ぶと即座に _isPlaying = false になる
// - その結果、currentScaleElement が nil を返す
// - しかし実際の再生停止処理（engine.stop()）はまだ実行中

// これにより、以下のコードが破綻する:
let currentElement = scalePlayer.currentScaleElement  // 要素を取得
await scalePlayer.stop()  // 停止を要求
// この時点で currentElement は nil になっているが、まだ音が鳴っている可能性がある
```

**問題点**:
- プロトコルの契約と実装が一致しない
- 呼び出し側が予期しない動作に遭遇する
- テストでモックを使うと動作が異なる

---

#### 違反2: Mock実装の不整合

**場所**: テストコード（推測）

**問題コード**:
```swift
// MockScalePlayer が本物と異なる動作をする可能性
class MockScalePlayer: ScalePlayerProtocol {
    var isPlaying: Bool = false
    var currentScaleElement: ScaleElement?

    // ⚠️ currentScaleElement が独立したプロパティ
    // 本物は _isPlaying に依存しているが、モックは依存しない

    func stop() async {
        isPlaying = false
        // ⚠️ currentScaleElement をクリアしない
        // 本物は stop() で currentScaleElement が nil になるが、モックはならない
    }
}

// テスト
func testStopClearsCurrentElement() async {
    let mockPlayer = MockScalePlayer()
    mockPlayer.currentScaleElement = .scaleNote(MIDINote(value: 60))

    await mockPlayer.stop()

    // ❌ テストは通る（mockPlayer.currentScaleElement がまだ存在）
    // しかし本物では nil になる
    XCTAssertNil(mockPlayer.currentScaleElement)  // 失敗しない（モックでは）
}
```

**LSP違反の証拠**:
- モックを本物に置き換えるとテストが失敗する
- 実装とモックで動作が異なる
- プロトコルの契約が不明確

---

### 推奨リファクタリング

#### 契約の明確化

**Before**:
```swift
protocol ScalePlayerProtocol {
    var isPlaying: Bool { get }
    var currentScaleElement: ScaleElement? { get }
    func stop() async
}
```

**After**:
```swift
protocol ScalePlayerProtocol {
    var isPlaying: Bool { get }

    /// 現在再生中のスケール要素を返す
    /// - Returns: 再生中の場合は要素、停止中または停止処理中の場合は nil
    /// - Note: stop() を呼び出した後は即座に nil を返す
    var currentScaleElement: ScaleElement? { get }

    /// 再生を停止する
    /// - Note: 呼び出し後、isPlaying は false、currentScaleElement は nil になる
    /// - Note: 実際の音声停止処理は非同期で完了する
    func stop() async
}

// 実装
public class AVAudioEngineScalePlayer: ScalePlayerProtocol {
    public var currentScaleElement: ScaleElement? {
        // 契約通りの実装
        guard _isPlaying else { return nil }
        // ...
    }

    public func stop() async {
        // 契約通りの実装
        _isPlaying = false  // 即座にfalseにする（契約通り）
        playbackTask?.cancel()
        // ...
    }
}

// モック
class MockScalePlayer: ScalePlayerProtocol {
    private var _isPlaying: Bool = false
    private var _currentElement: ScaleElement?

    var isPlaying: Bool { _isPlaying }

    var currentScaleElement: ScaleElement? {
        // 本物と同じ振る舞い
        guard _isPlaying else { return nil }
        return _currentElement
    }

    func stop() async {
        // 本物と同じ振る舞い
        _isPlaying = false
        // currentScaleElement も自動的に nil になる
    }
}
```

**改善点**:
- プロトコルの契約が明確
- 実装とモックの動作が一致
- 呼び出し側の期待と実装が一致

---

## I - Interface Segregation Principle（インターフェース分離の原則）

### 原則の定義

> **"Clients should not be forced to depend on interfaces they do not use."**
>
> クライアントは、使用しないインターフェースに依存することを強制されるべきではない。

**言い換え**: インターフェースは小さく、目的に特化したものにすべきである。

### なぜ重要か

- **疎結合**: 不要な依存を避ける
- **柔軟性**: インターフェースの変更が影響を及ぼす範囲を最小化
- **理解しやすさ**: 小さいインターフェースは理解が容易

### 違反の兆候

- 大きすぎるインターフェース
- 実装クラスがインターフェースの一部しか使わない
- クライアントが不要なメソッドに依存する

---

### Vocalis Studioでの違反例

#### 違反1: ScalePlayerProtocol が大きすぎる

**場所**: `ScalePlayerProtocol.swift`（推測）

**問題コード**:
```swift
protocol ScalePlayerProtocol {
    // 状態プロパティ
    var isPlaying: Bool { get }
    var currentNoteIndex: Int { get }
    var progress: Double { get }
    var currentScaleElement: ScaleElement? { get }

    // スケール読み込み（2つのフォーマット）
    func loadScale(_ notes: [MIDINote], tempo: Tempo) async throws
    func loadScaleElements(_ elements: [ScaleElement], tempo: Tempo) async throws

    // 再生制御
    func play(muted: Bool) async throws
    func stop() async
}
```

**ISP違反の証拠**:
```swift
// RecordingStateViewModel は一部のメソッドしか使わない
class RecordingStateViewModel {
    private let scalePlayer: ScalePlayerProtocol

    func playLastRecording() async {
        // ✅ 使用: loadScaleElements()
        try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)

        // ✅ 使用: play(muted:)
        try await scalePlayer.play(muted: true)

        // ❌ 不使用: loadScale() (legacy format)
        // ❌ 不使用: currentNoteIndex
        // ❌ 不使用: progress
        // ❌ 不使用: currentScaleElement
    }
}

// PitchDetectionViewModel も一部のメソッドしか使わない
class PitchDetectionViewModel {
    private let scalePlayer: ScalePlayerProtocol

    func startTargetPitchMonitoring() async throws {
        // ✅ 使用: loadScaleElements()
        try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)

        // ✅ 使用: currentScaleElement
        if let element = scalePlayer.currentScaleElement {
            // ...
        }

        // ❌ 不使用: loadScale() (legacy format)
        // ❌ 不使用: play(muted:)
        // ❌ 不使用: stop()
        // ❌ 不使用: currentNoteIndex
        // ❌ 不使用: progress
    }
}
```

**問題点**:
- RecordingStateViewModel は ScalePlayerProtocol の50%しか使わない
- PitchDetectionViewModel は ScalePlayerProtocol の30%しか使わない
- 不要なメソッドに依存している

---

#### 違反2: AudioPlayerProtocol（推測）

**場所**: `AudioPlayerProtocol.swift`（推測）

**問題コード**:
```swift
protocol AudioPlayerProtocol {
    var isPlaying: Bool { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }

    func play(url: URL) async throws
    func pause() async
    func resume() async
    func stop() async
    func seek(to time: TimeInterval) async
}
```

**ISP違反の証拠**:
```swift
// RecordingStateViewModel は一部のメソッドしか使わない
class RecordingStateViewModel {
    private let audioPlayer: AudioPlayerProtocol

    func playLastRecording() async {
        // ✅ 使用: play(url:)
        try await audioPlayer.play(url: url)

        // ❌ 不使用: pause(), resume(), seek()
        // ❌ 不使用: currentTime, duration
    }

    func stopPlayback() async {
        // ✅ 使用: stop()
        await audioPlayer.stop()
    }
}
```

---

### 推奨リファクタリング

#### Interface Segregation（インターフェースの分離）

**Before**:
```swift
protocol ScalePlayerProtocol {
    var isPlaying: Bool { get }
    var currentNoteIndex: Int { get }
    var progress: Double { get }
    var currentScaleElement: ScaleElement? { get }

    func loadScale(_ notes: [MIDINote], tempo: Tempo) async throws
    func loadScaleElements(_ elements: [ScaleElement], tempo: Tempo) async throws
    func play(muted: Bool) async throws
    func stop() async
}
```

**After**:
```swift
// 小さな、目的特化したインターフェース

// 1. スケール読み込み
protocol ScaleLoadable {
    func loadScaleElements(_ elements: [ScaleElement], tempo: Tempo) async throws
}

// 2. 再生制御
protocol ScalePlaybackControl {
    func play(muted: Bool) async throws
    func stop() async
}

// 3. 再生状態監視
protocol ScalePlaybackMonitoring {
    var isPlaying: Bool { get }
    var currentScaleElement: ScaleElement? { get }
}

// 4. 進行状態監視
protocol ScaleProgressMonitoring {
    var progress: Double { get }
    var currentNoteIndex: Int { get }
}

// 完全な実装（すべてのインターフェースを実装）
class AVAudioEngineScalePlayer: ScaleLoadable, ScalePlaybackControl, ScalePlaybackMonitoring, ScaleProgressMonitoring {
    // すべてのインターフェースを実装
}

// クライアントは必要なインターフェースだけに依存
class RecordingStateViewModel {
    // ✅ 必要な機能だけに依存
    private let scaleLoader: ScaleLoadable
    private let playbackControl: ScalePlaybackControl

    init(scaleLoader: ScaleLoadable, playbackControl: ScalePlaybackControl) {
        self.scaleLoader = scaleLoader
        self.playbackControl = playbackControl
    }

    func playLastRecording() async {
        try await scaleLoader.loadScaleElements(scaleElements, tempo: settings.tempo)
        try await playbackControl.play(muted: true)
    }
}

class PitchDetectionViewModel {
    // ✅ 必要な機能だけに依存
    private let scaleLoader: ScaleLoadable
    private let playbackMonitoring: ScalePlaybackMonitoring

    init(scaleLoader: ScaleLoadable, playbackMonitoring: ScalePlaybackMonitoring) {
        self.scaleLoader = scaleLoader
        self.playbackMonitoring = playbackMonitoring
    }

    func startTargetPitchMonitoring() async throws {
        try await scaleLoader.loadScaleElements(scaleElements, tempo: settings.tempo)

        if let element = playbackMonitoring.currentScaleElement {
            // ...
        }
    }
}
```

**改善点**:
- 各クライアントが必要な機能だけに依存
- インターフェースが小さく、理解しやすい
- 変更の影響範囲が最小化

---

## D - Dependency Inversion Principle（依存性逆転の原則）

### 原則の定義

> **"High-level modules should not depend on low-level modules. Both should depend on abstractions."**
>
> 上位モジュールは下位モジュールに依存すべきではない。両者は抽象に依存すべきである。

**言い換え**: 具象クラスではなく、インターフェース（抽象）に依存すべきである。

### なぜ重要か

- **疎結合**: 実装の詳細から独立
- **テスタビリティ**: モックやスタブで置き換え可能
- **柔軟性**: 実装を簡単に変更できる

### 違反の兆候

- クラスが具象クラスに直接依存している
- new 演算子で具象クラスをインスタンス化している
- テストでモックが作れない

---

### Vocalis Studioでの違反例

#### 違反1: DependencyContainer が具象クラスに依存（部分的）

**場所**: `DependencyContainer.swift`（推測）

**問題コード**（推測）:
```swift
class DependencyContainer {
    // ❌ 具象クラスを直接インスタンス化
    let scalePlayer = AVAudioEngineScalePlayer()

    // ✅ プロトコルとして公開
    func makeRecordingStateViewModel() -> RecordingStateViewModel {
        return RecordingStateViewModel(
            // ...
            scalePlayer: scalePlayer  // ← 具象クラスだが、プロトコルとして渡される
        )
    }
}
```

**DIP違反の証拠**:
```swift
// DependencyContainer は AVAudioEngineScalePlayer という具象クラスを知っている
let scalePlayer = AVAudioEngineScalePlayer()  // ← 直接依存

// もし別の実装に変えたい場合
let scalePlayer = SomeOtherScalePlayer()  // ← DependencyContainer を変更する必要がある
```

**問題点**:
- DependencyContainer が実装の詳細を知っている
- 実装を変更する場合、DependencyContainer を変更する必要がある
- テスト時に別の実装に置き換えにくい

---

#### 違反2: ファイルロガーの直接使用

**場所**: `PitchDetectionViewModel.swift:70-74`

**問題コード**:
```swift
FileLogger.shared.log(
    level: "INFO",
    category: "pitch_monitoring",
    message: "🔵 Target pitch monitoring started"
)
```

**DIP違反の証拠**:
```swift
// PitchDetectionViewModel が FileLogger という具象クラスに直接依存
FileLogger.shared  // ← シングルトン、グローバル状態

// もしロガーを変更したい場合
// → すべての FileLogger.shared を変更する必要がある

// テスト時にロガーをモックできない
// → ログ出力を検証できない
```

---

#### 違反3: UserDefaults の直接使用（推測）

**場所**: `RecordingUsageTracker.swift`（推測）

**問題コード**（推測）:
```swift
class RecordingUsageTracker {
    func getTodayCount() -> Int {
        // ❌ UserDefaults に直接依存
        return UserDefaults.standard.integer(forKey: "dailyRecordingCount")
    }

    func incrementCount() {
        // ❌ UserDefaults に直接依存
        let count = getTodayCount() + 1
        UserDefaults.standard.set(count, forKey: "dailyRecordingCount")
    }
}
```

**DIP違反の証拠**:
```swift
// RecordingUsageTracker が UserDefaults という具象クラスに依存
UserDefaults.standard  // ← シングルトン、グローバル状態

// テスト時に問題が発生
// - テストが実際の UserDefaults を変更してしまう
// - テスト間で状態が共有される
// - テストが遅い（ディスクI/O）
```

---

### 推奨リファクタリング

#### Dependency Injection（依存性注入）

**Before**:
```swift
class PitchDetectionViewModel {
    func startTargetPitchMonitoring() {
        FileLogger.shared.log(...)  // 具象クラスに直接依存
    }
}
```

**After**:
```swift
// 1. 抽象（プロトコル）を定義
protocol Logger {
    func log(level: String, category: String, message: String)
}

// 2. 具象クラスがプロトコルを実装
class FileLogger: Logger {
    static let shared = FileLogger()

    func log(level: String, category: String, message: String) {
        // ファイルに書き込み
    }
}

// 3. ViewModelは抽象に依存
class PitchDetectionViewModel {
    private let logger: Logger  // ← プロトコルに依存

    init(logger: Logger) {
        self.logger = logger
    }

    func startTargetPitchMonitoring() {
        logger.log(
            level: "INFO",
            category: "pitch_monitoring",
            message: "🔵 Target pitch monitoring started"
        )
    }
}

// 4. DIコンテナで注入
class DependencyContainer {
    let logger: Logger = FileLogger.shared

    func makePitchDetectionViewModel() -> PitchDetectionViewModel {
        return PitchDetectionViewModel(
            logger: logger  // ← 抽象として注入
        )
    }
}

// 5. テストでモックを注入
class MockLogger: Logger {
    var loggedMessages: [String] = []

    func log(level: String, category: String, message: String) {
        loggedMessages.append(message)
    }
}

// テスト
func testStartTargetPitchMonitoring() async throws {
    let mockLogger = MockLogger()
    let viewModel = PitchDetectionViewModel(logger: mockLogger)

    try await viewModel.startTargetPitchMonitoring(settings: settings)

    XCTAssertTrue(mockLogger.loggedMessages.contains("🔵 Target pitch monitoring started"))
}
```

**改善点**:
- PitchDetectionViewModel が抽象に依存
- テストでモックを注入できる
- ロガーの実装を変更しても ViewModel に影響しない

---

#### Abstract Factory Pattern（抽象ファクトリパターン）

**Before**:
```swift
class DependencyContainer {
    let scalePlayer = AVAudioEngineScalePlayer()  // 具象クラスを直接インスタンス化
}
```

**After**:
```swift
// 1. ファクトリプロトコルを定義
protocol ScalePlayerFactory {
    func createScalePlayer() -> ScalePlayerProtocol
}

// 2. 具象ファクトリを実装
class AVAudioEngineScalePlayerFactory: ScalePlayerFactory {
    func createScalePlayer() -> ScalePlayerProtocol {
        return AVAudioEngineScalePlayer()
    }
}

// 3. DIコンテナは抽象に依存
class DependencyContainer {
    private let scalePlayerFactory: ScalePlayerFactory

    init(scalePlayerFactory: ScalePlayerFactory = AVAudioEngineScalePlayerFactory()) {
        self.scalePlayerFactory = scalePlayerFactory
    }

    func makeRecordingStateViewModel() -> RecordingStateViewModel {
        let scalePlayer = scalePlayerFactory.createScalePlayer()
        return RecordingStateViewModel(
            scalePlayer: scalePlayer
        )
    }
}

// 4. テストでモックファクトリを注入
class MockScalePlayerFactory: ScalePlayerFactory {
    func createScalePlayer() -> ScalePlayerProtocol {
        return MockScalePlayer()
    }
}

// テスト
func testDependencyContainer() {
    let container = DependencyContainer(scalePlayerFactory: MockScalePlayerFactory())
    let viewModel = container.makeRecordingStateViewModel()

    // ViewModel は MockScalePlayer を使っている
}
```

**改善点**:
- DependencyContainer が具象クラスを知らない
- 実装を変更しても DependencyContainer に影響しない
- テストで別の実装を注入できる

---

## まとめ

### SOLID原則の相互関係

```
Single Responsibility
    ↓ (責任を分離すると)
Interface Segregation
    ↓ (小さなインターフェースにすると)
Dependency Inversion
    ↓ (抽象に依存すると)
Liskov Substitution
    ↓ (置換可能性が保証されると)
Open/Closed
    ↓ (拡張が容易になる)

より良い設計
```

### Vocalis Studioでの優先順位

#### 🔴 最優先（今回のバグに直結）

1. **Single Responsibility Principle**
   - RecordingStateViewModel の責任分離
   - PitchDetectionViewModel の責任分離
   - → Shared Mutable State の解消

#### 🟡 高優先度（設計改善）

2. **Open/Closed Principle**
   - ScaleElement の switch 文をポリモーフィズムに変更
   - プラットフォーム固有のコードを Strategy パターンに変更

3. **Dependency Inversion Principle**
   - FileLogger の抽象化
   - UserDefaults の抽象化
   - テスタビリティの向上

#### 🟢 中優先度（長期的改善）

4. **Interface Segregation Principle**
   - ScalePlayerProtocol の分離
   - AudioPlayerProtocol の分離

5. **Liskov Substitution Principle**
   - プロトコルの契約明確化
   - モックの実装一貫性

### 推奨アクション

#### Phase 1: バグ修正（短期）
1. RecordingStateViewModel.stopPlayback() に scalePlayer.stop() を追加
2. 実行順序を明確化

#### Phase 2: SRP改善（中期）
1. ScalePlaybackCoordinator を抽出
2. CountdownManager を抽出
3. 責任を再配置

#### Phase 3: SOLID準拠（長期）
1. OCP: Strategy パターンの導入
2. DIP: 依存性注入の徹底
3. ISP: インターフェースの分離
4. LSP: 契約の明確化

### 期待される効果

- **保守性**: 変更の影響範囲が明確になる
- **テスタビリティ**: すべてのコンポーネントがテスト可能になる
- **拡張性**: 新機能の追加が容易になる
- **理解しやすさ**: コードの意図が明確になる
- **バグの減少**: 設計の問題によるバグが減る

### 参考文献

- **Clean Architecture** - Robert C. Martin
  - SOLID原則の詳細な解説
  - アーキテクチャパターンとの関係

- **Design Patterns** - Gang of Four
  - SOLID原則を実現するデザインパターン

- **Refactoring** - Martin Fowler
  - SOLID原則違反からのリファクタリング手法
