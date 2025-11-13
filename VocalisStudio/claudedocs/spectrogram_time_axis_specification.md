# スペクトログラム時間軸（横軸）スクロール仕様

## 概要

スペクトログラム表示における時間軸（横軸）のスクロール挙動を定義する。
赤い再生カーソルは画面中央に固定され、再生の進行に伴い「紙（キャンバス）が左へ流れる」方式を採用する。

---

## 用語定義

| 用語 | 説明 |
|------|------|
| `paperLeft` | ビューポート左端から見た「紙（キャンバス）の左端位置」[px]。紙を左へ動かすほど値は増える（右方向に進む）。**負の値を許容**。 |
| `pps` | pixelsPerSecond（固定値。例: 50 px/s）。時間とピクセルの変換係数。 |
| `vpW` | スペクトログラム領域のビューポート幅[px]（周波数ラベル列72pxを除いた幅）。 |
| `canvasW` | 紙（全録音時間）の幅[px] = `durationSec × pps` |
| `playheadX` | 再生カーソルのビューポート内の固定X座標[px]。**常に画面中央** = `vpW / 2` |
| `currentTime` | 現在の再生時刻[秒] |
| `durationSec` | 録音の総時間[秒] |

---

## 不変条件

### 1. スケールは固定
- `pps`は通常表示/フルスクリーンでも不変
- 1秒あたりのピクセル数は常に50px

### 2. カーソルはビューポート内で固定
- `playheadX = vpW / 2`（画面中央）
- 紙が流れ、カーソルは静止

### 3. 時間ラベルはX方向のみ追従
- X軸: 紙と同期してスクロール
- Y軸: 固定（`paperTop`の影響を受けない）

### 4. 周波数ラベルはY方向のみ追従
- X軸: 固定（ビューポート左端、幅72px）
- Y軸: 紙と同期してスクロール（`-paperTop`）

---

## paperLeftの更新式

### 基本式
```swift
paperLeft(t) = min(currentTime * pps - playheadX, canvasW - playheadX)
```

### 説明
- **通常時**: `paperLeft(t) = currentTime * pps - playheadX`
  - 再生が進むと紙が左へ流れる
  - 赤線（`playheadX`）の真下に`currentTime`位置が来る

- **上限**: `canvasW - playheadX`
  - 紙の右端（録音終端）が赤線に到達したら停止
  - それ以上紙は流れない

- **下限**: なし
  - 負の値を許容する
  - 初期状態で`paperLeft(0) = -playheadX`

---

## 初期状態 (currentTime = 0)

### paperLeftの初期値
```swift
paperLeft(0) = min(0 * pps - playheadX, canvasW - playheadX)
            = min(-playheadX, canvasW - playheadX)
            = -playheadX  // 通常は左側の値
```

### 視覚的状態
- 紙の左端（0s位置）が赤線（画面中央）に接する
- 赤線の真下に0sラベルが表示される
- 赤線より左側に`playheadX`分の**グレー余白**が見える
- これは**仕様通りの正しい表示**

### 初期表示イメージ
```
┌─────────────────────────────────────────────────────┐
│ ビューポート (vpW = 600px)                            │
│                                                      │
│ [グレー余白 300px]     0s   1s   2s   3s   4s   5s  │
│                        ↑                             │
│                     紙の左端                          │
│                                                      │
│         画面中央 (playheadX = 300px)                  │
│            ↓                                         │
│            ┃ ← 赤線（固定）                           │
│            ┃                                         │
│         0sが赤線真下                                  │
└─────────────────────────────────────────────────────┘
```

---

## 再生中の挙動

### t = 3秒の例

**前提**:
- `vpW = 600px`
- `playheadX = 300px`
- `pps = 50px/s`
- `durationSec = 10s`
- `canvasW = 500px`
- `currentTime = 3.0s`

**計算**:
```swift
paperLeft(3) = min(3 * 50 - 300, 500 - 300)
            = min(150 - 300, 200)
            = min(-150, 200)
            = -150px
```

