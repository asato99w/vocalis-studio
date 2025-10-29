# SwiftUI Button タップ問題調査レポート

**問題**: 特定のButton要素に対してXCUITestの`.tap()`が`action`クロージャーを起動しない

**影響範囲**: `RecordingControls.swift`内の「最後の録音を再生」ボタン

**調査日**: 2025-10-29

**重要**: これはSwiftUI ButtonとXCUITestの一般的な互換性問題ではなく、特定の実装における環境/階層/モディファイアの問題である可能性が高い。

---

## 問題の詳細

### 症状

`RecordingControls`内の特定のButton要素に対して`.tap()`を実行しても、`action`クロージャーが呼び出されない。

```swift
// SwiftUI View
Button(action: {
    print("[DIAG] Button tapped")  // ← このログが出力されない
    onPlayLast()
}) {
    Text("Play")
}
.accessibilityIdentifier("PlayLastRecordingButton")

// UITest
let playButton = app.buttons["PlayLastRecordingButton"]
XCTAssertTrue(playButton.exists)  // ✅ ボタンは存在する
playButton.tap()  // ← タップは実行されるが、actionが呼ばれない
```

### 検証方法

1. **スクリーンショット比較**
   - タップ前後のスクリーンショットを取得
   - 結果: 完全に同一（UIの状態変化なし）

2. **診断ログ**
   - `action`クロージャー内に`print()`と`Logger.debug()`を追加
   - 結果: ログが一切出力されない（actionが呼ばれていない証拠）

3. **アクセシビリティ要素**
   - `XCTAssertTrue(playButton.exists)` → ✅ Pass
   - `XCTAssertTrue(playButton.isHittable)` → ✅ Pass
   - ボタン要素自体は正しく認識されている

---

## 試行した解決策と結果

### 試行1: `.buttonStyle(PlainButtonStyle())` の追加

**仮説**: SwiftUIのデフォルトButtonStyleがXCUITestと互換性がない

**実装**:
```swift
Button(action: { onPlayLast() }) {
    Text("Play")
}
.buttonStyle(PlainButtonStyle())  // ← 追加
.accessibilityIdentifier("PlayLastRecordingButton")
```

**結果**: ❌ **効果なし**
- テストは完走するがactionは依然として呼ばれない
- スクリーンショットもタップ前後で同一

### 試行2: 並列テスト無効化

**仮説**: 並列テスト実行がシミュレータの不安定性を引き起こしている

**実装**:
```bash
xcodebuild test \
  -parallel-testing-enabled NO \
  -destination 'id=<SIMULATOR_UUID>'
```

**結果**: ✅/❌ **部分的成功**
- ✅ シミュレータクラッシュを解決
- ✅ テストが完走（22秒）
- ❌ ボタンタップ問題は未解決

### 試行3: 3ステップ診断テスト (2025-10-29実施)

**目的**: 問題の範囲と原因を特定する

**Step 1: 最小限のButtonスモークテスト**
```swift
// RecordingView.swift portrait layout内に追加
Button("TEST") {
    print("[DIAG] MINIMAL BUTTON TAPPED")
}
.accessibilityIdentifier("MinimalButton")
```

**結果**: ❌ **失敗**
- XCUITestは正常にButtonを認識してタップ実行
- しかし`action`クロージャーが呼ばれない
- `[DIAG] MINIMAL BUTTON TAPPED`ログが一切出力されない
- **重要**: RecordingControls固有の問題ではなく、ScrollView内の**すべてのButton**が影響を受けている

**Step 2: Button状態の詳細確認**
```swift
print("Button exists: \(playButton.exists)")
print("Button isEnabled: \(playButton.isEnabled)")
print("Button isHittable: \(playButton.isHittable)")
print("Button frame: \(playButton.frame)")
```

**結果**: ✅ **すべて正常**
- `exists`: true
- `isEnabled`: true
- `isHittable`: true
- `frame`: (16.0, 574.3, 361.0, 34.3) - 画面内の正常な位置
- Button要素の状態に異常なし

**Step 3: 座標ベースタップテスト**
```swift
let coordinate = playButton.coordinate(
    withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)
)
coordinate.tap()
```

