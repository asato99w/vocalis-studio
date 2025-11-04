# テスト失敗調査計画: 7-11番

**作成日**: 2025-11-04
**対象**: Unit Tests (VocalisStudioTests)
**失敗テスト数**: 5個

## 失敗テスト一覧

### 7. AVAudioEngineScalePlayerTests.testPlay_CompletesSuccessfully()

**テストファイル**: `VocalisStudioTests/Infrastructure/Audio/AVAudioEngineScalePlayerTests.swift:144-155`
**実装ファイル**: `VocalisStudio/Infrastructure/Audio/AVAudioEngineScalePlayer.swift`

**テスト目的**: スケール再生が正常に完了し、完了後の状態が正しいことを確認

**テストコード**:
```swift
func testPlay_CompletesSuccessfully() async throws {
    let notes = [try MIDINote(60)]
    let tempo = try Tempo(secondsPerNote: 0.1)

    try await sut.loadScale(notes, tempo: tempo)
    try await sut.play()  // ← ここで完了を待つ

    // After completion, should not be playing
    XCTAssertFalse(sut.isPlaying)
    XCTAssertEqual(sut.progress, 1.0)
}
```

**失敗時の実行時間**: 0.031秒 (非常に短い)

**想定される問題**:
1. **非同期処理の変更**: `play()`メソッドが即座に戻るように変更された（実装コード210行目のコメント: "Don't wait for playback to complete - return immediately"）
2. **テストの期待値との不一致**: テストは`play()`が完了を待つことを期待しているが、実装は即座に戻る
3. **progress計算の問題**: 再生開始直後に`progress`が1.0になっていない

**調査手順**:
1. ✅ 実装ファイル確認: `AVAudioEngineScalePlayer.swift` 読み込み済み
2. ✅ `play()`メソッドの非同期動作確認:
   - `playLegacyScale()` (220-266行目) の動作を確認
   - Task内で非同期実行されている
   - 210行目: "Don't wait for playback to complete - return immediately"
3. ✅ テスト実行とエラー詳細確認:
   - 個別テスト実行完了
   - 実行時間: 0.468秒 (0.1秒音符×1 = 実際に再生完了している)
4. ✅ テストの修正方針決定: Option A を選択

**調査結果 (Phase 2 完了)**:
- **根本原因特定**: `play()` メソッドの設計変更
- **詳細**:
  - `play()` メソッドは Task をバックグラウンドで起動して即座に戻る
  - テストは `play()` が完了を待つことを期待している
  - テスト直後に `isPlaying` をチェックするため、まだ再生中（true）の状態
  - 実際には 0.468秒後に再生完了しているが、テストはそれを待たない
- **失敗したアサーション**:
  - `XCTAssertFalse(sut.isPlaying)` → 実際は true
  - `XCTAssertEqual(sut.progress, 1.0)` → 実際は 0.0 または中間値

**修正案 (確定)**:
- **推奨**: Option A - テストを実装の非同期動作に合わせて修正
  ```swift
  func testPlay_CompletesSuccessfully() async throws {
      let notes = [try MIDINote(60)]
      let tempo = try Tempo(secondsPerNote: 0.1)

      try await sut.loadScale(notes, tempo: tempo)
      try await sut.play()  // 即座に戻る

      // Playing should start
      XCTAssertTrue(sut.isPlaying)

      // Wait for completion
      try await Task.sleep(nanoseconds: 200_000_000) // 0.2秒

      // After completion
      XCTAssertFalse(sut.isPlaying)
      XCTAssertEqual(sut.progress, 1.0)
  }
  ```

---

### 8. ScalePlaybackCoordinatorTests.testStartMutedPlayback_shouldLoadAndPlayScaleInMutedMode()

**テストファイル**: `VocalisStudioTests/Application/Services/ScalePlaybackCoordinatorTests.swift:24-40`
**実装ファイル**: `VocalisStudio/Application/Services/ScalePlaybackCoordinator.swift`

