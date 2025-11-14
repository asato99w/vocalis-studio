# 周波数ラベル可視性問題の調査報告

**日付**: 2025-11-14
**対象**: AnalysisView.swift - スペクトログラム表示
**問題**: 周波数ラベル(6k, 7k, 8k等)が初期状態で表示されず、再生4-5秒後に突然表示される

## 問題の概要

### 現象
- **初期状態(0-3秒)**: 周波数ラベル(0Hz, 1k, 2k, 3k, 4k, 5k, 6k, 7k, 8k)が非表示
- **中盤以降(4-5秒~)**: スペクトログラムが画面左端に到達すると、周波数ラベルが突然表示される

### 期待動作
- 周波数ラベルは画面左端に固定され、初期状態から常に表示されるべき

## 根本原因の特定

### Canvas座標系の理解

**SwiftUIのCanvas描画ルール**:
- Canvasのフレーム範囲外(0未満、canvasWidthより大きい)に描画された要素は表示されない
- `.offset()`修飾子でCanvas全体を移動させることができる

### 初期状態の座標計算

**オリジナル実装**:
```swift
// Canvas幅: 録音データの長さに基づく
canvasWidth = dataDuration * pixelsPerSecond  // 例: 1秒 * 50 = 50px

// Canvas offset: プレイヘッドを画面中央に配置するための調整
canvasOffsetX = playheadX - currentTimeCanvasX  // 例: 180px

// 周波数ラベルのCanvas座標
labelCanvasX = 5  // 常に固定

// 周波数ラベルの画面座標
labelScreenX = labelCanvasX + canvasOffsetX = 5 + 180 = 185px  // 画面外(右側)
```

**問題の核心**:
- Canvasが短い(50px)
- Canvas offset が正の値(180px)でCanvasが右にシフト
- ラベル位置(x=5)はCanvas範囲内だが、Canvas自体が画面右側にあるため表示されない

**4-5秒後に表示される理由**:
```swift
// Canvas幅が成長
canvasWidth = 4.5秒 * 50 = 225px

// Canvas offsetが負に転じる
canvasOffsetX = 180 - 200 = -20px  // Canvasが左にシフト

// 周波数ラベルの画面座標
labelScreenX = 5 + (-20) = -15px  // まだ画面外(左側)だが...

// さらに進むと
canvasOffsetX = -100px
labelScreenX = 5 + (-100) = -95px  // Canvas範囲内かつ画面内に入る
```

## 試行錯誤の経緯

### 試行1: ラベル位置を動的に調整(失敗)
```swift
// 誤ったアプローチ
let labelX = 5 + max(0, canvasOffsetX)
```

**問題点**: ラベルが時間経過で移動してしまう(x=185 → x=5)
- 初期: labelX = 5 + 180 = 185px
- 中盤: labelX = 5 + 0 = 5px
- **要件違反**: 画面固定ラベルが移動してしまう

**ユーザーフィードバック**:
> "なぜ、同じ過ちを繰り返すのでしょうか。そのような対応ではラベル固定という要件と矛盾することは明らかではないですか。"

### 試行2: Canvas幅拡張 + データオフセット(失敗)
```swift
// Canvas幅を拡張
canvasWidth = dataWidth + leftPadding  // leftPadding = viewportWidth / 2

// データ描画位置をオフセット
spectrogramX = timestamp * pixelsPerSecond + leftPadding
timeAxisX = timestamp * pixelsPerSecond + leftPadding
```

**問題点**: スペクトログラムが画面外に押し出された
- 0sのデータ位置 = 0 * 50 + 180 = 180px (Canvas座標)
- Canvas offset = 180px
- 画面上の位置 = 180 + 180 = 360px (画面外右側)

**結果**: スペクトログラムが完全に非表示になった

## 正しい解決アプローチ(進行中)

### 設計方針

