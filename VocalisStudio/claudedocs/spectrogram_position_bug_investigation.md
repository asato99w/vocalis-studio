# スペクトログラム位置ずれ問題 調査報告

**作成日**: 2025-11-13
**ステータス**: 調査中（根本原因未特定）

## 問題の概要

### 症状
- スペクトログラムの濃い青色部分が、0s位置（赤いカーソー下）ではなく、約1s付近（右側）に表示される
- 0s位置（赤いカーソー直下）には何も描画されていない（薄いグレーの背景のみ）

### 期待動作
- スペクトログラムがCanvas X=0（0s位置）から描画される
- Canvas X=0が赤いカーソー（ビューポート中央）直下に表示される
- 初期状態で`paperLeft = -144.5`により、Canvas全体が右に144.5pxオフセットされ、Canvas X=0がビューポート中央（赤いカーソー位置）に配置される

### 再現手順
1. 録音を実行（約1秒程度）
2. 録音一覧から録音を選択し、分析画面に遷移
3. スペクトログラム表示を確認
4. UIテスト: `VocalisStudioUITests/AnalysisUITests/testPlayback_TimeAxisScroll`

## 調査結果

### ✅ 正しく動作している部分

#### 1. データ生成（AudioFileAnalyzer）
- `AudioFileAnalyzer.swift` line 240: `let timestamp = Double(position) / sampleRate`
- 最初のtimestamp = 0.0で開始
- ログ確認済み: `First timestamp: 0.0`

#### 2. 描画座標計算（drawSpectrogramOnCanvas）
- `AnalysisView.swift` line 904: `let x = CGFloat(timestamp - firstTimestamp) * pixelsPerSecond`
- `firstTimestamp = data.timeStamps.first ?? 0.0` (line 844)
- frame[0]: timestamp=0.000, x=0.0
- ログ確認済み:
  ```
  🖍️ Drawing frame[0]: timestamp=0.000, x=0.0
    magnitude=7.7797, maxMag=42.3723
  ```

#### 3. 時間軸のスクロール
- 時間軸ラベル（0s, 1s, 2s）は正しくスクロールする
- `paperLeft`の初期化: `-144.5`（line 619）
- `drawSpectrogramTimeAxisWithOffset`で正しく描画される

### ❌ 問題が発生している部分

#### 1. スペクトログラム本体の位置
- **視覚的確認**: Canvas X=0に緑色マーカーを追加した結果、マーカーが右端（約1s位置）に表示
- **ずれの大きさ**: 約95〜105px（推定）
- **Canvas構造**:
  ```swift
  Canvas { context, size in
      drawSpectrogramOnCanvas(...) // X=0から描画
      // DEBUG: Draw green marker at Canvas X=0
      context.stroke(Path { path in
          path.move(to: CGPoint(x: 0, y: 0))
          path.addLine(to: CGPoint(x: 0, y: size.height))
      }, with: .color(.green), lineWidth: 3)
  }
  .frame(width: canvasWidth, height: canvasHeight)
  .offset(x: -paperLeft, y: -paperTop)  // line 566
  .frame(width: spectroViewportW, height: viewportHeight)
  .clipped()
  ```

## 可能性のある原因

### 仮説1: canvasWidthの計算誤り
- **計算式** (line 500): `let canvasWidth: CGFloat = CGFloat(durationSec) * pixelsPerSecond`
- **durationSec計算** (line 489-494):
  ```swift
  let minT = ts.min() ?? 0
  let maxT = ts.max() ?? 0
  return max(0, maxT - minT)
  ```
- **問題の可能性**: timestampが0.0から始まっていても、`durationSec`が実際のデータ範囲と異なる？
- **検証方法**: `canvasWidth`の実際の値をログ出力（既存の`viewport_debug`ログで確認可能）

### 仮説2: drawSpectrogramOnCanvasの引数誤り
- **呼び出し** (line 547-553):
  ```swift
  drawSpectrogramOnCanvas(
      context: context,
      canvasWidth: dataWidth,  // dataWidth = durationSec * pixelsPerSecond
      canvasHeight: canvasHeight,
      maxFreq: maxFreq,
      data: data
  )
  ```
- **問題の可能性**: `dataWidth`と実際の`Canvas.frame(width:)`の値が異なる？
- **検証方法**: `drawSpectrogramOnCanvas`内で`canvasWidth`パラメータの値をログ出力