**テスト目的**: ミュート再生が正しく開始され、MockScalePlayerの呼び出しが正しいことを確認

**テストコード**:
```swift
func testStartMutedPlayback_shouldLoadAndPlayScaleInMutedMode() async throws {
    let settings = ScaleSettings(...)

    try await sut.startMutedPlayback(settings: settings)

    XCTAssertTrue(mockScalePlayer.loadScaleCalled)
    XCTAssertTrue(mockScalePlayer.playCalled)
    XCTAssertEqual(mockScalePlayer.playMuted, true)
}
```

**失敗時の実行時間**: 0.004秒 (即座に失敗)

**想定される問題**:
1. **非同期Taskの問題**: `startMutedPlayback()`が`Task { try await scalePlayer.play(muted: true) }`でバックグラウンド実行している（実装49-55行目）
2. **タイミング問題**: Taskが実行される前にテストが完了している
3. **MockScalePlayerの更新タイミング**: `playCalled`フラグがTask実行前に検証されている

**調査手順**:
1. ✅ 実装ファイル確認: `ScalePlaybackCoordinator.swift` 読み込み済み
2. ✅ `startMutedPlayback()`の非同期動作確認:
   - 49-55行目: Task内で`play(muted: true)`を呼び出し
   - 非ブロッキング実装
3. ✅ MockScalePlayerの実装確認:
   - テストファイル内のMockで`playCalled`フラグを使用
   - `playCalled`フラグはTask内で更新される
4. ✅ テスト修正方針決定: 待機時間追加を選択

**調査結果 (Phase 3 完了)**:
- **根本原因特定**: バックグラウンドTaskのタイミング問題
- **詳細**:
  - `startMutedPlayback()` メソッドは `Task { try await scalePlayer.play(muted: true) }` でバックグラウンド実行
  - メソッドは Task を起動して即座に戻る
  - テストは即座にアサーションをチェックするため、Task がまだ実行されていない
  - MockScalePlayerの `playCalled` フラグがTask実行前に検証される
- **実行時間**: 0.004秒 (即座に失敗 = Task実行前)
- **失敗したアサーション**:
  - `XCTAssertTrue(mockScalePlayer.playCalled)` → 実際は false (Taskがまだ実行されていない)
  - `XCTAssertEqual(mockScalePlayer.playMuted, true)` → 同様に未設定

**修正案 (確定)**:
- **推奨**: テストに待機時間を追加してTask実行を待つ
  ```swift
  func testStartMutedPlayback_shouldLoadAndPlayScaleInMutedMode() async throws {
      let settings = ScaleSettings(...)

      try await sut.startMutedPlayback(settings: settings)

      // Wait for background Task to execute
      try await Task.sleep(nanoseconds: 50_000_000) // 50ms

      XCTAssertTrue(mockScalePlayer.loadScaleCalled)
      XCTAssertTrue(mockScalePlayer.playCalled)
      XCTAssertEqual(mockScalePlayer.playMuted, true)
  }
  ```

---

### 9-11. RealtimePitchDetectorTests (3個)

**テストファイル**: `VocalisStudioTests/Infrastructure/Audio/RealtimePitchDetectorTests.swift`
**実装ファイル**: `VocalisStudio/Infrastructure/Audio/RealtimePitchDetector.swift`

#### 9. testStartRealtimeDetection_WhenNotDetecting_SetsIsDetectingTrue() (35-41行目)

**テスト目的**: 初期状態から`startRealtimeDetection()`を呼び出すと`isDetecting`がtrueになることを確認

**テストコード**:
```swift
func testStartRealtimeDetection_WhenNotDetecting_SetsIsDetectingTrue() throws {
    try sut.startRealtimeDetection()
    XCTAssertTrue(sut.isDetecting)
}
```

**失敗時の実行時間**: 0.013秒

#### 10. testStartRealtimeDetection_WhenAlreadyDetecting_DoesNothing() (43-53行目)

**テスト目的**: すでに検出中の状態で再度`startRealtimeDetection()`を呼び出してもエラーなく動作することを確認

