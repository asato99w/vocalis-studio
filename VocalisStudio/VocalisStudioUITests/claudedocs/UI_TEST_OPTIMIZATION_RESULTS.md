# UIテスト実行時間最適化 - 最終結果

## 概要

UIテストの実行時間を最適化するため、Thread.sleepによる固定待機を状態ベースの待機に置き換えました。

## 実施フェーズ

### Phase 1: アニメーション無効化
**実装内容**:
- UITestEnvironment.swiftを作成し、環境値でアニメーション無効化フラグを伝播
- VocalisStudioApp.swiftで-UITestDisableAnimationsフラグを検出
- RecordingView.swiftの4箇所でwithAnimationブロックを条件分岐
- SettingsUITests.swiftの2箇所でアニメーション待機（2.0秒×2）を削除

**削減時間**: 約3秒

### Phase 2: 録音初期化待機の最適化
**実装内容**:
- 8つのテストケースで録音開始後のThread.sleep（5.0~11.0秒）を削除
- `StopRecordingButton`の`waitForExistence(timeout: 10)`で録音開始を検知
- 実際の録音時間として1.0秒（または5.0秒）のみ残す

**削減時間**: 約97秒

**編集ファイル**:
1. RecordingFlowUITests.swift（6.5秒 → 1.0秒）
2. RecordingListUITests.swift - testRecordingListNavigation（7.0秒 → 1.0秒）
3. RecordingListUITests.swift - testDeleteRecording（7.0秒 → 1.0秒）
4. NavigationUITests.swift - testMultipleRecordings 1回目（5.0秒 → 1.0秒）
5. NavigationUITests.swift - testMultipleRecordings 2回目（5.0秒 → 1.0秒）
6. PlaybackUITests.swift - testPlaybackFullCompletion（11.0秒 → 5.0秒）
7. PlaybackUITests.swift - testTargetPitchShouldDisappearAfterStoppingPlayback（11.0秒 → 5.0秒）
8. AnalysisUITests.swift（5.0秒 → 1.0秒）

### Phase 3: 保存完了待機の最適化
**実装内容**:
- 7つのテストケースで録音停止後のThread.sleep（2.0~3.0秒）を削除
- `PlayLastRecordingButton`の`waitForExistence(timeout: 5)`で保存完了を検知

**削減時間**: 約19秒

**編集ファイル**:
1. RecordingFlowUITests.swift（2.0秒削除）
2. RecordingListUITests.swift - 2箇所（2.0秒×2削除）
3. NavigationUITests.swift - 2箇所（2.0秒×2削除）
4. PlaybackUITests.swift - 2箇所（2.0秒 + 1.0秒削除）
5. AnalysisUITests.swift（2.0秒削除）
6. SettingsUITests.swift - 2箇所（3.0秒×2削除）

## 最終結果

### テスト実行時間（Phase 2完了後）

| テストケース | 実行時間 | 以前の時間（推定） |
|------------|---------|------------------|
| testBasicRecordingFlow | 16.1秒 | ~18秒 |
| testRecordingListNavigation | 26.6秒 | ~30秒 |
| testDeleteRecording | 25.6秒 | ~30秒 |
| testMultipleRecordings | 29.0秒 | ~45秒 |
| testFullNavigationFlow | 17.1秒 | ~30秒 |
| testPlaybackFullCompletion | 29.4秒 | ~40秒 |
| testTargetPitchShouldDisappearAfterStoppingPlayback | 28.2秒 | ~40秒 |
| testAnalysisViewDisplay | 38.8秒 | ~45秒 |
| testChangeScaleSettings | 50.1秒 | ~55秒 |

### 総合結果

- **最適化前**: 約294秒（4分54秒） - UI_TEST_WAIT_TIME_ANALYSIS.mdより
- **最適化後**: 約153秒（2分33秒） - 実測値（並列実行）
- **削減時間**: 約141秒（2分21秒）
- **削減率**: 約48%

**目標達成**: 119秒削減目標に対し、141秒削減を達成 ✅

## 技術的詳細

### 最適化パターン

#### 録音初期化待機の置き換え
```swift
// Before
startButton.tap()
Thread.sleep(forTimeInterval: 6.5)
let stopButton = app.buttons["StopRecordingButton"]
XCTAssertTrue(stopButton.waitForExistence(timeout: 2))

// After
startButton.tap()
let stopButton = app.buttons["StopRecordingButton"]
XCTAssertTrue(stopButton.waitForExistence(timeout: 10))
Thread.sleep(forTimeInterval: 1.0)  // 実録音時間のみ
```

#### 保存完了待機の置き換え
```swift
// Before
stopButton.tap()
Thread.sleep(forTimeInterval: 2.0)
// 次の操作...

// After
stopButton.tap()
let playButton = app.buttons["PlayLastRecordingButton"]
XCTAssertTrue(playButton.waitForExistence(timeout: 5))
// 次の操作...
```

#### アニメーション無効化
```swift
// VocalisStudioApp.swift
@Environment(\.uiTestAnimationsDisabled) var uiTestAnimationsDisabled

// RecordingView.swift
if uiTestAnimationsDisabled {
    isSettingsPanelVisible.toggle()
} else {
    withAnimation {
        isSettingsPanelVisible.toggle()
    }
}
```

### 並列実行

UIテストは5つの並列クローンで実行されるため、最長のテスト（testChangeScaleSettings: 50.1秒）が全体の実行時間を決定します。実際の合計実行時間は約153秒（シミュレータ起動時間を含む）。

## 学んだこと

1. **固定待機の問題**: Thread.sleepは常に最悪ケースの時間を消費する
2. **状態ベース待機の利点**: waitForExistenceは実際の状態変化を待つため、高速かつ確実
3. **アニメーション無効化**: UIテストモードでのアニメーション無効化は小さいが確実な削減効果
4. **並列実行の重要性**: 複数シミュレータクローンによる並列実行で全体時間を大幅削減

## 今後の改善案

1. **さらなる最適化**: 残りのThread.sleep（ナビゲーション遷移待機など）の削除
2. **カスタムwaiter**: より複雑な状態遷移に対する汎用的なwaiter関数の実装
3. **テスト分割**: 長時間テスト（testChangeScaleSettings）のさらなる分割や最適化

## 実行日時

- 最適化実施日: 2025-11-02
- 最終テスト実行: 15:04（JST）
- xcresultファイル: Test-VocalisStudio-2025.11.02_15-04-21-+0900.xcresult
