# 引き継ぎ資料: スペクトログラム時間軸スクロール問題

作成日: 2025-11-13
最終更新: 2025-11-13 17:52

---

## 現在の状況

### 問題の本質
スペクトログラムの時間軸（横軸）ラベルの位置が**仕様と一致していない**。

### 仕様 vs 実際

**仕様書の要求** (`spectrogram_time_axis_specification.md`):
- 初期状態: 0sラベルが赤線（画面中央）の**真下**に配置される
- 赤線より左側に `playheadX` 分の**グレー余白**が表示される
- 再生中: 赤線の真下に常に `currentTime` のラベルが位置する
- 再生終了後: 0s位置に戻る

**実際の動作** (スクリーンショット検証結果):
- ❌ 0sラベルが赤線より**右側**に配置されている
- ❌ 赤線より左側はグレー余白ではなく、何も表示されていない空白
- ❌ 再生中、赤線が時間ラベルの**間**に位置する（0sと1sの間など）
- ❌ 再生終了後も0sラベルが赤線の右側にあり、初期位置に正しく戻っていない

### 検証に使用したスクリーンショット

```
/tmp/time_axis_screenshots/391CC198-6867-4FBC-99C8-CCDCE55C2989.png  # 再生開始前
/tmp/time_axis_screenshots/E22C4820-70A0-4A33-B6EA-BA63D1864A66.png  # 再生中（~1秒）
/tmp/time_axis_screenshots/36D94839-A539-4063-8896-0BD648E8069E.png  # 再生終了後
```

**検証方法**:
```bash
# UIテスト実行
./VocalisStudio/scripts/test-runner.sh ui AnalysisUITests/testPlayback_TimeAxisScroll

# スクリーンショット抽出
xcrun xcresulttool export attachments \
  --path "最新の.xcresult" \
  --output-path /tmp/time_axis_screenshots
```

---

## これまでの修正履歴

### 修正1: `alignment: .topLeading` の追加（不十分）

**日時**: 2025-11-13 17:30頃

**ファイル**: `VocalisStudio/Presentation/Views/AnalysisView.swift:612`

**変更内容**:
```swift
// 修正前:
.frame(width: spectroViewportW, height: timeLabelHeight)
.clipped()

// 修正後:
.frame(width: spectroViewportW, height: timeLabelHeight, alignment: .topLeading)
.clipped()
```

**意図**:
Canvas に `.offset()` を適用した後の `.frame()` で `alignment` パラメータを指定することで、オフセットされたコンテンツが正しい位置（左上基準）に配置されるようにする。

**効果**:
- Y軸方向の配置は改善された可能性あり
- **X軸方向の問題は未解決**（0sラベルが依然として赤線の右側）

**教訓**:
- スクリーンショットを注意深く観察せず、「正しい」と誤判断してしまった
- 仕様書の全項目と実際の表示を照合する重要性を再認識

---

## 問題の原因（推定）

### 可能性1: Canvas サイズとオフセットの不整合

**現在の実装** (`AnalysisView.swift:605-613`):
```swift
Canvas { context, size in
    if spectrogramData != nil {
        drawSpectrogramTimeAxis(context: context, size: size, durationSec: durationSec)
    }
}
.frame(width: canvasWidth, height: timeLabelHeight)  // Canvas全体のサイズ
.offset(x: -paperLeft, y: 0)                         // オフセット適用
.frame(width: spectroViewportW, height: timeLabelHeight, alignment: .topLeading)  // クリップ領域
.clipped()
```

**問題点**:
- 最初の `.frame(width: canvasWidth)` で Canvas 全体のサイズを設定
- `.offset(x: -paperLeft)` でオフセット適用
- 2つ目の `.frame(width: spectroViewportW, alignment: .topLeading)` でクリップ領域を設定

この3段階の構造で `alignment: .topLeading` が X軸方向に正しく機能しているか疑問。