**テストコード**:
```swift
func testStartRealtimeDetection_WhenAlreadyDetecting_DoesNothing() throws {
    try sut.startRealtimeDetection()
    XCTAssertTrue(sut.isDetecting)

    try sut.startRealtimeDetection()  // 再度呼び出し
    XCTAssertTrue(sut.isDetecting)
}
```

**失敗時の実行時間**: 0.038秒

#### 11. testStopRealtimeDetection_WhenDetecting_SetsIsDetectingFalse() (55-67行目)

**テスト目的**: 検出中に`stopRealtimeDetection()`を呼び出すと`isDetecting`がfalseになり、状態がクリアされることを確認

**テストコード**:
```swift
func testStopRealtimeDetection_WhenDetecting_SetsIsDetectingFalse() throws {
    try sut.startRealtimeDetection()
    XCTAssertTrue(sut.isDetecting)

    sut.stopRealtimeDetection()

    XCTAssertFalse(sut.isDetecting)
    XCTAssertNil(sut.detectedPitch)
    XCTAssertNil(sut.spectrum)
}
```

**失敗時の実行時間**: 0.007秒

**共通の想定される問題**:
1. **@MainActor制約**: `RealtimePitchDetector`が`@MainActor`でマークされている可能性
2. **AVAudioEngine初期化失敗**: オーディオエンジンの初期化が失敗している
3. **実装メソッドの欠如**: `startRealtimeDetection()`/`stopRealtimeDetection()`が実装されていない
4. **状態管理の問題**: `isDetecting`プロパティの更新が正しく行われていない

**調査手順**:
1. ✅ 実装ファイル読み込み: `RealtimePitchDetector.swift` 読み込み完了
2. ✅ クラス定義確認:
   - `@MainActor`: **確認 - クラスが `@MainActor` でマークされている** (9行目)
   - `isDetecting` プロパティ: **実装済み** (12行目)
   - `startRealtimeDetection()`: **実装済み** (137-188行目)
   - `stopRealtimeDetection()`: **実装済み** (191-199行目)
3. ✅ AVAudioEngine関連の初期化: 正しく実装されている
4. ⏳ エラーメッセージの詳細確認: 次のフェーズで確認予定

**調査結果 (Phase 1 完了)**:
- **根本原因特定**: `@MainActor` 制約の違反
- **詳細**: `RealtimePitchDetector` クラスが `@MainActor` でマークされているため、テストから同期的に呼び出すことができない
- **Swift 6 concurrency**: 厳格な actor isolation チェックにより、この違反はコンパイルエラーまたは実行時エラーになる

**修正案 (確定)**:
- **推奨**: テストクラス全体を `@MainActor` でマーク
  ```swift
  @MainActor
  final class RealtimePitchDetectorTests: XCTestCase {
      // すべてのテストが自動的に MainActor コンテキストで実行される

      func testStartRealtimeDetection_WhenNotDetecting_SetsIsDetectingTrue() throws {
          try sut.startRealtimeDetection()
          XCTAssertTrue(sut.isDetecting)
      }

      func testStartRealtimeDetection_WhenAlreadyDetecting_DoesNothing() throws {
          try sut.startRealtimeDetection()
          XCTAssertTrue(sut.isDetecting)

          try sut.startRealtimeDetection()
          XCTAssertTrue(sut.isDetecting)
      }

      func testStopRealtimeDetection_WhenDetecting_SetsIsDetectingFalse() throws {
          try sut.startRealtimeDetection()
          XCTAssertTrue(sut.isDetecting)

          sut.stopRealtimeDetection()

          XCTAssertFalse(sut.isDetecting)
          XCTAssertNil(sut.detectedPitch)
          XCTAssertNil(sut.spectrum)
      }
  }
  ```

- **理由**:
  - テストクラス全体を `@MainActor` でマークすることで、すべてのテストが自動的に MainActor コンテキストで実行される
  - 個々のテストメソッドを変更する必要がない
  - `RealtimePitchDetector` の実装と一致する

