# スペクトログラム - ビューポートアーキテクチャ実装プラン（修正版 v2）

## 作成日時
2025-11-12（修正版）

## 仕様の明確化

### ⚠️ 重要な訂正

**従来の誤った理解**:
- ❌ Y軸ラベルを画面固定位置にオーバーレイとして配置
- ❌ ラベルとキャンバスを別レイヤーで管理
- ❌ スクロール時にラベルのテキストを動的に更新

**正しい仕様**:
- ✅ Y軸ラベルはキャンバスの一部として描画
- ✅ ラベルとスペクトルは同一座標系
- ✅ ラベルもスペクトルも一緒に上下スクロール
- ✅ ビューポートは切り取るだけ（描画なし）

## 正しいアーキテクチャ設計

### Layer 構造（2層）

```
┌─────────────────────────────────────────────┐
│ Layer 1: ビューポート（表示窓）              │
│  - 役割: .clipped()で切り取るだけ            │
│  - 描画: なし（透明な窓）                    │
│  - 位置: 画面固定                            │
│                                             │
│  ┌───────────────────────────────────┐     │
│  │ [表示可能領域]                     │     │
│  │                                   │     │
│  │  ┏━━━━━━━━━━━━━━━━━━━━┓       │     │
│  │  ┃ 3000Hz ──────────── ┃ ←─┐   │     │
│  │  ┃ 2500Hz ──────────── ┃   │   │     │
│  │  ┃ 2000Hz ──────────── ┃   │   │     │
│  │  ┗━━━━━━━━━━━━━━━━━━━━┛   │   │     │
│  │      ↑ キャンバスの可視部分    │   │     │
│  └──────┼─────────────────────┘   │     │
│         │                            │     │
└─────────┼────────────────────────────┘
          │
          ↓ ビューポート外は非表示
          │
    Layer 2: キャンバス（Y軸ラベル + スペクトログラム）
          │
    ┌─────┴────────────────────────────────┐
    │ キャンバス全体（縦長・スクロール可能）  │
    │                                      │
    │ 4000Hz ─────┬─────────────────────  │
    │        ラベル│スペクトログラム        │
    │ 3500Hz ─────┼─────────────────────  │
    │             │                        │
    │ 3000Hz ─────┼─────────────────────  │
    │        ラベル│スペクトログラム        │
    │ 2500Hz ─────┼─────────────────────  │
    │             │                        │
    │ 2000Hz ─────┼─────────────────────  │
    │        ラベル│スペクトログラム        │
    │ 1500Hz ─────┼─────────────────────  │
    │        ラベル│スペクトログラム        │
    │ 1000Hz ─────┼─────────────────────  │
    │        ラベル│スペクトログラム        │
    │  500Hz ─────┼─────────────────────  │
    │             │                        │
    │    0Hz ─────┴─────────────────────  │
    │        ラベル スペクトログラム        │
    │                                      │
    │ ← .offset(y: -frequencyOffsetY)     │
    │ ← ラベルもスペクトルも一緒に移動      │
    └──────────────────────────────────────┘

    キャンバス高さ = maxFrequency * hzToPixelRatio
    例: 4000Hz * 0.5pt/Hz = 2000pt
```

### 構造の詳細説明

#### Layer 1: ビューポート（窓）
- **役割**: 下のキャンバスを切り取って表示する透明な窓
- **実装**: GeometryReader + .clipped()
- **描画**: 一切なし
- **位置**: 画面に固定（動かない）
- **高さ**: 画面の表示領域に応じた固定サイズ

#### Layer 2: キャンバス（Y軸ラベル + スペクトログラム）
- **役割**: Y軸ラベルとスペクトログラムを含む1枚の巨大なキャンバス
- **実装**: Canvas内でラベルとスペクトルを同一座標系で描画
- **描画内容**:
  - **Y軸ラベル**: キャンバスの左端（X = 0〜40pt）に周波数位置に対応して描画
  - **スペクトログラム**: キャンバスの右側（X = 40pt〜）に周波数位置に対応して描画