**検証方法**:
```swift
// デバッグログを追加
.frame(width: canvasWidth, height: timeLabelHeight)
.background(Color.yellow.opacity(0.3))  // Canvas全体を可視化
.offset(x: -paperLeft, y: 0)
.background(Color.blue.opacity(0.3))    // オフセット後を可視化
.frame(width: spectroViewportW, height: timeLabelHeight, alignment: .topLeading)
.background(Color.red.opacity(0.3))     // クリップ領域を可視化
.clipped()
```

**代替案**:
```swift
Canvas { context, size in
    // size は spectroViewportW × timeLabelHeight
    // 描画時に paperLeft を考慮した座標変換を行う
    let offsetX = -paperLeft
    var time: Double = 0
    while time <= durationSec {
        let x = CGFloat(time) * pixelsPerSecond + offsetX
        // x が 0 <= x <= size.width の範囲のみ描画
        if x >= 0 && x <= size.width {
            // ラベル描画
        }
        time += 1.0
    }
}
.frame(width: spectroViewportW, height: timeLabelHeight)
```

### 可能性2: paperLeft の初期値計算エラー

**仕様書の定義** (`spectrogram_time_axis_specification.md:66-73`):
```swift
paperLeft(0) = min(0 * pps - playheadX, canvasW - playheadX)
            = min(-playheadX, canvasW - playheadX)
            = -playheadX  // 通常は左側の値（負の値）
```

**確認ポイント**:
- `paperLeft` の初期値が `-playheadX` になっているか
- `playheadX = spectroViewportW / 2` の計算は正しいか
- 再生中の `paperLeft` 更新式が仕様通りか

**検証方法**:
```swift
// AnalysisView.swift の適切な場所に追加
os_log(.debug, log: OSLog(subsystem: "com.kazuasato.VocalisStudio", category: "time_axis"),
       "📍 paperLeft=%{public}f, playheadX=%{public}f, currentTime=%{public}f, pps=%{public}f",
       paperLeft, playheadX, currentTime, pixelsPerSecond)

FileLogger.shared.log(level: "DEBUG", category: "time_axis",
    message: "paperLeft=\(paperLeft), playheadX=\(playheadX), currentTime=\(currentTime)")
```

**期待値**:
- 初期状態（`currentTime = 0`）: `paperLeft = -playheadX`（例: `-300px`）
- 3秒再生時: `paperLeft = 3 * 50 - 300 = -150px`

### 可能性3: drawSpectrogramTimeAxis の描画基準点

**仕様書の描画方法** (`spectrogram_time_axis_specification.md:269-291`):
```swift
Canvas { context, size in
    let labelInterval: Double = 1.0  // 1秒間隔
    var time: Double = 0

    // 0秒 〜 durationSecまでのラベルを生成
    while time <= durationSec {
        let x = CGFloat(time) * pixelsPerSecond
        let y = size.height / 2  // Y方向は固定（中央）

        let text = Text(String(format: "%.0fs", time))
            .font(.caption)
            .foregroundColor(.gray)

        // 左端からの描画（cutoff防止）
        context.draw(text, at: CGPoint(x: x, y: y), anchor: .leading)

        time += labelInterval
    }
}
```

**確認ポイント**:
- `x = CGFloat(time) * pixelsPerSecond` の計算は正しいか
- `anchor: .leading` が設定されているか（`.center` だと位置がずれる）
- `size` は `canvasWidth` か `spectroViewportW` か

**実装の確認先**:
`drawSpectrogramTimeAxis()` 関数の実装を確認する必要あり（AnalysisView.swift 内）

---

## 次のステップ（調査・修正項目）

### 1. paperLeft の値を確認【優先度: 高】

**目的**: 仕様通りの値になっているか検証

**手順**:
1. ログ出力コードを追加（上記「可能性2」参照）
2. アプリを実行し、分析画面を開く
3. 初期状態の `paperLeft` を確認（期待: `-playheadX`）
4. 再生ボタンを押して、再生中の `paperLeft` を確認
5. ログファイルを確認: `~/Library/Developer/CoreSimulator/Devices/[UUID]/data/Containers/Data/Application/[UUID]/Documents/logs/`

