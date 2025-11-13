# スペクトログラム - 固定ラベル+ビューポートアーキテクチャ実装プラン

## 作成日時
2025-11-12

## 背景

### ユーザーからの要求
ユーザーは現在の「動的に更新される周波数ラベル」の実装を否定し、以下のような「窓越しに大きなグラフを見る」アーキテクチャを要求:

1. **固定された周波数ラベル** - スクロールしても数値は変わらない（例: 常に 0Hz, 1500Hz, 3000Hz）
2. **3層構造**:
   - Layer 1 (最下層): 周波数全体（0〜最大Hz）を描画した大きなキャンバス
   - Layer 2 (中間層): 表示範囲を制限する「窓」ビューポート
   - Layer 3 (最上層): 固定された周波数目盛り
3. **スクロール動作**: ラベルは固定、下の大きなキャンバスがスクロールする

### ユーザーのメタファー
> 「横に流れる大きなグラフを窓越しにのぞいているイメージです。伝わりますか?」
> 「０から大きなスペクトルの全体を下位レイヤーに表示して、それを除き窓越しに見ているようなイメージで」

### 対象範囲
まずはスペクトログラムのみ実装。ピッチグラフは後回し。

## 現在の実装（AnalysisView.swift:442-620）

### 現在の問題点

1. **動的ラベル（Line 507-560）**
   ```swift
   let displayMaxFreq = baseMaxFreq - frequencyScrollOffset
   let displayMinFreq = baseMinFreq - frequencyScrollOffset
   Text("\(Int(displayMaxFreq))Hz")  // スクロールで数値が変わる
   ```

2. **Y座標のオフセット適用（Line 608）**
   ```swift
   y: size.height - CGFloat(freqIndex + 1) * cellHeight + frequencyOffsetY
   ```
   - セルの描画位置にオフセットを直接追加
   - ビューポートという概念がない

3. **周波数範囲の制限**
   - 現在: `isExpanded` で 200-2000Hz または 100-3000Hz に制限
   - 要求: 0Hz から最大Hz まで全体を描画

## 新しいアーキテクチャ設計

### Layer 構造

```
┌─────────────────────────────────────┐
│ Layer 3: 固定ラベル (Overlay)       │  ← 常に 0Hz, 1500Hz, 3000Hz を表示
│  [3000Hz]                           │
│                                     │
│  [1500Hz]                           │
│                                     │
│  [0Hz]                              │
└─────────────────────────────────────┘
          ↓ 重なり合い
┌─────────────────────────────────────┐
│ Layer 2: ビューポート窓 (.clipped()) │
│ ┌─────────────────────────────────┐ │
│ │ 表示可能領域（クリッピング）      │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
          ↓ マスクで制限
┌─────────────────────────────────────┐
│ Layer 1: 大きなキャンバス (Canvas)   │
│                                     │
│ ← スクロールで上下に移動            │
│                                     │
│ 周波数範囲: 0Hz 〜 maxFrequency     │
│ (例: 0〜4000Hz)                     │
│                                     │
│ 高さ: 実際の周波数範囲に応じた       │
│      巨大なキャンバス                │
└─────────────────────────────────────┘
```

### 実装の詳細設計

#### 1. 固定周波数ラベル（Layer 3）

**実装箇所**: `SpectrogramView` の Overlay として追加

```swift
// 固定ラベル - スクロールに関係なく常に同じ値を表示
.overlay(alignment: .leading) {
    VStack(spacing: 0) {
        // 上部ラベル (例: 3000Hz)
        HStack {
            Text("3000Hz")
                .font(.caption2)
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.5))
                .cornerRadius(4)
            Spacer()
        }
        Spacer()
        // 中央ラベル (例: 1500Hz)
        HStack {
            Text("1500Hz")
                // ... 同様のスタイル
        }
        Spacer()
        // 下部ラベル (例: 0Hz)
        HStack {
            Text("0Hz")
                // ... 同様のスタイル
        }
    }
    .padding(8)
    .allowsHitTesting(false)  // タッチイベントを透過
}
```