**結果**: ❌ **失敗**
- 座標タップも`action`クロージャーを起動しない
- アクセシビリティAPI経由でも座標経由でも同じ結果
- タップイベント自体が配信されていない

**根本原因の特定**:
`RecordingView.swift`の Portrait Layout (lines 110-171)を分析した結果、**`ScrollView`内にButtonが配置されていることが原因**と判明。ScrollViewがタップイベントを奪っている。

### 試行4: ScrollView問題の解決策 (推奨)

**根本原因**: `RecordingView.swift`のPortrait LayoutでScrollView内にButtonが配置されている

**解決策A: `.scrollTo()`でButtonを確実に可視化**
```swift
// UITest側
let playButton = app.buttons["PlayLastRecordingButton"]
app.swipeUp() // ScrollViewを一番下までスクロール
playButton.tap()
```

**解決策B: ScrollViewから除外してButtonを固定配置**
```swift
// RecordingView.swift
VStack {
    ScrollView {
        VStack {
            // 設定パネルとディスプレイエリア
        }
    }

    // ScrollView外に配置
    RecordingControls(...)
        .padding()
}
```

**解決策C: UITestでScrollViewを直接操作**
```swift
// UITest側
// ScrollView内の要素を確実に表示
let scrollView = app.scrollViews.firstMatch
scrollView.swipeUp()
Thread.sleep(forTimeInterval: 0.5)

let playButton = app.buttons["PlayLastRecordingButton"]
playButton.tap()
```

**推奨**: 解決策Bが最も根本的。RecordingControlsは常に画面下部に固定表示されるべきUIコンポーネントなので、ScrollView外に配置するのが適切。

---

## 技術的分析

### 問題の性質

**重要な前提**: 多くの環境ではSwiftUI ButtonとXCUITestの`.tap()`は正常に動作する。今回の問題は特定の実装における以下のいずれかと考えられる:

1. **環境/階層/モディファイアがイベント配信を奪っている**
2. **要素の参照先が微妙にズレている**

### 確認された事実

#### ✅ 正常に機能している要素
- Button要素の検出 (`exists` = true)
- アクセシビリティ識別子の認識
- Button要素へのヒットテスト (`isHittable` = true)
- スクリーンショット取得

#### ❌ 機能していない要素
- タップイベントのaction closureへの配信
- UIの状態変更（ボタンのビジュアル状態、ViewModelの状態など）

### 一般的な原因候補

以下は、SwiftUI ButtonのXCUITestタップイベントが届かない典型的な原因:

1. **透明なオーバーレイがタップを奪っている**
   - `ZStack`で上にある`Color.clear`や`.overlay(...)`
   - 親Viewの`.contentShape(Rectangle())`

2. **親ViewにonTapGestureがある**
   - `onTapGesture`や`.highPriorityGesture`がButtonの上位階層に存在
   - ジェスチャーの優先度でButtonのタップが奪われる

3. **accessibilityIdentifierが別の要素についている**
   - `accessibilityIdentifier`が間違った階層に設定
   - 実際のButtonではなく親Viewや子Viewに設定されている

4. **Buttonが無効化されている**
   - `.disabled(true)`状態でタップ時に無効化されている
   - 条件によって動的に無効化されている

5. **ScrollView内で可視範囲外**
   - Buttonが技術的には存在するが、ScrollView外で視覚的に隠れている
   - `.scrollTo()`で確実に表示する必要がある

6. **カスタムbuttonStyleの問題**
   - カスタムButtonStyleの実装が`makeBody`内でタップイベントを消費
   - `.contentShape(...)`の誤用

7. **マイクロフォン権限ダイアログ**
   - 録音開始時の権限ダイアログがButtonを覆っている
   - ダイアログのハンドリングが必要

8. **action内でMainActorブロック**
   - `action`クロージャー内の処理がメインスレッドをブロック
   - タップ完了前に画面遷移やモーダル表示

---

## 環境情報

### 開発環境
- **Xcode**: 15.0+
- **macOS**: Sonoma 14.0+
- **iOS Simulator**: 18.5
- **Swift**: 5.9+
- **SwiftUI**: iOS 15.0+