**成功条件**:
- 初期状態: `paperLeft ≈ -playheadX`（例: `-300px`）
- 再生中（3秒）: `paperLeft ≈ currentTime * 50 - playheadX`（例: `-150px`）

### 2. drawSpectrogramTimeAxis の実装確認【優先度: 高】

**目的**: 時間ラベル描画のロジックが仕様通りか検証

**確認ポイント**:
```swift
// AnalysisView.swift 内の drawSpectrogramTimeAxis() を探す
func drawSpectrogramTimeAxis(context: GraphicsContext, size: CGSize, durationSec: Double) {
    // 確認1: x座標計算
    let x = CGFloat(time) * pixelsPerSecond
    // ✅ 正しい: time * pps
    // ❌ 誤り: time * pps - paperLeft（オフセットは外で適用済み）

    // 確認2: anchor設定
    context.draw(text, at: CGPoint(x: x, y: y), anchor: .leading)
    // ✅ 正しい: .leading
    // ❌ 誤り: .center または anchor指定なし

    // 確認3: 描画範囲
    while time <= durationSec { ... }
    // ✅ 正しい: durationSec まで
    // ❌ 誤り: 固定値や durationSec を超える範囲
}
```

**手順**:
1. `drawSpectrogramTimeAxis()` 関数の実装を Read ツールで確認
2. 上記3つの確認ポイントをチェック
3. 問題があれば修正

### 3. Canvas + offset + frame 構造の見直し【優先度: 中】

**目的**: 3段階フレーム設定が正しく機能するか検証

**検証方法A: 背景色で可視化**
```swift
Canvas { ... }
.frame(width: canvasWidth, height: timeLabelHeight)
.background(Color.yellow.opacity(0.3))  // Canvas全体
.offset(x: -paperLeft, y: 0)
.background(Color.blue.opacity(0.3))    // オフセット後
.frame(width: spectroViewportW, height: timeLabelHeight, alignment: .topLeading)
.background(Color.red.opacity(0.3))     // クリップ領域
.clipped()
```

スクリーンショットを撮り、各レイヤーの配置を確認。

**検証方法B: 代替実装でテスト**
```swift
Canvas { context, size in
    // size は spectroViewportW
    // paperLeft を考慮した描画
    var time: Double = 0
    while time <= durationSec {
        let x = CGFloat(time) * pixelsPerSecond - paperLeft
        if x >= 0 && x <= size.width {
            let text = Text(String(format: "%.0fs", time))
                .font(.caption)
                .foregroundColor(.gray)
            context.draw(text, at: CGPoint(x: x, y: size.height / 2), anchor: .leading)
        }
        time += 1.0
    }
}
.frame(width: spectroViewportW, height: timeLabelHeight)
.clipped()
```

この代替実装で正しく表示されるか確認。

### 4. UIテストの改善【優先度: 低】

**目的**: 定量的な検証を追加

**現在のテスト**:
- スクリーンショット撮影のみ
- 目視確認に依存

**改善案**:
```swift
@MainActor
func testPlayback_TimeAxisScroll() throws {
    let app = launchAppWithResetRecordingCount()
    navigateToAnalysisScreen(app)
    Thread.sleep(forTimeInterval: 3.0)

    // スペクトログラム領域とPlayPauseボタンを取得
    let spectrogramCanvas = app.otherElements["SpectrogramCanvas"]
    let playPauseButton = app.buttons["AnalysisPlayPauseButton"]

    XCTAssertTrue(spectrogramCanvas.exists, "Spectrogram canvas should exist")

    // 座標取得（XCUITestでは制限あり、将来の改善案）
    // let frame = spectrogramCanvas.frame
    // let centerX = frame.midX

    // スクリーンショット撮影（既存）
    let screenshot1 = app.screenshot()
    // ...

    // 定量的チェック（将来実装）
    // XCTAssertEqual(timeLabelX, playheadX, accuracy: 2.0, "0s label should be at playhead")
}
```

---

## 関連ファイル