- **位置**: .offset(y: -frequencyOffsetY)で上下に移動
- **高さ**: 周波数範囲に基づく動的サイズ（例: 4000Hz * 0.5pt/Hz = 2000pt）
- **座標系**: 統一座標系（Y = 0 が maxFrequency、Y = canvasHeight が 0Hz）

## 実装の詳細設計

### 1. 座標変換関数（必須・単一実装）

すべての周波数↔Y座標変換はこの関数を使用:

```swift
/// Hz → Canvas Y 座標
/// - Parameters:
///   - hz: 周波数（Hz）
///   - canvasHeight: キャンバス全体の高さ
///   - maxFreq: 最大周波数（Hz）
/// - Returns: Y座標（0 = 最上部 = maxFreq、canvasHeight = 最下部 = 0Hz）
private func frequencyToCanvasY(_ hz: Double, canvasHeight: CGFloat, maxFreq: Double) -> CGFloat {
    let ratio = hz / maxFreq
    return canvasHeight * (1.0 - CGFloat(ratio))
}

/// Canvas Y 座標 → Hz
private func canvasYToFrequency(_ y: CGFloat, canvasHeight: CGFloat, maxFreq: Double) -> Double {
    let ratio = 1.0 - (y / canvasHeight)
    return maxFreq * Double(ratio)
}

/// キャンバス全体の高さを計算
private func calculateTotalCanvasHeight(data: SpectrogramData) -> CGFloat {
    let maxFrequency = Double(data.frequencyBins.max() ?? 4000.0)
    let hzToPixelRatio: CGFloat = isExpanded ? 0.5 : 0.3
    return CGFloat(maxFrequency) * hzToPixelRatio
}
```

**重要**: この関数を以下の全ての箇所で使用:
- Y軸ラベルの位置計算
- スペクトログラムセルの位置計算
- デバッグ検証コード

### 2. Y軸ラベルの描画（Canvas内）

```swift
/// Y軸ラベルを描画（キャンバスの左端）
private func drawFrequencyLabels(context: GraphicsContext, canvasHeight: CGFloat, maxFreq: Double) {
    // ラベルを配置する周波数のリスト
    let labelFrequencies: [Double] = isExpanded
        ? [0, 500, 1000, 1500, 2000, 2500, 3000, 3500, 4000]  // 拡張表示
        : [0, 500, 1000, 1500, 2000]                          // 通常表示

    for frequency in labelFrequencies {
        // 周波数→Y座標変換（座標変換関数を使用）
        let y = frequencyToCanvasY(frequency, canvasHeight: canvasHeight, maxFreq: maxFreq)

        // ラベルテキスト描画
        let text = Text("\(Int(frequency))Hz")
            .font(.caption2)
            .foregroundColor(.white)

        // 背景付きで描画（X = 左端から5pt）
        let textSize = text.sizeThatFits(.init(width: 40, height: 20))
        let backgroundRect = CGRect(
            x: 5,
            y: y - textSize.height / 2,
            width: textSize.width + 8,
            height: textSize.height + 4
        )

        context.fill(
            Path(roundedRect: backgroundRect, cornerRadius: 4),
            with: .color(.black.opacity(0.5))
        )

        context.draw(
            text,
            at: CGPoint(x: 5 + textSize.width / 2 + 4, y: y)
        )
    }
}
```

**重要**:
- ラベルは固定値（周波数）を表示
- 座標変換関数で位置を計算
- スペクトルと同じCanvas内に描画

### 3. スペクトログラムの描画（Canvas内）