**固定ラベルの値の決定方法**:
- **通常表示**: 0Hz, 1000Hz, 2000Hz
- **拡張表示 (isExpanded)**: 0Hz, 1500Hz, 3000Hz

#### 2. ビューポート窓（Layer 2）

**実装方法**: GeometryReader で囲み、`.clipped()` でクリッピング

```swift
GeometryReader { geometry in
    ZStack(alignment: .topLeading) {
        // Layer 1: 大きなキャンバス（後述）
        largeSpectrogramCanvas(geometry: geometry)
            .offset(y: -frequencyOffsetY)  // ← キャンバス全体をオフセット
    }
    .clipped()  // ← ビューポート外をクリッピング
}
```

**重要な変更点**:
- 従来: 各セルの y 座標にオフセット適用
- 新方式: Canvas 全体に `.offset(y:)` を適用し、`.clipped()` で切り取る

#### 3. 大きなキャンバス（Layer 1）

**実装箇所**: 新しい `drawFullSpectrogram()` 関数を作成

```swift
private func drawFullSpectrogram(
    context: GraphicsContext,
    size: CGSize,  // ← ビューポートのサイズ（例: 画面高さ 800pt）
    data: SpectrogramData,
    viewportHeight: CGFloat  // ← ビューポートの高さ
) {
    // 全周波数範囲を計算
    let maxFrequency = Double(data.frequencyBins.max() ?? 4000.0)
    let minFrequency = 0.0  // ← 常に 0Hz から開始

    // 実際の周波数範囲に基づいた巨大なキャンバス高さを計算
    // 例: 0-4000Hz の範囲で、1Hz あたり 0.5pt とすると 2000pt
    let totalCanvasHeight = CGFloat(maxFrequency - minFrequency) * hzToPixelRatio

    // 各周波数ビンを描画
    let freqBinCount = data.frequencyBins.count
    let cellHeight = totalCanvasHeight / CGFloat(freqBinCount)

    for (timeIndex, timestamp) in data.timeStamps.enumerated() {
        // ... 時間軸の処理（既存コードと同様）

        for (freqIndex, magnitude) in magnitudeFrame.enumerated() {
            // Y座標: キャンバス全体の座標系で計算
            let y = totalCanvasHeight - CGFloat(freqIndex + 1) * cellHeight

            let rect = CGRect(
                x: x,
                y: y,  // ← オフセットは Canvas 全体に .offset() で適用
                width: cellWidth,
                height: cellHeight
            )
            context.fill(Path(rect), with: .color(color))
        }
    }
}
```

**キャンバスサイズの計算**:
- **全周波数範囲**: 0Hz 〜 `maxFrequency`（データに基づく）
- **ピクセル比率**: 1Hz あたり何ピクセルか（例: 0.5pt/Hz）
- **キャンバス高さ**: `maxFrequency * hzToPixelRatio`
  - 例: 4000Hz * 0.5pt/Hz = 2000pt

### スクロール動作の実装

#### 現在のスクロール状態管理（維持）

```swift
@State private var frequencyOffsetY: CGFloat = 0
@State private var lastDragValueY: CGFloat = 0
```

#### スクロールオフセットの適用方法（変更）

**従来**:
```swift
// 各セルの y 座標にオフセット追加
y: size.height - CGFloat(freqIndex + 1) * cellHeight + frequencyOffsetY
```

**新方式**:
```swift
// Canvas 全体にオフセット適用
largeSpectrogramCanvas(geometry: geometry)
    .offset(y: -frequencyOffsetY)  // ← ここで一括適用
```

**理由**: 固定ラベルを動かさず、キャンバスのみをスクロールするため

#### スクロール範囲の制限（調整必要）

現在のコード（Line 490-502）:
```swift
let maxScroll = totalHeight * 0.5  // 画面高さの50%
```