### 仕様書
- `VocalisStudio/claudedocs/spectrogram_time_axis_specification.md` - 完全な仕様定義（430行）
  - paperLeft の計算式、初期状態、再生中の挙動、受け入れ基準を含む

### 実装ファイル
- `VocalisStudio/VocalisStudio/Presentation/Views/AnalysisView.swift`
  - **605-613行目**: 時間軸 Canvas 描画部分（現在の修正箇所）
  - `drawSpectrogramTimeAxis()` 関数: 時間ラベル描画ロジック（場所要確認）
  - `paperLeft` の計算・更新ロジック（場所要確認）

### テストファイル
- `VocalisStudio/VocalisStudioUITests/AnalysisUITests.swift`
  - **378-425行目**: `testPlayback_TimeAxisScroll()` メソッド
  - 再生開始前、再生中、再生終了後のスクリーンショット撮影

### ドキュメント
- `VocalisStudio/claudedocs/UITEST_SCREENSHOT_EXTRACTION.md` - スクリーンショット抽出方法
  - Xcode 16 以降: `xcrun xcresulttool export attachments` コマンド使用

### スクリーンショット
- `/tmp/time_axis_screenshots/*.png` - 現在の検証結果
  - 問題を示すエビデンスとして保存済み

---

## 重要な教訓

### 検証の重要性

1. **スクリーンショットを注意深く観察する**
   - ❌ 誤った判断: 「0sラベルが赤線の真下にある」（実際は右側にあった）
   - ✅ 正しい方法: 赤線と0sラベルの相対位置を**ピクセル単位**で確認
   - ツール: 画像編集ソフトで座標測定、または背景色で位置確認

2. **仕様書の全項目と照合する**
   - ❌ 誤った判断: 一部の項目だけ確認して「正しい」と結論
   - ✅ 正しい方法: 受け入れ基準（チェックリスト）を1つずつ確認
   - 仕様書330-358行目: 受け入れ基準（6項目）

3. **ユーザーからの疑問提起を真剣に受け止める**
   - ユーザー: "このスクリーンショットを見て正しいと判断したのであれば..."
   - この指摘により、改めて注意深く確認し、問題を発見できた

### 修正前の確認事項

1. **現在の実装コード全体を読む**
   - 断片的な理解は危険
   - Canvas 描画、オフセット適用、クリップ処理の全体フローを把握

2. **仕様書の数式と実装の計算式を照合**
   - `paperLeft = currentTime * pps - playheadX`
   - `paperLeft <= canvasW - playheadX`（上限）
   - 負の値を許容する設計

3. **実際の値（ログ出力）で検証**
   - 推測ではなく、実際のランタイム値を確認
   - OSLog または FileLogger で出力

4. **視覚的検証だけでなく、定量的検証も行う**
   - スクリーンショットだけでは不十分
   - 座標値、距離、タイミングを数値で確認

---

## デバッグ手順（推奨フロー）

### Phase 1: 情報収集（30分）

```bash
# 1. 実装の確認
# AnalysisView.swift を読み、以下を確認:
# - paperLeft の初期化箇所
# - paperLeft の更新箇所（再生中）
# - drawSpectrogramTimeAxis() の実装
# - Canvas + offset + frame の構造

# 2. ログ出力の追加
# paperLeft, playheadX, currentTime の値をログ出力

# 3. アプリ実行とログ取得
./VocalisStudio/scripts/test-runner.sh ui AnalysisUITests/testPlayback_TimeAxisScroll
# または手動実行

# 4. ログファイル確認
# ~/Library/Developer/CoreSimulator/Devices/[UUID]/data/Containers/Data/Application/[UUID]/Documents/logs/
```

### Phase 2: 原因特定（30分）

```swift
// paperLeft の値を確認
// 期待値と実際の値を比較

// 初期状態（currentTime = 0）:
// 期待: paperLeft = -playheadX = -(spectroViewportW / 2)
// 実際: [ログから確認]

// 再生中（currentTime = 3）:
// 期待: paperLeft = 3 * 50 - playheadX
// 実際: [ログから確認]

// drawSpectrogramTimeAxis() の確認
// - x座標計算は正しいか
// - anchor は .leading か
// - 描画範囲は 0 <= time <= durationSec か
```