### 仮説3: Canvasのsize.widthが期待と異なる
- **Canvas内部** (line 541): `Canvas { context, size in ...}`
- **frame指定** (line 565): `.frame(width: canvasWidth, height: canvasHeight)`
- **問題の可能性**: SwiftUIの`Canvas`内で取得される`size`が、`.frame()`指定と異なる？
- **検証方法**: Canvas内で`size.width`と`canvasWidth`を比較ログ出力

### 仮説4: offsetの適用順序またはタイミング
- **offset指定** (line 566): `.offset(x: -paperLeft, y: -paperTop)`
- **初期値**: `paperLeft = -144.5` → `offset(x: 144.5)`
- **問題の可能性**: `.offset()`が期待通りに適用されていない？ZStack内の座標系の問題？
- **検証方法**: 異なるoffset値でテストし、視覚的な移動量を確認

## 調査で使用したデバッグコード

### 1. 描画座標のログ出力
`AnalysisView.swift` line 906-910:
```swift
if binIndex == 0 && timeIndex < 5 {
    FileLogger.shared.log(level: "DEBUG", category: "spectrogram_draw",
        message: "🖍️ Drawing frame[\(timeIndex)]: timestamp=\(String(format: "%.3f", timestamp)), x=\(String(format: "%.1f", x))")
}
```

### 2. magnitude分布のログ出力
`AnalysisView.swift` line 846-857:
```swift
let magnitudesByTime = data.timeStamps.enumerated().map { (index, timestamp) -> String in
    let avgMag = data.magnitudes[index].reduce(0.0, +) / Float(data.magnitudes[index].count)
    let x = CGFloat(timestamp - firstTimestamp) * pixelsPerSecond
    return String(format: "t=%.2f(x=%.1f):mag=%.2f", timestamp, x, avgMag)
}.joined(separator: ", ")

FileLogger.shared.log(level: "DEBUG", category: "spectrogram_debug",
    message: "🎨 SPECTROGRAM: frames=\(data.timeStamps.count), ...")
FileLogger.shared.log(level: "DEBUG", category: "spectrogram_magnitude",
    message: "📊 MAGNITUDE_DATA: \(magnitudesByTime)")
```

**注意**: magnitude分布ログは実際には出力されていない（原因不明）

### 3. Canvas X=0の視覚的マーカー
`AnalysisView.swift` line 562-570:
```swift
// DEBUG: Draw green marker at Canvas X=0
context.stroke(
    Path { path in
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: size.height))
    },
    with: .color(.green),
    lineWidth: 3
)
```

**結果**: 緑色の線が右端（約1s位置）に表示され、Canvas X=0が期待位置にないことを確認

## ログ取得の問題

### 症状
- 最新のコード変更（`spectrogram_magnitude`ログなど）が反映されたログが記録されていない
- UIテスト実行後のログが古いまま（19:54の実行ログが残り続けている）

### 推測される原因
1. UIテストが別のアプリコンテナインスタンスを起動している
2. コードがビルドに反映されていない
3. FileLoggerの書き込み先が異なる

### 確認済みログファイル
- `/Users/kazuasato/Library/Developer/CoreSimulator/Devices/7E44408D-C4F7-43FE-B3AE-C111CA557A00/data/Containers/Data/Application/C1DC74A1-7189-4967-8ACA-625911D58B51/Documents/logs/vocalis_2025-11-13T10:53:54.log`
- 最終更新: 19:54（その後のテスト実行のログが記録されていない）

## 次の調査ステップ

### 優先度高

1. **既存ログの詳細確認**
   - `viewport_debug`ログから実際の値を確認:
     - `paperLeft` の初期値と変化
     - `spectroViewportW` の値
     - `canvasWidth` の値
   - これらの値から理論的なCanvas X=0の表示位置を計算

2. **Canvas内部のsize確認**
   ```swift
   Canvas { context, size in
       FileLogger.shared.log(level: "DEBUG", category: "canvas_size",
           message: "Canvas size: \(size.width)x\(size.height), expected canvasWidth: \(canvasWidth)")
       // ... 既存の描画コード
   }
   ```

3. **複数マーカーの追加**
   - X=0, X=50, X=100に異なる色のマーカーを追加
   - ビューポートの境界線を表示
   - これにより、実際のCanvas座標系とビューポート座標系の関係を可視化