**視覚的状態**:
```
┌─────────────────────────────────────────────────────┐
│ ビューポート (vpW = 600px)                            │
│                                                      │
│ [余白150px]  0s   1s   2s   3s   4s   5s   6s   7s  │
│              ↑              ↑                        │
│           紙の左端       画面中央                      │
│                          ↓                           │
│                          ┃ ← 赤線                    │
│                          ┃                           │
│                       3sが赤線真下 ✅                 │
└─────────────────────────────────────────────────────┘
```

**時間ラベルの画面内位置**:
```swift
// Canvas描画座標（paperLeftオフセット適用前）
0s: x = 0 * 50 = 0px
3s: x = 3 * 50 = 150px

// .offset(x: -paperLeft) = .offset(x: 150) 適用後
0s: 0 + 150 = 150px
3s: 150 + 150 = 300px = playheadX ✅
```

---

## 録音終端での挙動

### 上限到達の計算

**前提** (同上):
- `canvasW = 500px`
- `playheadX = 300px`
- `durationSec = 10s`

**上限**:
```swift
paperLeft_max = canvasW - playheadX = 500 - 300 = 200px
```

**上限到達時刻**:
```swift
currentTime * pps - playheadX = 200
currentTime * 50 - 300 = 200
currentTime * 50 = 500
currentTime = 10秒  // 録音終端 ✅
```

### t = 10秒の状態
```swift
paperLeft(10) = min(10 * 50 - 300, 500 - 300)
             = min(500 - 300, 200)
             = min(200, 200)
             = 200px
```

**視覚的状態**:
```
┌─────────────────────────────────────────────────────┐
│ ビューポート (vpW = 600px)                            │
│                                                      │
│ 4s   5s   6s   7s   8s   9s  10s [余白300px]        │
│                         ↑    ↑                      │
│                    画面中央  紙の右端                 │
│                      ↓                               │
│                      ┃ ← 赤線                        │
│                      ┃                               │
│                   10sが赤線真下 ✅                    │
└─────────────────────────────────────────────────────┘
```

**録音終端の画面内位置**:
```swift
// 紙上の終端位置
endPos = 10 * 50 = 500px

// ビューポート内での表示位置
viewportX = endPos - paperLeft
         = 500 - 200
         = 300px
         = playheadX ✅
```

---

## フルスクリーン切替時の挙動

### 変更される値
- `vpW`: ビューポート幅が拡大
- `playheadX = vpW / 2`: 画面中央位置が変化

### 変更されない値
- `pps`: 50px/s で固定（セルの幅は不変）
- `canvasW`: 録音時間は変わらない
- `currentTime`: 再生位置は継続

### 切替後の処理
```swift
// 新しいplayheadXを計算
let newPlayheadX = newVpW / 2

// paperLeftを再計算
let paperLeft_target = currentTime * pps - newPlayheadX
let paperLeft_max = canvasW - newPlayheadX
paperLeft = min(paperLeft_target, paperLeft_max)
```

---

## 極端ケース: canvasW < playheadX

### 状況
非常に短い録音（例: 3秒）でビューポートが広い場合:
- `durationSec = 3s`
- `canvasW = 3 * 50 = 150px`
- `vpW = 600px`
- `playheadX = 300px`

### 挙動
```swift
paperLeft_max = canvasW - playheadX = 150 - 300 = -150px
```

**t = 0**:
```swift
paperLeft(0) = min(0 - 300, -150) = min(-300, -150) = -300
```

**t = 3秒**:
```swift
paperLeft(3) = min(3*50 - 300, -150)
            = min(150 - 300, -150)
            = min(-150, -150)
            = -150px  // 上限到達
```

**結果**:
- 初期状態: 紙の左端が赤線より左（`-300px`）
- 再生終端: 紙の右端が赤線に到達（`-150px`）
- 描画クリップにより、範囲外は描画されない
- **仕様通りの正しい挙動**

---

## 時間ラベルの描画