### Phase 3: 修正実装（1時間）

```swift
// 原因に応じて修正:

// パターンA: paperLeft の計算が誤っている場合
// → 仕様書の式を正確に実装

// パターンB: drawSpectrogramTimeAxis() の描画基準が誤っている場合
// → anchor を .leading に修正、x座標計算を修正

// パターンC: Canvas + offset + frame の構造が誤っている場合
// → 代替実装を試す（Canvas内で paperLeft を考慮）
```

### Phase 4: 検証（30分）

```bash
# 1. UIテスト実行
./VocalisStudio/scripts/test-runner.sh ui AnalysisUITests/testPlayback_TimeAxisScroll

# 2. スクリーンショット抽出と確認
xcrun xcresulttool export attachments \
  --path "[最新の.xcresult]" \
  --output-path /tmp/time_axis_fixed

# 3. 受け入れ基準チェック（仕様書330-358行目）
# ✅ 0sラベルが画面中央の赤線真下に表示
# ✅ 赤線より左側にグレー余白が存在
# ✅ 再生中、赤線の真下に常に currentTime のラベルが位置
# ✅ 再生終了後、0s位置に戻る
```

---

## まとめ

### 現状
- `alignment: .topLeading` を追加したが、X軸方向の問題は未解決
- 0sラベルが赤線の右側に配置されている
- 仕様要求: 0sラベルは赤線の真下

### 原因候補
1. Canvas + offset + frame の構造問題（可能性: 高）
2. paperLeft の計算エラー（可能性: 中）
3. drawSpectrogramTimeAxis の描画基準点エラー（可能性: 中）

### 次のアクション
1. paperLeft の値をログ出力で確認（優先度: 高）
2. drawSpectrogramTimeAxis の実装を確認（優先度: 高）
3. Canvas + offset + frame 構造を検証・代替実装（優先度: 中）
4. UIテストを定量的検証に改善（優先度: 低）

### 推奨デバッグフロー
Phase 1: 情報収集（30分） → Phase 2: 原因特定（30分） → Phase 3: 修正実装（1時間） → Phase 4: 検証（30分）

**総所要時間見積もり: 2.5-3時間**

---

## 参考情報

### 仕様書の重要セクション

- **69-79行目**: 初期状態の定義と視覚的状態
- **100-145行目**: 再生中の挙動（t = 3秒の例）
- **266-292行目**: 時間ラベルの描画方法
- **330-358行目**: 受け入れ基準（チェックリスト）

### SwiftUI Canvas + offset + frame の挙動

参考資料: [SwiftUI Frame and Offset Behavior](https://developer.apple.com/documentation/swiftui/view/offset(x:y:))

- `.offset()` はビュー全体を移動
- 2つ目の `.frame(alignment:)` は、オフセット後のコンテンツを指定されたアライメントで配置
- `alignment: .topLeading` は左上基準だが、X軸方向で期待通り動作するか要検証

### FileLogger の使用方法

```swift
FileLogger.shared.log(level: "DEBUG", category: "time_axis",
    message: "paperLeft=\(paperLeft), playheadX=\(playheadX)")
```

ログファイル場所:
```
~/Library/Developer/CoreSimulator/Devices/[UDID]/data/Containers/Data/Application/[App UUID]/Documents/logs/vocalis_[timestamp].log
```

UDID 確認:
```bash
xcrun simctl list devices | grep "iPhone 16"
```

---

## 連絡先・質問

この資料に関する質問や追加情報が必要な場合は、以下を参照:
- 仕様書: `VocalisStudio/claudedocs/spectrogram_time_axis_specification.md`
- 実装: `VocalisStudio/VocalisStudio/Presentation/Views/AnalysisView.swift`
- テスト: `VocalisStudio/VocalisStudioUITests/AnalysisUITests.swift`