---

## 調査優先順位

1. **最優先**: RealtimePitchDetectorTests (9-11番)
   - 理由: 3つのテストが連続して失敗しており、根本原因が共通の可能性が高い
   - 実装ファイル未確認のため、まず実装を読む

2. **次点**: AVAudioEngineScalePlayerTests (7番)
   - 理由: 実装は確認済み。非同期処理の設計変更が原因と特定済み
   - 修正方針も明確

3. **最後**: ScalePlaybackCoordinatorTests (8番)
   - 理由: #7と同様の非同期Taskの問題。修正パターンが類似

---

## 次のアクション

### Phase 1: RealtimePitchDetector調査 (9-11番)

```bash
# 1. 実装ファイル読み込み
Read /Users/kazuasato/Documents/dev/music/vocalis_studio/VocalisStudio/VocalisStudio/Infrastructure/Audio/RealtimePitchDetector.swift

# 2. エラーメッセージ詳細取得
grep -B 10 -A 30 "RealtimePitchDetectorTests.testStartRealtimeDetection_WhenNotDetecting" /tmp/all_tests.log

# 3. 個別テスト実行
cd /Users/kazuasato/Documents/dev/music/vocalis_studio/VocalisStudio
xcodebuild test \
  -project VocalisStudio.xcodeproj \
  -scheme VocalisStudio \
  -destination 'platform=iOS Simulator,name=iPhone 16 Clean' \
  -only-testing:VocalisStudioTests/RealtimePitchDetectorTests/testStartRealtimeDetection_WhenNotDetecting_SetsIsDetectingTrue \
  2>&1 | tee /tmp/realtime_detector_test.log
```

### Phase 2: AVAudioEngineScalePlayer修正 (7番)

```swift
// 修正内容: テストを実装の非同期動作に合わせる
func testPlay_CompletesSuccessfully() async throws {
    let notes = [try MIDINote(60)]
    let tempo = try Tempo(secondsPerNote: 0.1)

    try await sut.loadScale(notes, tempo: tempo)
    try await sut.play()

    XCTAssertTrue(sut.isPlaying)

    try await Task.sleep(nanoseconds: 200_000_000)

    XCTAssertFalse(sut.isPlaying)
    XCTAssertEqual(sut.progress, 1.0)
}
```

### Phase 3: ScalePlaybackCoordinator修正 (8番)

```swift
// 修正内容: Task実行を待つ
func testStartMutedPlayback_shouldLoadAndPlayScaleInMutedMode() async throws {
    let settings = ScaleSettings(...)

    try await sut.startMutedPlayback(settings: settings)
    try await Task.sleep(nanoseconds: 50_000_000)

    XCTAssertTrue(mockScalePlayer.loadScaleCalled)
    XCTAssertTrue(mockScalePlayer.playCalled)
    XCTAssertEqual(mockScalePlayer.playMuted, true)
}
```

---

## 備考

- すべてのテストは単体テスト（Unit Tests）であり、UIテストではない
- 実行時間が非常に短い（0.004-0.038秒）ため、初期化段階での失敗が疑われる
- AVAudioEngine関連のテストは非同期処理の設計変更が主な原因
- RealtimePitchDetectorTests は実装確認が必要

---

## 関連ファイル

- `/tmp/all_tests.log` - 全テスト実行ログ
- `VocalisStudioTests/Infrastructure/Audio/AVAudioEngineScalePlayerTests.swift`
- `VocalisStudioTests/Application/Services/ScalePlaybackCoordinatorTests.swift`
- `VocalisStudioTests/Infrastructure/Audio/RealtimePitchDetectorTests.swift`
- `VocalisStudio/Infrastructure/Audio/AVAudioEngineScalePlayer.swift`
- `VocalisStudio/Application/Services/ScalePlaybackCoordinator.swift`
- `VocalisStudio/Infrastructure/Audio/RealtimePitchDetector.swift` (未確認)