**新しい計算**:
```swift
// キャンバス全体の高さ - ビューポート高さ = スクロール可能範囲
let totalCanvasHeight = CGFloat(maxFrequency) * hzToPixelRatio
let viewportHeight = geometry.size.height
let maxScrollRange = totalCanvasHeight - viewportHeight

// 上方向スクロール制限: 0 (キャンバス上端)
// 下方向スクロール制限: maxScrollRange (キャンバス下端)
frequencyOffsetY = max(0, min(frequencyOffsetY, maxScrollRange))
```

### Hz とピクセルの変換

#### 固定ラベルの位置計算

```swift
// ラベルの固定位置（ビューポート基準）
let viewportHeight = geometry.size.height

// 上部ラベル (3000Hz) → Y = 0
// 中央ラベル (1500Hz) → Y = viewportHeight / 2
// 下部ラベル (0Hz) → Y = viewportHeight
```

#### キャンバス座標 ↔ 周波数の変換

```swift
// Hz → Pixel
func frequencyToPixel(_ hz: Double, canvasHeight: CGFloat, maxFreq: Double) -> CGFloat {
    let ratio = hz / maxFreq
    return canvasHeight * (1.0 - CGFloat(ratio))  // 上が高周波
}

// Pixel → Hz
func pixelToFrequency(_ y: CGFloat, canvasHeight: CGFloat, maxFreq: Double) -> Double {
    let ratio = 1.0 - (y / canvasHeight)
    return maxFreq * Double(ratio)
}
```

## 実装ステップ

### Phase 1: 構造変更（スペクトログラムのみ）

1. **固定ラベルの実装**
   - 動的計算を削除（Line 512-522）
   - `.overlay()` で固定値のラベルを追加
   - 値: 通常 (0Hz, 1000Hz, 2000Hz)、拡張 (0Hz, 1500Hz, 3000Hz)

2. **キャンバス描画の変更**
   - `drawSpectrogram()` を `drawFullSpectrogram()` にリファクタリング
   - 周波数範囲を 0Hz 〜 maxFrequency に拡大
   - キャンバス高さを周波数範囲に基づいて計算
   - セルの y 座標計算からオフセット除去

3. **ビューポートの実装**
   - Canvas を `.offset(y: -frequencyOffsetY)` でラップ
   - `.clipped()` でビューポート外をマスク

4. **スクロール範囲の調整**
   - 最大スクロール範囲を `totalCanvasHeight - viewportHeight` に変更

### Phase 2: テストと検証

1. **UIテスト実行**
   - `testSpectrogramExpandDisplay` でスクリーンショット取得
   - 固定ラベルが正しい値を表示しているか確認
   - スクロール動作が正常か確認

2. **手動検証**
   - スクロール時にラベルが固定されているか
   - キャンバス全体が正しくスクロールするか
   - 0Hz から最大Hz まで全範囲を表示できるか

### Phase 3: 最適化（オプショナル）

1. **描画パフォーマンス**
   - 巨大なキャンバスの描画コスト評価
   - 必要に応じてオフスクリーンレンダリング

2. **メモリ使用量**
   - キャンバスサイズの上限設定
   - データの間引き処理

## 影響範囲

### 変更が必要なファイル
- `/Users/asatokazu/Documents/dev/mine/music/vocalis-studio/VocalisStudio/VocalisStudio/Presentation/Views/AnalysisView.swift`
  - `SpectrogramView` 構造体 (Line 442-620)

### 変更が不要な部分
- 時間軸のスクロール（横方向）: 既存の実装を維持
- DragGesture の方向検出（45度閾値）: 既存の実装を維持
- State 変数: `frequencyOffsetY`, `lastDragValueY` を維持
- 全画面表示の切り替え: `.fullScreenCover()` を維持

## リスクと懸念事項

### 1. 巨大なキャンバスの描画コスト
- **懸念**: 0-4000Hz で 2000pt のキャンバスを毎フレーム描画すると重い可能性
- **対策**: SwiftUI の `.drawingGroup()` でメタルレンダリング最適化

### 2. スクロールのスムーズさ
- **懸念**: 大きなキャンバスの `.offset()` 適用がカクつく可能性
- **対策**: GeometryReader 外で計算を最小化、不要な再描画を防ぐ