### テスト設定
- **並列テスト**: NO (無効化して安定性向上)
- **シミュレータ指定**: UUID指定 (`id=508462B0-4692-4B9B-88F9-73A63F9B91F5`)
- **テスト対象**: iPhone 16 シミュレータ

---

## 今後の調査方向

### 1. 3つの基本診断テスト（推奨アプローチ）

問題を切り分けるため、以下の順序で診断を実施:

#### Step 1: 最小限のButtonでスモークテスト
```swift
// RecordingView内に診断用の最小Buttonを一時的に追加
Button("TEST") { print("MINIMAL BUTTON TAPPED") }
    .accessibilityIdentifier("MinimalButton")

// UITestで検証
let minimal = app.buttons["MinimalButton"]
minimal.tap()
// → これが動けば環境は正常、RecordingControls固有の問題
```

**目的**: 環境全体の問題か、特定のButton実装の問題かを切り分け

#### Step 2: Button状態の詳細確認
```swift
// UITest側で詳細な状態を確認
let playButton = app.buttons["PlayLastRecordingButton"]

XCTAssertTrue(playButton.exists, "Button exists")
XCTAssertTrue(playButton.isEnabled, "Button is enabled")  // ← 重要
XCTAssertTrue(playButton.isHittable, "Button is hittable")

// フレーム情報も確認
print("Button frame: \(playButton.frame)")
print("Button value: \(playButton.value ?? "nil")")
```

**目的**: `isEnabled = false`の可能性を排除

#### Step 3: 座標ベースタップで回避可能かテスト
```swift
// UITest側
let playButton = app.buttons["PlayLastRecordingButton"]
let coordinate = playButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
coordinate.tap()
```

**目的**: アクセシビリティAPIの問題か、座標タップでも同じかを確認

### 2. 追加で必要な情報

以下の情報があれば、問題を精密に特定可能:

1. **RecordingControlsの全体レイアウト**
   - ZStack/overlay/gestureまわりのコード
   - Buttonを含むView階層全体

2. **Buttonに適用されているmodifierの完全なリスト**
   - 適用順序も含めて（順序が重要）
   - `.accessibilityIdentifier()`の位置

3. **Host Application設定**
   - UITestターゲット → Host Applicationがアプリに設定されているか確認
   - `General > Host Application`

4. **isEnabledの実測値**
   - テスト側で`XCTAssertTrue(playButton.isEnabled)`が本当にtrueか
   - 動的に無効化されていないか確認

### 3. よくある解決パターン

#### パターンA: 透明オーバーレイの除去
```swift
// 問題のあるコード
VStack {
    RecordingControls(...)
}
.overlay(Color.clear)  // ← これがタップを奪う

// 修正
VStack {
    RecordingControls(...)
}
// overlayを削除
```

#### パターンB: ジェスチャー優先度の調整
```swift
// 問題のあるコード
VStack {
    RecordingControls(...)
}
.onTapGesture { /* 親のジェスチャー */ }

// 修正
VStack {
    RecordingControls(...)
        .allowsHitTesting(true)  // 子のタップを優先
}
```

#### パターンC: accessibilityIdentifierの位置修正
```swift
// 問題のあるコード
Button(action: { onPlayLast() }) {
    HStack {
        Image(...)
        Text(...)
    }
    .accessibilityIdentifier("PlayButton")  // ← HStackについている
}

// 修正
Button(action: { onPlayLast() }) {
    HStack {
        Image(...)
        Text(...)
    }
}
.accessibilityIdentifier("PlayButton")  // ← Buttonについている
```

---

## 参考リソース

### 診断用スクリーンショット
- Before tap: `/tmp/diagnostic_screenshots_direct/40B7BAAC-CD56-4AE1-AACE-A2BADCC4B043.png`
- After tap: `/tmp/diagnostic_screenshots_direct/A2645774-14F3-47E2-8116-9D24DB1BC1C2.png`

