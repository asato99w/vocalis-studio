# Pitch Detection PoC

VocalisStudio用のピッチ検出・グラフ表示機能の技術調査プロジェクト

## 目的

録音音声からピッチ（音高）を検出し、リアルタイムでグラフ表示する機能の実現可能性を検証する

## 検証項目

1. **ピッチ検出アルゴリズム**
   - Accelerate frameworkのvDSPを使用したFFT解析
   - 自己相関法によるピッチ検出
   - 人間の声に対する精度評価

2. **グラフ描画**
   - SwiftUI Canvasによるリアルタイム描画
   - 再生位置との同期

3. **パフォーマンス**
   - 長時間録音（5分以上）の処理時間
   - メモリ使用量

## プロジェクト構成

```
PitchDetectionPoC/
├── App/                    # アプリエントリーポイント
├── PitchDetection/        # ピッチ検出ロジック
│   ├── PitchDetector.swift
│   └── AudioAnalyzer.swift
├── UI/                    # グラフ表示UI
│   ├── PitchGraphView.swift
│   └── RecorderView.swift
└── Resources/             # サンプル音声ファイル
```

## 技術スタック

- Swift 5.9+
- SwiftUI
- AVFoundation
- Accelerate framework (vDSP)

## 次のステップ

Xcodeで新規プロジェクトを作成してください：
1. Xcode → File → New → Project
2. iOS → App を選択
3. Product Name: `PitchDetectionPoC`
4. Interface: SwiftUI
5. Language: Swift
6. 保存先: `/Users/kazuasato/Documents/dev/music/vocalis_studio/pitch_detection_poc`