### Canvas描画コード
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
.frame(width: spectroViewportW, height: timeLabelHeight)
.offset(x: -paperLeft)  // X方向のみ紙と同期
.clipped()
```

### ポイント
- **X座標**: Canvas内で`time * pps`で計算、`.offset(x: -paperLeft)`で同期
- **Y座標**: `size.height / 2`で固定（`paperTop`の影響なし）
- **描画範囲**: `0 <= time <= durationSec`のみ
- **anchor**: `.leading`で左端基準（cutoff防止）

---

## 赤線（再生カーソル）の描画

### Canvas描画コード
```swift
Canvas { context, size in
    // playheadXの固定位置に垂直線を描画
    let playheadX = size.width / 2  // 画面中央

    context.stroke(
        Path { path in
            path.move(to: CGPoint(x: playheadX, y: 0))
            path.addLine(to: CGPoint(x: playheadX, y: size.height))
        },
        with: .color(.red),
        lineWidth: 2
    )
}
.frame(width: spectroViewportW, height: viewportHeight)
.allowsHitTesting(false)
```

### ポイント
- **位置**: `playheadX = size.width / 2`（画面中央固定）
- **オフセットなし**: `.offset()`を適用しない
- **z-index**: スペクトログラムの上に重ねる

---

## 受け入れ基準（目視確認項目）

### ✅ チェックリスト

1. **初期表示**:
   - [ ] 0sラベルが画面中央の赤線真下に表示
   - [ ] 赤線より左側にグレー余白が存在
   - [ ] 赤線より右側にスペクトログラムが表示

2. **再生中**:
   - [ ] 赤線は画面中央で静止
   - [ ] スペクトログラムが左へ流れる
   - [ ] 時間ラベルがスペクトログラムと同期して流れる
   - [ ] 赤線の真下に常に`currentTime`のラベルが位置

3. **縦スクロール**:
   - [ ] 周波数を上下スクロールしても時間ラベル帯は動かない
   - [ ] 時間ラベルのY位置は完全固定

4. **フルスクリーン切替**:
   - [ ] セル（マス目）の幅は不変（pps固定）
   - [ ] 見える範囲のみ拡大
   - [ ] 再生位置は継続

5. **録音終端**:
   - [ ] 紙の右端が赤線に到達したら停止
   - [ ] 録音終端（durationSec）のラベルが赤線真下に表示
   - [ ] それ以上紙は流れない

6. **周波数ラベルとのレイアウト**:
   - [ ] 周波数ラベル列（左72px）と重ならない
   - [ ] 各要素が明確に分離されている

---

## 実装チェックポイント

### 1. paperLeftの初期化
```swift
// ⚠️ 重要: 負の値を許容
paperLeft = currentTime * pixelsPerSecond - playheadX
// 初期状態で paperLeft = -playheadX になる
```

### 2. paperLeftの更新（再生中）
```swift
// currentTime変化時に呼び出す
func updatePaperLeft() {
    let playheadX = spectroViewportW / 2
    let paperLeft_target = currentTime * pixelsPerSecond - playheadX
    let paperLeft_max = canvasWidth - playheadX
    paperLeft = min(paperLeft_target, paperLeft_max)
}
```

### 3. 初期化フラグの削除
```swift
// ❌ 削除: isPaperLeftInitializedフラグは不要
// paperLeftは毎フレーム更新式で計算される
```

### 4. 描画範囲の制限
```swift
// 時間ラベル
while time <= durationSec {  // duration超は描画しない
    // ...
}

// スペクトログラム
// 同様にdurationSecまでのデータのみ描画
```

---

## まとめ

### 設計の核心
1. **赤線固定**: `playheadX = vpW / 2`で画面中央に固定
2. **紙が流れる**: `paperLeft = currentTime * pps - playheadX`で紙を左へ移動
3. **負の値許容**: 初期状態で`paperLeft = -playheadX`（左側に余白）
4. **上限制御**: `paperLeft <= canvasW - playheadX`（右端で停止）

### 時間ラベルの同期
- X方向: `.offset(x: -paperLeft)`で紙と完全同期
- Y方向: 固定（`paperTop`の影響なし）

### 周波数ラベルの分離
- X方向: 固定（左列72px）
- Y方向: `.offset(y: -paperTop)`で紙と同期

### 3レーン構成
```
HStack(spacing: 0) {
    FrequencyLabelsView()     // 左列: X固定, Y追従
    VStack(spacing: 0) {
        SpectrogramCanvas()   // 右上: XY追従
        TimeLabelsCanvas()    // 右下: X追従, Y固定
    }
}
```