```swift
private func drawSpectrogram(context: GraphicsContext, size: CGSize, data: SpectrogramData, canvasHeight: CGFloat) {
    let pixelsPerSecond: CGFloat = isExpanded ? 30 : 50
    let timeWindow = Double(size.width / pixelsPerSecond)
    let centerX = size.width / 2
    let maxMagnitude = data.magnitudes.flatMap { $0 }.max() ?? 1.0
    let maxFrequency = Double(data.frequencyBins.max() ?? 4000.0)

    let freqBinCount = data.frequencyBins.count
    let cellHeight = canvasHeight / CGFloat(freqBinCount)

    // ラベル用のX軸オフセット（ラベルが左端40ptを占有）
    let labelWidth: CGFloat = 50

    for (timeIndex, timestamp) in data.timeStamps.enumerated() {
        let timeOffset = timestamp - currentTime
        guard abs(timeOffset) <= timeWindow / 2 else { continue }

        let x = centerX + CGFloat(timeOffset) * pixelsPerSecond
        let cellWidth = pixelsPerSecond * 0.1

        guard timeIndex < data.magnitudes.count else { continue }
        let magnitudeFrame = data.magnitudes[timeIndex]

        for (freqIndex, magnitude) in magnitudeFrame.enumerated() {
            let normalizedMagnitude = CGFloat(magnitude / maxMagnitude)
            let hue = 0.6 - normalizedMagnitude * 0.6
            let color = Color(hue: hue, saturation: 0.8, brightness: 0.9 * normalizedMagnitude + 0.1)

            let binFrequency = data.frequencyBins[freqIndex]

            // 座標変換関数を使用（ラベルと同じ関数）
            let y = frequencyToCanvasY(Double(binFrequency), canvasHeight: canvasHeight, maxFreq: maxFrequency)

            let rect = CGRect(
                x: x + labelWidth,  // ラベルの右側に描画
                y: y,
                width: cellWidth,
                height: cellHeight
            )
            context.fill(Path(rect), with: .color(color))
        }
    }
}
```

**重要**:
- スペクトルはラベルの右側（X = 50pt〜）に描画
- ラベルと同じ座標変換関数を使用
- ラベルとスペクトルは同一座標系

### 4. ビューポートとスクロールの実装

```swift
var body: some View {
    VStack(alignment: .leading, spacing: 6) {
        Text("analysis.spectrogram_title".localized)
            .font(.subheadline)
            .fontWeight(.semibold)
            .accessibilityIdentifier("SpectrogramTitle")

        GeometryReader { geometry in
            // Layer 1: ビューポート（窓）
            ZStack {
                // Layer 2: キャンバス（ラベル + スペクトル）
                Canvas { context, size in
                    if let data = spectrogramData, !data.timeStamps.isEmpty {
                        let totalCanvasHeight = calculateTotalCanvasHeight(data: data)
                        let maxFrequency = Double(data.frequencyBins.max() ?? 4000.0)

                        // Y軸ラベルを描画（キャンバスの左端）
                        drawFrequencyLabels(
                            context: context,
                            canvasHeight: totalCanvasHeight,
                            maxFreq: maxFrequency
                        )

                        // スペクトログラムを描画（ラベルの右側）
                        drawSpectrogram(
                            context: context,
                            size: size,
                            data: data,
                            canvasHeight: totalCanvasHeight
                        )

                        // 再生位置ライン
                        drawPlaybackPosition(context: context, size: size)

                        // 時間軸
                        drawSpectrogramTimeAxis(context: context, size: size)
                    } else {
                        drawPlaceholder(context: context, size: size)
                    }
                }
                // キャンバス全体をオフセット（ラベルもスペクトルも一緒に動く）
                .offset(y: -frequencyOffsetY)
            }
            // ビューポート外をクリッピング
            .clipped()
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let translation = value.translation
                        let angle = atan2(abs(translation.height), abs(translation.width))

                        if angle > .pi / 4 {
                            frequencyOffsetY = lastDragValueY + translation.height
                        }
                    }
                    .onEnded { _ in
                        lastDragValueY = frequencyOffsetY

                        if let data = spectrogramData {
                            let totalCanvasHeight = calculateTotalCanvasHeight(data: data)
                            let viewportHeight = geometry.size.height
                            let maxScrollRange = totalCanvasHeight - viewportHeight

                            // スクロール範囲を制限
                            frequencyOffsetY = max(0, min(frequencyOffsetY, maxScrollRange))
                            lastDragValueY = frequencyOffsetY
                        }
                    }
            )
        }
        .background(Color.black.opacity(0.1))
        .cornerRadius(8)
    }
}
```

