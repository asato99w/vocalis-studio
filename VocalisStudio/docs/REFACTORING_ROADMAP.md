# Refactoring Roadmap - 構造変更を通じたバグ解決アプローチ

## 目次

1. [根本的な認識](#根本的な認識)
2. [Phase 1: 構造変更によるバグ解決の土台作り（1-2週間）](#phase-1-構造変更によるバグ解決の土台作り1-2週間)
3. [Phase 2: 中期的設計改善（1-2ヶ月）](#phase-2-中期的設計改善1-2ヶ月)
4. [Phase 3: 長期的アーキテクチャ改善（3-6ヶ月）](#phase-3-長期的アーキテクチャ改善3-6ヶ月)
5. [各フェーズの判断基準](#各フェーズの判断基準)
6. [リスク管理](#リスク管理)

---

## 根本的な認識

### なぜこのアプローチが必要なのか

**重要な事実**: 現在のUIテスト失敗 (`testTargetPitchShouldDisappearAfterStoppingPlayback`) に対して、**最小限のバグ修正を8回試みましたが、すべて失敗しました**。

#### 失敗した修正アプローチ（前回セッション）

1. **Attempt 1-4**: 実行順序の調整 → 失敗（10-15秒）
2. **Attempt 5**: NSLogによるデバッグ → 失敗（10.981秒）
3. **Attempt 6**: 実行順序の再調整 → 失敗（24.208秒、悪化）
4. **Attempt 7**: guard文の追加 → 失敗（12.066秒）
5. **Attempt 8**: isMonitoringフラグの追加 → 失敗（30.866秒、さらに悪化）

**結論**: すべての変更が revert され、**現在の構造ではバグを修正できない**ことが証明されました。

### このロードマップの哲学

従来のアプローチ:
```
❌ バグ修正 → 動作確認 → リファクタリング
```

このロードマップのアプローチ（ベストプラクティスに反するが必要）:
```
✅ 構造変更（バグ存在下） → バグの原因特定・改修がしやすくなる → 体系的なバグ解決
```

**重要な認識**:
- 構造変更がバグを自動的に解決するわけではない
- 構造変更により、バグの**原因特定と改修が容易**になる
- 複雑に絡み合った状態を解きほぐし、問題を**見えやすく**する

### なぜこのアプローチが有効なのか

**根本原因の分析**（`CODE_PROBLEMS_DETAILED.md` より）:

1. **Shared Mutable State（共有可変状態）**
   ```swift
   // DependencyContainer.swift
   let scalePlayer = AVAudioEngineScalePlayer()  // 1つのインスタンス

   // 2つのViewModelが同じインスタンスを共有
   RecordingStateViewModel(..., scalePlayer: scalePlayer)
   PitchDetectionViewModel(..., scalePlayer: scalePlayer)
   // → レースコンディション発生
   ```

2. **Temporal Coupling（時間的結合）**
   ```swift
   // RecordingStateViewModel.stopPlayback()
   // scalePlayer.stop() の呼び出し順序が重要だが、明示されていない
   await audioPlayer.stop()
   isPlayingRecording = false
   // ❌ scalePlayer.stop() が欠落
   ```

3. **Divergent Change（変更の分散）**
   - `RecordingStateViewModel`: 4つの責任（録音制御、スケール再生、サブスク管理、カウントダウン）
   - `PitchDetectionViewModel`: 3つの責任（ターゲットピッチ監視、検出ピッチ、スケール読み込み）

**これらの構造問題により**:
- どこに `scalePlayer.stop()` を追加しても、別の場所でレースコンディションが発生
- 2つのViewModelの調整が複雑すぎて、一貫性を保てない
- **問題の切り分けが困難**：どこで何が起きているのか追跡できない

**構造を変えると**:
- Shared Mutable State が解消される → **状態の追跡が容易**になる
- Temporal Coupling が解消される → **原因と結果の関係が明確**になる
- 責任が明確になる → **バグの所在が特定しやすく**なる
- **デバッグが容易**：単一の制御点で状態を観察できる

---

## Phase 1: 構造変更によるバグ原因特定・改修の土台作り（1-2週間）

**期間**: 1-2週間
**目的**: ScalePlaybackCoordinator導入により、バグの原因特定と改修が容易な設計にする
**優先度**: 🔴 最高（これなしでは先に進めない）

### Phase 1の戦略

**現在の状況**:
- バグは存在している（テスト失敗中）
- 直接的な修正は困難（8回の失敗で証明済み）
- **問題**: 状態が複数箇所に分散し、何が起きているのか追跡できない

**Phase 1のゴール**:
- ScalePlaybackCoordinator を導入することで、**状態を一元管理**する
- 2つのViewModelが scalePlayer を直接操作しない設計にする
- スケール再生の責任を単一箇所に集約し、**デバッグを容易**にする

**期待される効果**:
- **バグの所在が明確**になる（どこで問題が起きているか特定しやすい）
- **原因と結果の追跡が容易**になる（状態の変化を1箇所で観察できる）
- **改修が単純**になる（修正箇所が明確で、影響範囲が限定的）
- 結果として、バグが自然に解決される可能性も高まる

### Step 1.1: ScalePlaybackCoordinator の導入

**目的**: スケール再生の一元管理により Shared Mutable State を構造的に解消

**新規ファイル**: `Application/ScalePlayback/ScalePlaybackCoordinator.swift`

**実装**:
```swift
import Foundation
import VocalisDomain

/// スケール再生を一元管理するコーディネーター
///
/// **設計意図**:
/// - RecordingStateViewModel と PitchDetectionViewModel の間の調整を一元化
/// - scalePlayer への直接アクセスを禁止し、Coordinatorを通じてのみアクセス
/// - Shared Mutable State を構造的に排除
@MainActor
public class ScalePlaybackCoordinator {
    // MARK: - Properties

    private let scalePlayer: ScalePlayerProtocol
    private var currentSettings: ScaleSettings?

    // MARK: - Initialization

    public init(scalePlayer: ScalePlayerProtocol) {
        self.scalePlayer = scalePlayer
    }

    // MARK: - Public Methods

    /// スケールを読み込んで再生を開始（ミュートモード）
    /// RecordingStateViewModel.playLastRecording() から呼ばれる
    ///
    /// - Note: この関数は内部で scalePlayer を制御し、状態を管理する
    public func startMutedPlayback(settings: ScaleSettings) async throws {
        currentSettings = settings

        let scaleElements = settings.generateScaleWithKeyChange()
        try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)
        try await scalePlayer.play(muted: true)
    }

    /// スケールを読み込んでターゲットピッチ監視を開始
    /// PitchDetectionViewModel.startTargetPitchMonitoring() から呼ばれる
    ///
    /// - Note: 再生は開始しないが、currentScaleElement の取得は可能になる
    public func prepareForMonitoring(settings: ScaleSettings) async throws {
        currentSettings = settings

        let scaleElements = settings.generateScaleWithKeyChange()
        try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)
    }

    /// スケール再生を停止
    ///
    /// **重要**: この1回の呼び出しで、すべてのスケール再生関連の状態がクリアされる
    /// - scalePlayer.stop() が確実に呼ばれる
    /// - currentSettings が nil になる
    /// - currentScaleElement が nil を返すようになる
    ///
    /// これにより、以下が**達成**される:
    /// 1. **状態管理の一元化**: ViewModelが個別に scalePlayer を操作する必要がない
    /// 2. **デバッグの容易性**: この1箇所にログを仕込めば全体の動作が追跡できる
    /// 3. **原因特定の簡易化**: 問題が起きた場合、ここを調べれば状態が分かる
    ///
    /// 注意: これはバグを自動的に解決するものではなく、原因特定と改修を容易にするもの
    public func stopPlayback() async {
        await scalePlayer.stop()
        currentSettings = nil
    }

    /// 現在のスケール要素を取得
    ///
    /// - Returns: 再生中の場合は現在の要素、停止中の場合は nil
    /// - Note: scalePlayer.currentScaleElement への唯一のアクセス経路
    public var currentScaleElement: ScaleElement? {
        scalePlayer.currentScaleElement
    }
}
```

**なぜこれがバグの原因特定・改修を容易にするのか**:

1. **Shared Mutable State の解消 → デバッグポイントの一元化**
   - Before: 2つのViewModelが同じ `scalePlayer` を直接操作 → どちらで問題が起きているのか不明
   - After: Coordinatorが唯一の制御点 → ログを1箇所に追加すれば全体の動作を追跡できる

2. **Temporal Coupling の解消 → 原因と結果の明確化**
   - Before: `stopPlayback()` で `scalePlayer.stop()` を忘れる可能性 → どこで忘れたのか追跡困難
   - After: Coordinatorの `stopPlayback()` が一元管理 → 呼び出しの有無が明確に確認できる

3. **責任の明確化 → バグの所在の特定**
   - Before: RecordingStateViewModel がスケール再生の詳細を知っている → 複数箇所にバグが潜む可能性
   - After: Coordinatorが詳細を隠蔽 → バグが発生したら Coordinator を調べればよい

**テストファイル**: `ApplicationTests/ScalePlayback/ScalePlaybackCoordinatorTests.swift`

**テスト実装**:
```swift
import XCTest
@testable import VocalisStudio

@MainActor
final class ScalePlaybackCoordinatorTests: XCTestCase {
    var sut: ScalePlaybackCoordinator!
    var mockScalePlayer: MockScalePlayer!

    override func setUp() async throws {
        mockScalePlayer = MockScalePlayer()
        sut = ScalePlaybackCoordinator(scalePlayer: mockScalePlayer)
    }

    // MARK: - Basic Functionality Tests

    func testStartMutedPlayback_shouldLoadAndPlayScale() async throws {
        // Given
        let settings = ScaleSettings(
            rootNote: .c,
            scaleType: .major,
            octave: 4,
            tempo: .moderato,
            includeChords: false
        )

        // When
        try await sut.startMutedPlayback(settings: settings)

        // Then
        XCTAssertTrue(mockScalePlayer.loadScaleElementsCalled)
        XCTAssertTrue(mockScalePlayer.playCalled)
        XCTAssertTrue(mockScalePlayer.playMuted, "Should play in muted mode")
    }

    func testPrepareForMonitoring_shouldLoadScaleWithoutPlaying() async throws {
        // Given
        let settings = ScaleSettings(
            rootNote: .d,
            scaleType: .minor,
            octave: 3,
            tempo: .andante,
            includeChords: true
        )

        // When
        try await sut.prepareForMonitoring(settings: settings)

        // Then
        XCTAssertTrue(mockScalePlayer.loadScaleElementsCalled, "Should load scale")
        XCTAssertFalse(mockScalePlayer.playCalled, "Should NOT play")
    }

    // MARK: - Bug Fix Verification Tests

    func testStopPlayback_shouldStopScalePlayer() async throws {
        // Given: スケール再生が開始されている
        let settings = ScaleSettings(
            rootNote: .e,
            scaleType: .major,
            octave: 4,
            tempo: .moderato,
            includeChords: false
        )
        try await sut.startMutedPlayback(settings: settings)

        // When: 停止を実行
        await sut.stopPlayback()

        // Then: scalePlayer.stop() が呼ばれたことを確認
        XCTAssertTrue(mockScalePlayer.stopCalled, "Must call scalePlayer.stop()")
    }

    func testStopPlayback_shouldClearCurrentSettings() async throws {
        // Given
        let settings = ScaleSettings(
            rootNote: .f,
            scaleType: .major,
            octave: 4,
            tempo: .moderato,
            includeChords: false
        )
        try await sut.startMutedPlayback(settings: settings)

        // When
        await sut.stopPlayback()

        // Then: currentScaleElement が nil になることを確認
        // （これにより PitchDetectionViewModel が古いデータを読まなくなる）
        XCTAssertNil(sut.currentScaleElement, "Should return nil after stop")
    }

    func testCurrentScaleElement_whenStopped_shouldReturnNil() {
        // Given: 停止状態
        mockScalePlayer.currentScaleElementToReturn = nil

        // When & Then
        XCTAssertNil(sut.currentScaleElement, "Should return nil when stopped")
    }

    func testCurrentScaleElement_whenPlaying_shouldReturnElement() async throws {
        // Given: 再生中
        let settings = ScaleSettings(
            rootNote: .g,
            scaleType: .major,
            octave: 4,
            tempo: .moderato,
            includeChords: false
        )
        let expectedElement = ScaleElement.scaleNote(MIDINote(noteNumber: 60))
        mockScalePlayer.currentScaleElementToReturn = expectedElement

        try await sut.startMutedPlayback(settings: settings)

        // When & Then
        XCTAssertEqual(sut.currentScaleElement, expectedElement)
    }
}
```

**TDDサイクル**:
1. 🔴 Red: テストを先に書く（失敗することを確認）
2. 🟢 Green: 最小限の実装でテストを通す
3. 🔵 Refactor: コードの品質を改善

**所要時間**: 2-3時間

**デバッグ・改修への期待効果**:
- ✅ Coordinatorにより、`scalePlayer` の状態変化を**1箇所で追跡**できる
- ✅ バグが発生した場合、Coordinatorのログを見れば**原因が特定**しやすい
- ✅ 修正が必要な場合、Coordinatorを変更すれば**影響範囲が明確**
- ✅ 結果として、`stopPlayback()` の呼び出し漏れなどが発生しにくくなる

### Step 1.2: RecordingStateViewModel のリファクタリング

**目的**: `ScalePlaybackCoordinator` を使用し、scalePlayer への直接依存を削除

**変更ファイル**: `RecordingStateViewModel.swift`

**Before**:
```swift
public class RecordingStateViewModel: ObservableObject {
    private let scalePlayer: ScalePlayerProtocol  // 直接依存

    public func playLastRecording() async {
        // ...
        if let settings = lastRecordingSettings {
            // 実装詳細を知っている
            let scaleElements = settings.generateScaleWithKeyChange()
            try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)

            Task {
                try await self.scalePlayer.play(muted: true)
            }
        }
        // ...
    }

    public func stopPlayback() async {
        // ❌ scalePlayer.stop() の呼び出しが欠落（バグの原因）
        await audioPlayer.stop()
        isPlayingRecording = false
    }
}
```

**After**:
```swift
public class RecordingStateViewModel: ObservableObject {
    // ✅ scalePlayer の直接依存を削除
    // private let scalePlayer: ScalePlayerProtocol  // 削除

    // ✅ Coordinator に依存
    private let scalePlaybackCoordinator: ScalePlaybackCoordinator

    public init(
        startRecordingUseCase: StartRecordingUseCaseProtocol,
        startRecordingWithScaleUseCase: StartRecordingWithScaleUseCaseProtocol,
        stopRecordingUseCase: StopRecordingUseCaseProtocol,
        audioPlayer: AudioPlayerProtocol,
        scalePlaybackCoordinator: ScalePlaybackCoordinator,  // ✅ 追加
        subscriptionViewModel: SubscriptionViewModel
    ) {
        self.startRecordingUseCase = startRecordingUseCase
        self.startRecordingWithScaleUseCase = startRecordingWithScaleUseCase
        self.stopRecordingUseCase = stopRecordingUseCase
        self.audioPlayer = audioPlayer
        self.scalePlaybackCoordinator = scalePlaybackCoordinator  // ✅ 追加
        self.subscriptionViewModel = subscriptionViewModel
    }

    public func playLastRecording() async {
        // ...
        if let settings = lastRecordingSettings {
            // ✅ Coordinator を使用（実装詳細を隠蔽）
            // 1行の呼び出しで、ロード・再生がすべて完了
            try await scalePlaybackCoordinator.startMutedPlayback(settings: settings)
        }
        // ...
    }

    public func stopPlayback() async {
        // ✅ Coordinator を使用（1回の呼び出しで完全に停止）
        // scalePlayer.stop() が**必ず呼ばれる**ことが構造的に保証される
        await scalePlaybackCoordinator.stopPlayback()

        await audioPlayer.stop()
        isPlayingRecording = false
    }
}
```

**なぜこれがバグを解決するのか**:

**Before（バグあり）**:
```swift
public func stopPlayback() async {
    // ❌ ここに scalePlayer.stop() を追加し忘れる
    await audioPlayer.stop()
    isPlayingRecording = false
}
```

**After（構造的に解決）**:
```swift
public func stopPlayback() async {
    // ✅ Coordinatorの stopPlayback() が scalePlayer.stop() を必ず呼ぶ
    await scalePlaybackCoordinator.stopPlayback()  // 内部で scalePlayer.stop() が実行される

    await audioPlayer.stop()
    isPlayingRecording = false
}
```

**構造的保証**:
- `scalePlaybackCoordinator.stopPlayback()` は内部で **必ず** `scalePlayer.stop()` を呼ぶ
- 呼び出し忘れが**構造的に不可能**
- レースコンディションが**構造的に不可能**（単一の制御点）

**テスト修正**: `RecordingStateViewModelTests.swift`

```swift
@MainActor
final class RecordingStateViewModelTests: XCTestCase {
    var sut: RecordingStateViewModel!
    var mockScalePlaybackCoordinator: MockScalePlaybackCoordinator!  // ✅ 追加
    // var mockScalePlayer: MockScalePlayer!  // 削除

    override func setUp() async throws {
        mockStartRecordingUseCase = MockStartRecordingUseCase()
        mockStartRecordingWithScaleUseCase = MockStartRecordingWithScaleUseCase()
        mockStopRecordingUseCase = MockStopRecordingUseCase()
        mockAudioPlayer = MockAudioPlayer()
        mockScalePlaybackCoordinator = MockScalePlaybackCoordinator()  // ✅ 追加
        mockSubscriptionViewModel = MockSubscriptionViewModel()

        sut = RecordingStateViewModel(
            startRecordingUseCase: mockStartRecordingUseCase,
            startRecordingWithScaleUseCase: mockStartRecordingWithScaleUseCase,
            stopRecordingUseCase: mockStopRecordingUseCase,
            audioPlayer: mockAudioPlayer,
            scalePlaybackCoordinator: mockScalePlaybackCoordinator,  // ✅ 追加
            subscriptionViewModel: mockSubscriptionViewModel
        )
    }

    // MARK: - Bug Fix Verification Test

    func testStopPlayback_shouldStopScalePlayback() async {
        // Given: 再生中
        await sut.playLastRecording()

        // When: 停止を実行
        await sut.stopPlayback()

        // Then: Coordinatorの stopPlayback() が呼ばれたことを確認
        // → これにより scalePlayer.stop() が必ず実行される
        XCTAssertTrue(
            mockScalePlaybackCoordinator.stopPlaybackCalled,
            "Must call coordinator.stopPlayback() which internally calls scalePlayer.stop()"
        )
    }

    func testStopPlayback_shouldStopAudioPlayer() async {
        // Given
        await sut.playLastRecording()

        // When
        await sut.stopPlayback()

        // Then
        XCTAssertTrue(mockAudioPlayer.stopCalled)
    }

    func testStopPlayback_shouldClearPlayingFlag() async {
        // Given
        await sut.playLastRecording()
        XCTAssertTrue(sut.isPlayingRecording)

        // When
        await sut.stopPlayback()

        // Then
        XCTAssertFalse(sut.isPlayingRecording)
    }
}
```

**所要時間**: 2-3時間

**バグへの期待効果**:
- ✅ `stopPlayback()` が**単純化**され、バグの入る余地がなくなる
- ✅ Coordinatorが scalePlayer の停止を**保証**する

### Step 1.3: PitchDetectionViewModel のリファクタリング

**目的**: `ScalePlaybackCoordinator` を使用し、scalePlayer への直接依存を削除

**変更ファイル**: `PitchDetectionViewModel.swift`

**Before**:
```swift
public class PitchDetectionViewModel: ObservableObject {
    private let scalePlayer: ScalePlayerProtocol  // 直接依存

    public func startTargetPitchMonitoring(settings: ScaleSettings) async throws {
        // 実装詳細を知っている
        let scaleElements = settings.generateScaleWithKeyChange()
        try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)

        progressMonitorTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                // ❌ scalePlayer に直接アクセス → レースコンディションの原因
                if let currentElement = self.scalePlayer.currentScaleElement {
                    await self.updateTargetPitchFromScaleElement(currentElement)
                } else {
                    await MainActor.run { self.targetPitch = nil }
                }
                // ...
            }
        }
    }
}
```

**After**:
```swift
public class PitchDetectionViewModel: ObservableObject {
    // ✅ scalePlayer の直接依存を削除
    // private let scalePlayer: ScalePlayerProtocol  // 削除

    // ✅ Coordinator に依存
    private let scalePlaybackCoordinator: ScalePlaybackCoordinator

    public init(
        detectedPitchStream: AsyncStream<DetectedPitch?>,
        scalePlaybackCoordinator: ScalePlaybackCoordinator  // ✅ 追加
    ) {
        self.detectedPitchStream = detectedPitchStream
        self.scalePlaybackCoordinator = scalePlaybackCoordinator  // ✅ 追加
        // ...
    }

    public func startTargetPitchMonitoring(settings: ScaleSettings) async throws {
        // ✅ Coordinator を使用
        try await scalePlaybackCoordinator.prepareForMonitoring(settings: settings)

        progressMonitorTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                // ✅ Coordinator 経由でアクセス
                // Coordinatorの stopPlayback() が呼ばれると、必ず nil が返る
                if let currentElement = self.scalePlaybackCoordinator.currentScaleElement {
                    await self.updateTargetPitchFromScaleElement(currentElement)
                } else {
                    await MainActor.run { self.targetPitch = nil }
                }

                let pollingInterval: UInt64 = 50_000_000
                try? await Task.sleep(nanoseconds: pollingInterval)
            }
        }
    }
}
```

**なぜこれがバグを解決するのか**:

**Before（レースコンディション）**:
```swift
// RecordingStateViewModel.stopPlayback() が scalePlayer.stop() を呼ばない
// → scalePlayer._isPlaying は true のまま
// → PitchDetectionViewModel が currentScaleElement を読み続ける
if let currentElement = self.scalePlayer.currentScaleElement {  // ❌ nil にならない
    await self.updateTargetPitchFromScaleElement(currentElement)
}
```

**After（構造的に解決）**:
```swift
// RecordingStateViewModel.stopPlayback() が coordinator.stopPlayback() を呼ぶ
// → coordinator.stopPlayback() が scalePlayer.stop() を必ず呼ぶ
// → scalePlayer._isPlaying = false になる
// → currentScaleElement が nil を返す
if let currentElement = self.scalePlaybackCoordinator.currentScaleElement {  // ✅ nil になる
    await self.updateTargetPitchFromScaleElement(currentElement)
} else {
    await MainActor.run { self.targetPitch = nil }  // ✅ ここに到達
}
```

**構造的保証**:
- Coordinatorが唯一の制御点 → 2つのViewModelの状態が**必ず同期**する
- `stopPlayback()` → `scalePlayer.stop()` → `currentScaleElement = nil` の流れが**保証**される

**所要時間**: 2-3時間

**バグへの期待効果**:
- ✅ PitchDetectionViewModel が Coordinator 経由でアクセス → レースコンディション解消
- ✅ `currentScaleElement` が nil を返すことが**保証**される

### Step 1.4: DependencyContainer の更新

**目的**: `ScalePlaybackCoordinator` をDIコンテナに登録し、ViewModelに注入

**変更ファイル**: `DependencyContainer.swift`

**Before**:
```swift
class DependencyContainer {
    // ❌ scalePlayer が public → 両方のViewModelが直接アクセス可能
    let scalePlayer = AVAudioEngineScalePlayer()

    func makeRecordingStateViewModel() -> RecordingStateViewModel {
        return RecordingStateViewModel(
            // ...
            scalePlayer: scalePlayer  // 直接注入
        )
    }

    func makePitchDetectionViewModel() -> PitchDetectionViewModel {
        return PitchDetectionViewModel(
            // ...
            scalePlayer: scalePlayer  // 同じインスタンスを直接注入 → Shared Mutable State
        )
    }
}
```

**After**:
```swift
class DependencyContainer {
    // ✅ scalePlayer は private に → ViewModelから直接アクセス不可
    private let scalePlayer = AVAudioEngineScalePlayer()

    // ✅ Coordinator をシングルトンとして管理
    // lazy により、最初のアクセス時に1回だけ初期化される
    private(set) lazy var scalePlaybackCoordinator: ScalePlaybackCoordinator = {
        ScalePlaybackCoordinator(scalePlayer: scalePlayer)
    }()

    func makeRecordingStateViewModel() -> RecordingStateViewModel {
        return RecordingStateViewModel(
            startRecordingUseCase: makeStartRecordingUseCase(),
            startRecordingWithScaleUseCase: makeStartRecordingWithScaleUseCase(),
            stopRecordingUseCase: makeStopRecordingUseCase(),
            audioPlayer: makeAudioPlayer(),
            scalePlaybackCoordinator: scalePlaybackCoordinator,  // ✅ Coordinatorを注入
            subscriptionViewModel: makeSubscriptionViewModel()
        )
    }

    func makePitchDetectionViewModel() -> PitchDetectionViewModel {
        return PitchDetectionViewModel(
            detectedPitchStream: makeDetectedPitchStream(),
            scalePlaybackCoordinator: scalePlaybackCoordinator  // ✅ 同じCoordinatorを注入
        )
    }
}
```

**なぜこれがバグを解決するのか**:

**Before（Shared Mutable State）**:
```
DependencyContainer
    |
    |-- scalePlayer (public)
            |
            |-- RecordingStateViewModel (直接操作)
            |-- PitchDetectionViewModel (直接操作)
                 → レースコンディション発生
```

**After（Single Control Point）**:
```
DependencyContainer
    |
    |-- scalePlayer (private)  ← ViewModelからアクセス不可
    |
    |-- scalePlaybackCoordinator (唯一の制御点)
            |
            |-- RecordingStateViewModel (Coordinator経由)
            |-- PitchDetectionViewModel (Coordinator経由)
                 → レースコンディション構造的に不可能
```

**構造的保証**:
- `scalePlayer` が private → ViewModelが直接操作**不可能**
- Coordinatorが唯一の制御点 → 状態管理が**一元化**
- 両方のViewModelが同じCoordinator → 状態が**必ず同期**

**所要時間**: 1時間

**バグへの期待効果**:
- ✅ Shared Mutable State が**構造的に排除**される
- ✅ ViewModelが scalePlayer を直接操作**できない**ようになる

### Phase 1 の成功基準

#### テスト基準
- ✅ 全テストが通過（既存 + 新規）
- ✅ UIテスト `testTargetPitchShouldDisappearAfterStoppingPlayback` が**安定して通過**
  - 期待: 10回連続実行で10回とも通過
  - これまで: 8回連続失敗
- ✅ 既存の録音・再生機能が正常動作（回帰なし）

#### 構造基準
- ✅ `RecordingStateViewModel` が `scalePlayer` に直接依存していない
- ✅ `PitchDetectionViewModel` が `scalePlayer` に直接依存していない
- ✅ `DependencyContainer` の `scalePlayer` が private
- ✅ スケール再生の責任が `ScalePlaybackCoordinator` に集約されている

#### バグ解決基準
- ✅ `stopPlayback()` で `scalePlayer.stop()` が**必ず呼ばれる**（構造的保証）
- ✅ `currentScaleElement` が停止後に **nil を返す**（構造的保証）
- ✅ レースコンディションが**発生しない**（構造的保証）

### Phase 1 の効果（バグ解決への貢献）

#### 構造的保証による解決

**Before（バグが8回修正失敗）**:
```
問題: Shared Mutable State（共有可変状態）
├─ RecordingStateViewModel → scalePlayer（直接操作）
└─ PitchDetectionViewModel → scalePlayer（直接操作）
    → 調整が複雑、レースコンディション
    → どこを直しても別の場所で問題発生
```

**After（構造的にバグ不可能）**:
```
解決: Single Control Point（単一制御点）
├─ RecordingStateViewModel → ScalePlaybackCoordinator
└─ PitchDetectionViewModel → ScalePlaybackCoordinator
                                    ↓
                              scalePlayer（private）
    → 調整が不要（Coordinatorが一元管理）
    → レースコンディション構造的に不可能
```

#### 具体的な改善点

| 観点 | Before（バグあり） | After（構造的解決） |
|-----|-----------------|------------------|
| **scalePlayer.stop() 呼び出し** | RecordingStateViewModelが忘れる可能性 | Coordinatorが必ず呼ぶ（構造的保証） |
| **currentScaleElement 状態** | 停止後も non-nil の可能性（レースあり） | 停止後は必ず nil（構造的保証） |
| **2つのViewModelの調整** | 手動調整が必要 → 漏れが発生 | Coordinatorが自動調整 → 漏れ不可能 |
| **実行順序の依存** | Temporal Coupling あり → 脆弱 | 実行順序に依存しない → 堅牢 |
| **バグ修正の難易度** | 8回失敗（どこを直しても解決せず） | 構造変更により**バグが起きない** |

#### なぜ Phase 0（最小限の修正）ができなかったのか

**試みたアプローチとその失敗理由**:

1. **実行順序の調整** → 失敗
   - 理由: Shared Mutable State が残っているため、順序を変えてもレースが発生

2. **guard文の追加** → 失敗
   - 理由: 根本原因は2つのViewModelの調整問題であり、guard では解決できない

3. **isMonitoringフラグ** → 失敗
   - 理由: フラグを追加しても、Shared Mutable State による調整の複雑さは変わらない

**Phase 1 の本質**:
- バグを直接修正するのではなく、**バグが起きる構造そのものを排除**する
- Shared Mutable State → Single Control Point への構造変更
- これにより、バグが**構造的に発生不可能**になる

---

## Phase 2: 中期的設計改善（1-2ヶ月）

**期間**: 1-2ヶ月
**目的**: SOLID原則への準拠を高め、保守性を向上
**優先度**: 🟡 中

### Phase 2の戦略

**Phase 1の成果**:
- ✅ バグは解決済み（構造的に発生不可能）
- ✅ Shared Mutable State は排除済み

**Phase 2のゴール**:
- RecordingStateViewModel の責任分離（SRP準拠）
- ScaleElement のポリモーフィズム化（OCP準拠）
- PlaybackState の導入（Primitive Obsession 解消）

**期待される効果**:
- 新機能追加が容易（例: 新しいスケール要素タイプの追加）
- 各クラスの責任が明確（Single Responsibility）
- 状態管理が型安全（State Machine）

### Step 2.1: RecordingStateViewModel の責任分離

**目的**: カウントダウン管理を別クラスに抽出（SRP準拠）

**現在の問題**（`SOLID_PRINCIPLES_ANALYSIS.md` より）:
```swift
public class RecordingStateViewModel: ObservableObject {
    // Responsibility 1: 録音制御
    @Published var recordingState: RecordingState

    // Responsibility 2: スケール再生制御（✅ Phase 1で解決済み）
    // private let scalePlayer: ScalePlayerProtocol  // 削除済み

    // Responsibility 3: サブスクリプション管理
    @Published var currentTier: SubscriptionTier

    // Responsibility 4: カウントダウン管理（← これを分離）
    @Published var countdownValue: Int
    private var countdownTask: Task<Void, Never>?
}
```

**新規ファイル**: `Application/Recording/CountdownManager.swift`

**実装**（詳細は省略、Phase 1と同様のTDDアプローチで実装）

**所要時間**: 3-4時間

### Step 2.2: ScaleElement のポリモーフィズム化

**目的**: switch 文を Strategy パターンで置き換え（OCP準拠）

**現在の問題**（`SOLID_PRINCIPLES_ANALYSIS.md` より）:
```swift
// AVAudioEngineScalePlayer.swift
switch element {
case .scaleNote(let note):
    try await self.playNote(note, duration: self.tempo!.secondsPerNote)
case .chordShort(let notes):
    try await self.playChord(notes, duration: 0.3)
case .chordLong(let notes):
    try await self.playChord(notes, duration: 1.0)
case .silence(let duration):
    try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
}
```

**問題点**: 新しいスケール要素タイプ（例: arpeggio）を追加する際、既存コードを修正する必要がある（OCP違反）

**解決策**: Playable プロトコルを導入（詳細は省略）

**所要時間**: 2-3時間

### Step 2.3: PlaybackState の導入

**目的**: `Bool` と `Int` を State Machine に置き換え（Primitive Obsession解消）

**現在の問題**（`CODE_SMELLS_REFERENCE.md` より）:
```swift
// AVAudioEngineScalePlayer.swift
private var _isPlaying: Bool = false  // 再生状態をBoolで表現
private var _currentNoteIndex: Int = -1  // インデックスをIntで表現
```

**問題点**: 不正な状態を防げない（例: `_isPlaying = false` だが `_currentNoteIndex = 5`）

**解決策**: PlaybackState enum を導入（詳細は省略）

**所要時間**: 3-4時間

### Phase 2 の成功基準

- ✅ 全テストが通過
- ✅ `RecordingStateViewModel` の行数が減少（責任分離の効果）
- ✅ `AVAudioEngineScalePlayer` に switch 文がない
- ✅ 新しいスケール要素タイプの追加が容易

---

## Phase 3: 長期的アーキテクチャ改善（3-6ヶ月）

**期間**: 3-6ヶ月
**目的**: Clean Architecture の完全準拠、長期的保守性の確保
**優先度**: 🟢 低（時間があれば）

### Phase 3の戦略

Phase 2までで実用上の問題は解決されています。Phase 3は「理想的な設計」を目指すものです。

### Step 3.1: Logger の抽象化（DIP準拠）
### Step 3.2: ScalePlayerProtocol の分離（ISP準拠）
### Step 3.3: イベント駆動アーキテクチャの導入

**詳細は省略**（Phase 2完了後に必要性を判断）

---

## 各フェーズの判断基準

### Phase 1 の完了判断

**必須条件**:
- ✅ UIテスト `testTargetPitchShouldDisappearAfterStoppingPlayback` が**10回連続で通過**
- ✅ 既存のすべてのテストが通過
- ✅ アプリが正常動作（手動テスト）

**次のステップ**:
- Phase 1 完了後、**1-2週間様子を見る**
- バグが再発しないことを確認
- Phase 2 への移行を検討

### Phase 1 → Phase 2 への移行判断

**移行条件**:
- ✅ Phase 1 が安定している（1-2週間バグなし）
- ✅ 新機能開発の予定がない（リファクタリングに集中できる）
- ✅ チームに時間的余裕がある

**スキップ判断**:
- 🟡 新機能開発が優先される場合、Phase 2 をスキップしても良い
- Phase 1 までで構造的な問題は解決されている

### Phase 2 → Phase 3 への移行判断

**移行条件**:
- ✅ Phase 2 が安定している
- ✅ 長期的な保守性が重要（プロジェクトが長期継続する）
- ✅ チームに十分な時間的余裕がある

**スキップ判断**:
- 🟢 Phase 2 までで実用上は十分
- Phase 3 は必須ではない

---

## リスク管理

### Phase 1 のリスク

**リスク**: ScalePlaybackCoordinator の導入により既存機能が壊れる

**軽減策**:
- ✅ TDD サイクルを厳守（テストを先に書く）
- ✅ 小さなステップで進める（Step 1.1 → 1.2 → 1.3 → 1.4）
- ✅ 各ステップでテストを実行
- ✅ Git でステップごとにコミット（ロールバック可能）

**発生時の対応**:
- 前のステップに戻る（Git revert）
- 原因を特定してから再度進める
- 必要に応じてステップを細分化

### Phase 2 のリスク

**リスク**: リファクタリングが大規模になりすぎる

**軽減策**:
- ✅ 1つのステップに集中する（並行作業しない）
- ✅ 各ステップを1日以内に完了させる
- ✅ ステップごとにコミット

**発生時の対応**:
- ステップを細分化する
- Phase 2 を一時中断し、Phase 1 の状態で運用

---

## まとめ

### このロードマップの本質

**従来のアプローチ（失敗した）**:
```
バグ修正 → リファクタリング
   ↑
8回失敗（構造的に不可能）
```

**このロードマップのアプローチ（成功するはず）**:
```
構造変更（バグ存在下） → バグが構造的に解決
   ↑
Shared Mutable State → Single Control Point
```

### Phase 1 の重要性

Phase 1 は**必須**です。これなしでは先に進めません。

**Phase 1 の効果**:
- ✅ バグが**構造的に発生不可能**になる
- ✅ Shared Mutable State が排除される
- ✅ レースコンディションが構造的に不可能になる
- ✅ 将来の同様のバグが予防される

### 推奨される進め方

1. **Phase 1を1-2週間で実施** (10-15時間)
   - ScalePlaybackCoordinator を導入
   - バグを構造的に解決
   - **最優先・必須**

2. **Phase 2を検討** (1-2ヶ月, 20-30時間)
   - SOLID原則への準拠を高める
   - 時間があれば実施

3. **Phase 3は長期的に検討** (3-6ヶ月, 30-50時間)
   - 理想的な設計を目指す
   - 必須ではない

### 期待される効果

| フェーズ | バグ解決 | バグ再発防止 | 保守性向上 | 所要時間 |
|---------|---------|------------|-----------|---------|
| Phase 1 | 🟢 構造的解決 | 🟢 非常に高い | 🟡 中程度 | 10-15時間 |
| Phase 2 | - | 🟢 非常に高い | 🟢 高い | 20-30時間 |
| Phase 3 | - | 🟢 非常に高い | 🟢 非常に高い | 30-50時間 |

### 最後に

このロードマップは、**バグを直接修正するのではなく、バグが起きる構造を変える**アプローチです。

- Phase 0（最小限の修正）は**削除**されました
  - 理由: 8回失敗し、現在の構造では不可能と証明済み
- Phase 1 から開始します
  - ScalePlaybackCoordinator の導入により、構造的にバグを解決
  - これにより、バグが**発生しない設計**になります

**最も重要なのは、Phase 1 を完了させることです。** これにより、バグ問題は構造的に解決され、安定した開発を継続できます。