**Canvas拡張戦略**:
1. Canvas幅を左側に拡張(`leftPadding`分)
2. Canvasの左端(x=0)が画面左端に来るようにする
3. 0sのデータ位置はCanvas内の`leftPadding`位置(画面中央)に配置
4. 周波数ラベルはCanvas左端近く(x=5)に固定

**座標系の整理**:
```
Canvas座標:
  ├─ 0 ──────── leftPadding ──────── canvasWidth
  │   [空白領域]    [データ領域]
  │   (黄色背景)
  │
  画面座標(初期状態):
  ├─ 0 ──────── viewportWidth/2 ──────── viewportWidth
      [Canvas左端]   [0sデータ位置]
```

### 実装内容

**1. Canvas幅の拡張**:
```swift
let canvasLeftPadding: CGFloat = viewportWidth / 2
let canvasWidth = dataWidth + canvasLeftPadding
```

**2. データ描画位置(変更なし)**:
```swift
// スペクトログラム
let x = CGFloat(timestamp) * pixelsPerSecond  // 0sは x=0

// 時間軸ラベル
let x = CGFloat(timestamp) * pixelsPerSecond  // 0sは x=0
```

**3. 周波数ラベル(変更なし)**:
```swift
let labelX = 5  // 固定
```

**4. デバッグ用の可視化**:
```swift
// 黄色背景でleftPadding領域を可視化
context.fill(
    Path(CGRect(x: 0, y: 0, width: canvasLeftPadding, height: canvasHeight)),
    with: .color(.yellow.opacity(0.3))
)
```

## 現在の状態

### 実装済み
- ✅ Canvas幅の拡張
- ✅ データ描画位置の保持
- ✅ デバッグ用黄色背景の追加

### 未確認
- ❓ 黄色背景が正しい位置に表示されるか
- ❓ 周波数ラベルが初期状態から表示されるか
- ❓ スペクトログラムが正しい位置に表示されるか

### 次のステップ

1. **黄色背景の確認**: UIテストを実行して、黄色背景が画面左端に表示されることを確認
2. **期待される表示**:
   - 黄色背景: 画面左端から画面中央(再生ヘッド位置)まで
   - 周波数ラベル: 黄色背景内の左端近く(x=5付近)
   - 0sデータ: 黄色背景の右端(画面中央の再生ヘッド位置)

3. **問題がある場合の診断**:
   - 黄色背景が画面外 → Canvas offsetの計算が間違っている
   - 黄色背景が画面右側 → leftPaddingの適用方法が間違っている
   - 黄色背景が正しい位置だが周波数ラベルが見えない → 描画順序の問題

## 技術的な学び

### Canvas座標系とオフセットの関係
```
Canvas内の要素位置 + Canvas offset = 画面上の位置

例:
周波数ラベル(Canvas x=5) + Canvas offset(180) = 画面x=185 (画面外)
周波数ラベル(Canvas x=5) + Canvas offset(-100) = 画面x=-95 (画面外)
```

### Canvas範囲の重要性
SwiftUI Canvasは範囲外の描画を表示しないため、Canvas幅の設計が重要:
- **狭すぎる**: 要素がCanvas範囲外に出て非表示になる
- **適切**: すべての表示要素がCanvas範囲内に収まる
- **広すぎる**: メモリ効率の問題(今回は許容範囲)

## 参考資料

- オリジナル実装のスクリーンショット: `/private/tmp/original_impl_screenshots/`
- Canvas拡張後のスクリーンショット: `/tmp/canvas_expansion_screenshots/`
- テストログ: `/tmp/canvas_width_fix_test.log`

## 関連ファイル

- `VocalisStudio/Presentation/Views/AnalysisView.swift` (lines 479-928)
  - Canvas幅計算: lines 479-491
  - 黄色背景描画: lines 511-515
  - スペクトログラム描画: lines 776-891
  - 周波数ラベル描画: lines 708-775
  - 時間軸ラベル描画: lines 904-929