### テストログ
- xcresult: `/Users/asatokazu/Library/Developer/Xcode/DerivedData/VocalisStudio-bcumrnabpksyjubqudqvtqtaohue/Logs/Test/Test-VocalisStudio-2025.10.29_10-49-17-+0900.xcresult`

### 関連ファイル
- `VocalisStudio/Presentation/Views/Recording/RecordingControls.swift` (Button実装)
- `VocalisStudioUITests/VocalisStudioUITests.swift:175-230` (診断テスト)

---

## 2025-10-29 最終調査結果: 根本原因の特定

### ⚠️ 重要な結論

**この問題はSwiftUI ButtonのXCUITestタップ問題ではなかった。**

実際の根本原因は、`RecordingViewModel.playLastRecording()`メソッドの**実装バグ（メソッド呼び出し漏れ）**でした。

### 調査手法: OSLogアーカイブによる詳細追跡

従来の調査では、XcodeのコンソールやFileLoggerのログだけでは詳細な実行フローを追えませんでした。今回、以下の手法でシミュレータの完全なログを取得することで、真の原因を特定しました:

```bash
# テスト実行の開始/終了時刻を記録
START=$(date -u +"%Y-%m-%d %H:%M:%S")
xcodebuild test ... 2>&1 | tee /tmp/xc_output.txt
END=$(date -u +"%Y-%m-%d %H:%M:%S")

# テスト終了後にログアーカイブを収集
xcrun simctl spawn "$UDID" log collect --output /tmp/sim.logarchive --last 10m

# アーカイブから時間範囲とサブシステムでフィルタして抽出
/usr/bin/log show --archive /tmp/sim.logarchive \
  --style syslog --info --debug \
  --start "$START" --end "$END" \
  --predicate 'subsystem == "com.kazuasato.VocalisStudio"' \
  2>&1 | tee /tmp/detailed_logs.log
```

### 完全な実行タイムライン（OSLogから再構築）

```
17:23:24.570 - 🔵 UI_TEST_MARK: PlayLastRecordingButton tapped
17:23:33.721 - 🔵 RecordingViewModel.playLastRecording() called
17:23:33.722 - 🔵 lastRecordingURL: Optional(file://.../recording_20251029_172330_372.m4a)
17:23:33.734 - 🔵 lastRecordingSettings: Optional(ScaleSettings(...))
17:23:33.734 - 🔵 Both URL and settings exist, starting pitch monitoring
17:23:33.739 - Audio session activated
17:23:41.263 - processAudioBuffer called 100 times
17:23:41.361 - detectPitchFromSamples: RMS 0.0000 (無音検出)

❌ Missing Logs (期待されたが出力されなかったログ):
- "Starting playback: recording_xxx.m4a" (RecordingStateViewModel:239)
- "Audio player prepared" (AudioPlayer実装)
- "Scale playback started during recording playback" (ScalePlaybackCoordinator)
```

### 根本原因の特定

`RecordingViewModel.playLastRecording()` (lines 210-231) を読むと:

```swift
public func playLastRecording() async {
    Logger.viewModel.debug("🔵 playLastRecording() called")
    Logger.viewModel.debug("🔵 lastRecordingURL: \(String(describing: self.lastRecordingURL))")
    Logger.viewModel.debug("🔵 lastRecordingSettings: \(String(describing: self.lastRecordingSettings))")

    if let url = lastRecordingURL, let settings = lastRecordingSettings {
        Logger.viewModel.debug("🔵 Both URL and settings exist, starting pitch monitoring")
        do {
            // ✅ ピッチ検出の準備は正常に実行された
            try await pitchDetectionVM.startTargetPitchMonitoring(settings: settings)
            Logger.viewModel.debug("🔵 Target pitch monitoring started successfully")
            try await pitchDetectionVM.startPlaybackPitchDetection(url: url)
            Logger.viewModel.debug("🔵 Playback pitch detection started successfully")
        } catch {
            Logger.viewModel.error("🔵 Error in pitch detection setup: \(error.localizedDescription)")
            Logger.viewModel.logError(error)
        }
    }

    // ❌ BUG: 実際の音声再生を呼んでいない!
    // await recordingStateVM.playLastRecording() が抜けている!
}
```