### 3. メモリ使用量
- **懸念**: 巨大なキャンバスのメモリ消費
- **対策**: 最大キャンバスサイズを制限（例: 5000pt）

## 代替案との比較

### 案A: 現在の動的ラベル（ユーザーが却下）
- ✗ ラベルがスクロールで変わる
- ✓ 実装がシンプル
- ✓ パフォーマンス良好

### 案B: 固定ラベル + ビューポート（ユーザー要求、本プラン）
- ✓ ラベルが固定
- ✓ ユーザーの直感的なメタファーに合致
- ✗ 実装が複雑
- ⚠ パフォーマンス要検証

### 案C: ScrollView + 大きなコンテンツ
- ✓ ラベルが固定
- ✗ ScrollView と横スクロール（時間軸）の競合
- ✗ 再生時の自動スクロールとの統合が困難

### 案D: 全画面表示を廃止して常に固定ラベル表示（オプション）

**背景**: 全画面表示（`.fullScreenCover`）を廃止し、通常画面でも固定ラベル+ビューポート方式を採用

**メリット**:
- ✓ 実装の一貫性: 通常画面と拡張画面で同じロジック
- ✓ コード量削減: `isExpanded` の分岐が減る
- ✓ ユーザー体験の統一: すべての画面で同じ操作感

**デメリット**:
- ✗ 全画面での詳細表示機能の喪失
- ✗ 既存のUIフローの変更
- ✗ UIテストの修正が必要

**実装の変更点**:
1. `.fullScreenCover()` の削除（Line 99-101）
2. `expandedGraphFullScreen()` 関数の削除
3. タップジェスチャーの変更: 全画面表示 → 何もしない or 他のアクション
4. UIテスト `testSpectrogramExpandDisplay` の修正

**判断基準**:
- 全画面表示が本質的に必要かどうか
- 固定ラベル+ビューポート方式で十分な情報を表示できるか
- ユーザーの要求に「全画面」の概念が含まれているか

**推奨**: まずは案Bで全画面表示を維持したまま実装し、動作確認後にユーザーに判断を委ねる

## 次のアクション

1. **Phase 1 の実装**:
   - 固定ラベルの追加
   - `drawFullSpectrogram()` の実装
   - `.offset()` + `.clipped()` の適用

2. **動作確認**:
   - UIテスト実行
   - スクリーンショットでの視覚的確認

3. **ユーザーフィードバック**:
   - 実装が要求通りか確認
   - パフォーマンスが許容範囲か確認

4. **必要に応じて最適化**:
   - 描画コストの削減
   - メモリ使用量の最適化

## 実装時の重要チェックリスト（追加仕様）

### 1. ラベル位置決め根拠の明確化

**原則**: ラベルはビューポート（viewport）基準の固定 Y 位置に描画する

```swift
// ビューポート座標系での固定位置
let viewportHeight = geometry.size.height

// ラベルの固定位置（ビューポート基準）
// 上部ラベル (例: 3000Hz) → Y = 0 (ビューポート上端)
// 中央ラベル (例: 1500Hz) → Y = viewportHeight / 2 (ビューポート中央)
// 下部ラベル (0Hz) → Y = viewportHeight (ビューポート下端)
```

**重要**: ラベルの Y 位置は `frequencyOffsetY` の影響を受けない（固定座標）

### 2. 座標変換の単一関数化（必須）

**原則**: 周波数 ↔ ピクセル変換を単一の関数に集約し、ラベル位置とキャンバス描画の両方で使用