### 5. スクロール動作の詳細

**オフセットの符号規則**:
- `frequencyOffsetY = 0`: キャンバス上端（高周波）がビューポート上端に表示
- `frequencyOffsetY = maxScrollRange`: キャンバス下端（低周波）がビューポート下端に表示

**スクロール動作**:
- **上にスワイプ**: `frequencyOffsetY` が増加 → キャンバスが上に移動 → 低周波が見える
- **下にスワイプ**: `frequencyOffsetY` が減少 → キャンバスが下に移動 → 高周波が見える

**重要**: ラベルもスペクトルも一緒に動く（同一キャンバス）

## 実装の検証項目

### 必須チェック項目

1. **座標変換の一貫性**
   ```swift
   #if DEBUG
   let testHz = 1500.0
   let canvasY = frequencyToCanvasY(testHz, canvasHeight: totalCanvasHeight, maxFreq: maxFrequency)
   let reconstructedHz = canvasYToFrequency(canvasY, canvasHeight: totalCanvasHeight, maxFreq: maxFrequency)
   assert(abs(reconstructedHz - testHz) < 0.01, "座標変換エラー")
   #endif
   ```

2. **ラベルとスペクトルの位置一致**
   - 同じ周波数のラベルとスペクトルが同じY座標に描画されること
   - 目視確認: 1000Hzラベルと1000Hzのスペクトル成分が水平に並ぶこと

3. **スクロール動作**
   - 上スワイプ → 低周波が表示される
   - 下スワイプ → 高周波が表示される
   - ラベルもスペクトルも一緒に動く

4. **クリッピング動作**
   - ビューポート外のラベルが見えないこと
   - ビューポート外のスペクトルが見えないこと

## 実装禁止事項

- ❌ View固定位置に `0Hz / 1500Hz / 3000Hz` などをオーバーレイ
- ❌ スクロール時にラベルのテキストを動的に更新
- ❌ ラベルとキャンバスを別レイヤー座標で扱う
- ❌ .overlay()でラベルを追加
- ❌ ラベルとスペクトルで異なる座標変換関数を使用

## 実装ステップ

### Phase 1: 座標変換関数の実装
1. `frequencyToCanvasY()` 関数を実装
2. `canvasYToFrequency()` 関数を実装
3. `calculateTotalCanvasHeight()` 関数を実装

### Phase 2: Y軸ラベルの描画
1. `drawFrequencyLabels()` 関数を実装
2. Canvas内でラベルを描画
3. 座標変換関数を使用して位置を計算

### Phase 3: スペクトログラムの描画修正
1. ラベル用のX軸オフセット（labelWidth）を追加
2. 座標変換関数を使用してY位置を計算
3. ラベルの右側に描画

### Phase 4: ビューポートとスクロールの実装
1. Canvasに.offset()を適用
2. .clipped()でクリッピング
3. スクロール範囲の制限を実装

### Phase 5: テストと検証
1. UIテストで動作確認
2. 座標変換の一貫性をチェック
3. ラベルとスペクトルの位置一致を確認

## 参考資料

- ユーザー指摘: "ラベルは最上位の固定オーバーレイではない"
- ユーザー指摘: "Y軸ラベルはキャンバスと一緒に上下に動く"
- ユーザー指摘: "ラベル = キャンバスの一部"
- ユーザー指摘: "ビューポートは描画せず切り取るだけ"
