# セットアップ手順

新しく追加した比較機能ファイルをXcodeプロジェクトに追加する手順

## Xcodeへのファイル追加

### 1. Xcodeでプロジェクトを開く
```bash
cd /Users/asatokazu/Documents/dev/mine/music/vocalis-studio/pitch_detection_poc/PoC
open PoC.xcodeproj
```

### 2. 新しいファイルを追加
以下の2つのファイルがプロジェクトに追加されました：

#### ✅ すでにディレクトリに存在しているファイル
- `PitchDetectorComparison.swift` - 4つのピッチ検出手法の実装と比較機能
- `ComparisonView.swift` - 比較結果を表示するUI

#### 📝 Xcodeプロジェクトへの追加手順

1. **Project Navigatorでファイル追加**
   - Xcode左側のProject Navigator（⌘+1）を開く
   - `PoC`フォルダを右クリック
   - "Add Files to 'PoC'..."を選択

2. **ファイルを選択**
   - `/Users/asatokazu/Documents/dev/mine/music/vocalis-studio/pitch_detection_poc/PoC/PoC/PitchDetectorComparison.swift`
   - `/Users/asatokazu/Documents/dev/mine/music/vocalis-studio/pitch_detection_poc/PoC/PoC/ComparisonView.swift`
   - 両方を選択（⌘キーを押しながらクリック）

3. **オプション設定**
   - ✅ "Copy items if needed"にチェック（すでにコピー済みなのでチェック不要）
   - ✅ "Create groups"を選択
   - ✅ "Add to targets"で`PoC`にチェック
   - "Add"ボタンをクリック

### 3. ビルドして確認
```bash
# またはXcodeで ⌘+B
xcodebuild -project PoC.xcodeproj -scheme PoC -destination 'platform=iOS Simulator,name=iPhone 16' build
```

### 4. 実行
- iPhone 16 Simulatorを選択
- ⌘+R で実行
- メイン画面に"Compare Detection Methods"ボタンが表示されることを確認

## トラブルシューティング

### ビルドエラー: "Use of undeclared type 'PitchDetectionMethod'"
→ `PitchDetectorComparison.swift`がプロジェクトに追加されていません。上記手順2を再実行してください。

### ビルドエラー: "Cannot find 'ComparisonView' in scope"
→ `ComparisonView.swift`がプロジェクトに追加されていません。上記手順2を再実行してください。

### AudioKitの依存関係エラー
`AudioKitPitchDetector.swift`がAudioKitライブラリに依存していますが、比較機能では使用していません。
もしビルドエラーが出る場合は、以下のコメントアウトで対応：

```swift
// AudioKitPitchDetector.swiftの先頭行をコメントアウト
// import AudioKit
```

## 動作確認

### 1. 基本動作確認
1. アプリを起動
2. "Compare Detection Methods"をタップ
3. "Start Recording"をタップ
4. マイクに向かって「あー」と5秒間発声
5. "Stop & Compare"をタップ
6. 数秒後に比較結果が表示される

### 2. 期待される結果
- 4つのアルゴリズムそれぞれの結果が表示される
- FFT-based Detectionが最も高速
- YIN Algorithmが最も高精度
- 推奨アルゴリズムが青いカードで表示される

### 3. スクリーンショット

```
┌─────────────────────────────────┐
│  Compare Detection Methods      │
├─────────────────────────────────┤
│  📊 Method Comparison           │
│                                 │
│  ⚪️ Ready                       │
│  [Start Recording]              │
│                                 │
│  ┌───────────────────────────┐ │
│  │ Method   Time  Rate  Conf │ │
│  │ FFT      0.15s  85%  0.72 │ │
│  │ Autocorr 0.32s  88%  0.75 │ │
│  │ YIN      0.48s  92%  0.85 │ │
│  │ Cepstrum 0.62s  87%  0.78 │ │
│  └───────────────────────────┘ │
│                                 │
│  ⭐ Recommended: YIN Algorithm  │
│  High accuracy musical apps    │
└─────────────────────────────────┘
```

## 次のステップ

実際に声を録音して、各アルゴリズムの違いを体験してください：

1. **持続音でテスト**（「あー」5秒）
   - YINとAutocorrelationが最も安定
   - FFTは高速だが信頼度がやや低い

2. **音階でテスト**（ドレミファソ）
   - YINが音高変化を最も正確に追従
   - Cepstrumは調波構造を明確に捉える

3. **ささやき声でテスト**
   - すべてのアルゴリズムで検出率が低下
   - YINが比較的頑健

これらの実験結果を基に、VocalisStudioに最適なアルゴリズムを選択できます！