### 優先度中

4. **時間軸とスペクトログラムの描画比較**
   - `drawSpectrogramTimeAxisWithOffset`と`drawSpectrogramOnCanvas`で同じoffset値を使用しているか確認
   - 時間軸は正しく表示されているので、その実装を参考にする

5. **dataWidthとcanvasWidthの関係調査**
   - line 544: `let dataWidth = CGFloat(durationSec) * pixelsPerSecond`
   - line 500: `let canvasWidth: CGFloat = CGFloat(durationSec) * pixelsPerSecond`
   - この2つは同じ値のはずだが、実際に同じか確認

6. **ZStack座標系の検証**
   - ZStackのalignment: `.topLeading`が正しく機能しているか
   - Canvas内の座標(0,0)がZStackの左上に対応しているか

### 優先度低

7. **AudioFileAnalyzerのデータ生成検証**
   - スペクトログラムのtimestamp生成ロジックを再確認
   - サンプリング間隔とposition計算の詳細検証

8. **SwiftUI Canvasのドキュメント調査**
   - `.frame()`, `.offset()`, `.clipped()`の適用順序と座標系への影響
   - Canvas内のGraphicsContextの座標原点

## 関連ファイル

### 主要ファイル
- `VocalisStudio/Presentation/Views/AnalysisView.swift`
  - Canvas構造とスクロール実装の中心
  - 重要な行:
    - line 489-494: durationSec計算
    - line 500: canvasWidth計算
    - line 505: playheadX計算
    - line 541-574: スペクトログラムCanvas定義
    - line 565-568: .frame() と .offset()
    - line 612-625: paperLeft初期化（.task(id:)内）
    - line 832-1010: drawSpectrogramOnCanvas関数
    - line 844: firstTimestamp定義
    - line 904: X座標計算

### 関連ファイル
- `VocalisStudio/Infrastructure/Analysis/AudioFileAnalyzer.swift`
  - line 226-280: analyzeSpectrogram関数
  - line 240: timestamp計算

- `claudedocs/spectrogram_time_axis_specification.md`
  - 受入基準とログ検証式の定義
  - line 365-433: ログ検証式

- `claudedocs/log_capture_guide_v2.md`
  - ログ取得方法のガイド

## 既知の制約

1. **時間軸は正しく動作している**
   - `drawSpectrogramTimeAxisWithOffset`は正しく描画される
   - 0sラベルが赤いカーソー下に表示される
   - スクロールも正しく追従する

2. **magnitude値は妥当**
   - frame[0]のmagnitude=7.7797（正規化後≈0.184）
   - 可視的な色で描画されるべき値

3. **offset初期値は正しい**
   - paperLeft = -144.5
   - offset(x: 144.5) → Canvas X=0がビューポート中央に来るはず

## 緊急度と影響範囲

### 緊急度: 高
- 時間軸スクロール実装の完成を阻害
- UIテストが視覚的に不完全

### 影響範囲
- スペクトログラム表示のみ（ピッチ分析グラフは影響なし）
- 時間軸ラベルは正常動作

### 回避策
- なし（根本的な修正が必要）

## 参考情報

### スクリーンショット
- `/tmp/time_axis_debug/F00EE3DF-A29D-43CF-9B11-0A3ABEE82D21.png`
  - 緑色マーカー（Canvas X=0）が右端に表示されているスクリーンショット

### テスト結果
- xcresult: `/Users/kazuasato/Library/Developer/Xcode/DerivedData/VocalisStudio-frcxxiswixbmnpedzxgbxeyluinf/Logs/Test/Test-VocalisStudio-UIOnly-2025.11.13_20-11-51-+0900.xcresult`

### ログファイル
- `/Users/kazuasato/Library/Developer/CoreSimulator/Devices/7E44408D-C4F7-43FE-B3AE-C111CA557A00/data/Containers/Data/Application/C1DC74A1-7189-4967-8ACA-625911D58B51/Documents/logs/vocalis_2025-11-13T10:53:54.log`

---

**調査担当者へのメモ**:
- 地道な調査が必要です。焦らず、一つずつ仮説を検証してください
- ログ出力を充実させることが最優先です
- 視覚的デバッグ（マーカー追加）が最も効果的です
- 時間軸の実装は正しいので、それとの比較が有効です