```swift
/// Hz → Canvas Y 座標 (キャンバス座標系)
private func frequencyToCanvasY(_ hz: Double, canvasHeight: CGFloat, maxFreq: Double) -> CGFloat {
    let ratio = hz / maxFreq
    return canvasHeight * (1.0 - CGFloat(ratio))  // 上が高周波、下が低周波
}

/// Canvas Y 座標 → Hz (キャンバス座標系)
private func canvasYToFrequency(_ y: CGFloat, canvasHeight: CGFloat, maxFreq: Double) -> Double {
    let ratio = 1.0 - (y / canvasHeight)
    return maxFreq * Double(ratio)
}

/// Canvas Y 座標 → Viewport Y 座標（スクロール適用後）
private func canvasYToViewportY(_ canvasY: CGFloat, offset: CGFloat) -> CGFloat {
    return canvasY - offset  // オフセット適用
}

/// Viewport Y 座標 → Canvas Y 座標（スクロール逆算）
private func viewportYToCanvasY(_ viewportY: CGFloat, offset: CGFloat) -> CGFloat {
    return viewportY + offset  // オフセット逆算
}
```

**使用箇所**:
- ラベル値の決定: `canvasYToFrequency(canvasYToViewportY(...))` で現在表示されている周波数を計算
- セル描画: `frequencyToCanvasY()` で各周波数ビンの Y 座標を計算

### 3. ラベル「値」決定ロジックの明示

**現在の仕様**: 固定値（スクロールで変わらない）

```swift
// 通常表示 (isExpanded = false)
// 上部: 2000Hz, 中央: 1000Hz, 下部: 0Hz

// 拡張表示 (isExpanded = true)
// 上部: 3000Hz, 中央: 1500Hz, 下部: 0Hz
```

**代替案（将来の検討）**: ビューポートに基づく動的ラベル

```swift
// ビューポート上端に表示されている周波数
let topFreq = canvasYToFrequency(
    canvasYToViewportY(0, offset: frequencyOffsetY),
    canvasHeight: totalCanvasHeight,
    maxFreq: maxFrequency
)

// ビューポート中央に表示されている周波数
let midFreq = canvasYToFrequency(
    canvasYToViewportY(viewportHeight / 2, offset: frequencyOffsetY),
    canvasHeight: totalCanvasHeight,
    maxFreq: maxFrequency
)

// ビューポート下端に表示されている周波数
let bottomFreq = canvasYToFrequency(
    canvasYToViewportY(viewportHeight, offset: frequencyOffsetY),
    canvasHeight: totalCanvasHeight,
    maxFreq: maxFrequency
)
```

**判断基準**: まずは固定値で実装し、ユーザーフィードバック後に動的ラベルを検討

### 4. オフセットの符号と丸め規則の統一

**符号規則**:
- `frequencyOffsetY`: 正の値 = 下にスクロール（低周波側を表示）、負の値 = 上にスクロール（高周波側を表示）
- Canvas の `.offset(y: -frequencyOffsetY)`: 負の符号で適用（Canvas を上に移動 = 高周波を表示）

**丸め規則**:
```swift
// サブピクセル精度を保つため、描画時は丸めない
let y = frequencyToCanvasY(hz, canvasHeight: totalCanvasHeight, maxFreq: maxFrequency)

// ラベル表示時のみ整数に丸める
Text("\(Int(round(displayFreq)))Hz")
```

**一貫性チェック**:
```swift
// デバッグ用アサーション
#if DEBUG
let testHz = 1500.0
let canvasY = frequencyToCanvasY(testHz, canvasHeight: totalCanvasHeight, maxFreq: maxFrequency)
let viewportY = canvasYToViewportY(canvasY, offset: frequencyOffsetY)
let reconstructedHz = canvasYToFrequency(viewportYToCanvasY(viewportY, offset: frequencyOffsetY), canvasHeight: totalCanvasHeight, maxFreq: maxFrequency)
assert(abs(reconstructedHz - testHz) < 0.01, "座標変換の整合性エラー: \(testHz)Hz → \(reconstructedHz)Hz")
#endif
```

### 5. テストアサーションの追加（導入推奨）