**問題点**:
1. ピッチ検出は正常に開始される（ログで確認済み）
2. しかし**肝心の音声再生メソッド `await recordingStateVM.playLastRecording()` を呼んでいない**
3. 結果: ピッチ検出は無音に対して動作し、実際には何も再生されない

### 正しい実装（RecordingStateViewModel内）

`RecordingStateViewModel.playLastRecording()` (lines 225-260) には正しいロジックが実装されている:

```swift
public func playLastRecording() async {
    Logger.viewModel.debug("🔵 playLastRecording() called in RecordingStateViewModel")

    guard let url = lastRecordingURL else {
        Logger.viewModel.warning("Play recording failed: no recording available")
        errorMessage = "No recording available"
        return
    }

    guard !isPlayingRecording else {
        Logger.viewModel.warning("⚠️ playLastRecording() blocked: isPlayingRecording = true")
        return
    }

    Logger.viewModel.info("Starting playback: \(url.lastPathComponent)")  // ← このログが出力されなかった

    do {
        isPlayingRecording = true

        // スケール設定があればミュート再生を開始
        if let settings = lastRecordingSettings {
            try await scalePlaybackCoordinator.startMutedPlayback(settings: settings)
        }

        // 実際の音声ファイルを再生（ブロッキング）
        try await audioPlayer.play(url: url)

        isPlayingRecording = false
        Logger.viewModel.info("Playback completed")

    } catch {
        Logger.viewModel.logError(error)
        errorMessage = error.localizedDescription
        isPlayingRecording = false
    }
}
```

このメソッドは**一度も呼ばれていない**（ログに "Starting playback" が存在しない）

### 結論

**これはSwiftUI ButtonのXCUITestタップ問題ではありませんでした。**

証拠:
- ✅ XCUITestのButtonタップは正常に動作（17:23:24.570のログで確認）
- ✅ `RecordingViewModel.playLastRecording()`は正常に呼ばれた（17:23:33.721のログで確認）
- ✅ ピッチ検出の準備も正常に完了（17:23:33.734のログで確認）
- ❌ 実際の音声再生メソッドが呼ばれなかった（ViewModelのバグ）

### 修正方法

`RecordingViewModel.playLastRecording()`の最後に1行追加:

```swift
public func playLastRecording() async {
    // ... 既存のピッチ検出準備コード ...

    // ✅ FIX: 実際の音声再生を呼ぶ
    await recordingStateVM.playLastRecording()
}
```

### 学んだこと

1. **OSLogアーカイブは強力な診断ツール**
   - Xcodeコンソールよりも詳細な情報が取得できる
   - 時間範囲とサブシステムでフィルタ可能
   - UITestの実行フローを完全に再現できる

2. **症状だけでは本質を見誤る**
   - 「Buttonが動作しない」→ 実際は「Buttonは動作するがメソッド呼び出しが不完全」
   - スクリーンショットの比較だけでは実行フローは分からない
   - ログによる時系列の再構築が不可欠

3. **診断ログの配置が重要**
   - `action`クロージャー内のログだけでなく、呼び出される側のメソッドにもログが必要
   - 「呼ばれた」と「実行された」は別物
   - 期待されるログが「存在しない」ことが最大のヒント

---

## まとめ

### 現状認識（更新）

当初はXCUITestの`.tap()`メソッドがSwiftUI `Button`の`action`クロージャーに到達しない問題と思われました。しかし、OSLogアーカイブによる詳細な調査の結果、**XCUITestは正常に動作しており、問題はViewModelの実装バグ（メソッド呼び出し漏れ）**であることが判明しました。

SwiftUI ButtonとXCUITestの互換性問題を疑う前に、まずOSLogアーカイブで完全な実行フローを確認することが重要です。

### 推奨アプローチ（更新）

1. **短期**: `RecordingViewModel.playLastRecording()`に`await recordingStateVM.playLastRecording()`を追加
2. **中期**: 同様のバグを防ぐため、メソッド呼び出しチェーンのテストを追加
3. **長期**: OSLogアーカイブを使った診断手法をドキュメント化し、今後の調査に活用