**デバッグ用検証コード**:
```swift
#if DEBUG
private func validateLabelAlignment(geometry: GeometryProxy) {
    guard let data = spectrogramData else { return }

    let totalCanvasHeight = calculateTotalCanvasHeight(data: data)
    let viewportHeight = geometry.size.height

    // ラベル位置の検証
    let labelPositions: [(label: String, viewportY: CGFloat, expectedHz: Double)] = [
        ("上部", 0, isExpanded ? 3000 : 2000),
        ("中央", viewportHeight / 2, isExpanded ? 1500 : 1000),
        ("下部", viewportHeight, 0)
    ]

    for (label, viewportY, expectedHz) in labelPositions {
        let canvasY = viewportYToCanvasY(viewportY, offset: frequencyOffsetY)
        let actualHz = canvasYToFrequency(canvasY, canvasHeight: totalCanvasHeight, maxFreq: maxFrequency)
        let error = abs(actualHz - expectedHz)

        if error > 10.0 {  // 10Hz以上のズレは警告
            print("⚠️ \(label)ラベルの位置ズレ: 期待値=\(expectedHz)Hz, 実際=\(actualHz)Hz, 誤差=\(error)Hz")
        }
    }
}
#endif
```

### 6. アーキテクチャ図の追加

**3層構造の視覚的説明**:

```
┌──────────────────────────────────────────────────┐
│ 最上位: ユーザー視点（画面）                      │
│                                                  │
│  [固定ラベル Layer 3 - Overlay]                  │
│  ┌──────────────────────────────────────────┐   │
│  │ 3000Hz ← 常に表示（固定）                 │   │
│  │                                          │   │
│  │ 1500Hz ← 常に表示（固定）                 │   │
│  │                                          │   │
│  │ 0Hz    ← 常に表示（固定）                 │   │
│  └──────────────────────────────────────────┘   │
│           ↓ 透明に重なり合い                     │
│  [ビューポート Layer 2 - Clipping]               │
│  ┌──────────────────────────────────────────┐   │
│  │ 表示可能領域（.clipped()でマスク）         │   │
│  │                                          │   │
│  │  ┏━━━━━━━━━━━━━━━━━━━━━━┓            │   │
│  │  ┃ キャンバスの可視部分   ┃            │   │
│  │  ┃ (スクロールで移動)      ┃            │   │
│  │  ┗━━━━━━━━━━━━━━━━━━━━━━┛            │   │
│  │                                          │   │
│  └──────────────────────────────────────────┘   │
│           ↓ ビューポート外は非表示                 │
│  [キャンバス Layer 1 - Canvas + .offset()]        │
│  ┌──────────────────────────────────────────┐   │
│  │ 4000Hz ────────────────────────────────  │   │
│  │ 3500Hz ────────────────────────────────  │   │
│  │ 3000Hz ────────────────────────────────  │   │
│  │ 2500Hz ────────────────────────────────  │   │
│  │ 2000Hz ────────────────────────────────  │   │
│  │ 1500Hz ────────────────────────────────  │   │
│  │ 1000Hz ────────────────────────────────  │   │
│  │  500Hz ────────────────────────────────  │   │
│  │    0Hz ────────────────────────────────  │   │
│  │                                          │   │
│  │ ← スクロールで上下に移動                  │   │
│  │ ← .offset(y: -frequencyOffsetY)で制御    │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  キャンバス高さ = maxFrequency * hzToPixelRatio │
│  例: 4000Hz * 0.5pt/Hz = 2000pt                 │
└──────────────────────────────────────────────────┘

【スクロール動作の説明】
・ユーザーが上にスワイプ → キャンバスが上に移動 → 高周波数を表示
・ユーザーが下にスワイプ → キャンバスが下に移動 → 低周波数を表示
・ラベルは常に固定位置（0Hz, 1500Hz, 3000Hz）を表示
```

## 参考資料

- ユーザーメッセージ: "目盛を動的に更新するのではなく、目盛を下位のレイヤーに固定するイメージではできませんか"
- ユーザーメッセージ: "固定ヘッダーのようなイメージで３層になっている感じです"
- ユーザーメッセージ: "横に流れる大きなグラフを窓越しにのぞいているイメージです"
- ユーザーメッセージ: "まずはスペクトルのみの対応からで構いません"
- 既存ドキュメント: `claudedocs/vertical_axis_expansion_analysis.md`
