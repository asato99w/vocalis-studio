# Pitch Detection PoC

VocalisStudio用のピッチ検出・グラフ表示機能の技術調査プロジェクト

## 目的

録音音声からピッチ（音高）を検出し、リアルタイムでグラフ表示する機能の実現可能性を検証する

## 🆕 NEW: ピッチ検出手法の比較機能

4つのピッチ検出アルゴリズムを同一音声で比較できる機能を実装しました：

1. **FFT-based Detection** - 周波数領域解析（高速）
2. **Autocorrelation** - 時間領域自己相関（バランス型）
3. **YIN Algorithm** - 改良自己相関（高精度）
4. **Cepstrum Analysis** - ケプストラム解析（音色分析）

詳細は [PITCH_DETECTION_METHODS.md](./PITCH_DETECTION_METHODS.md) を参照してください。

## 検証項目

1. **ピッチ検出アルゴリズム**
   - ✅ FFT-based Detection実装完了
   - ✅ Autocorrelation実装完了
   - ✅ YIN Algorithm実装完了
   - ✅ Cepstrum Analysis実装完了
   - ✅ 4手法の性能比較機能実装

2. **グラフ描画**
   - SwiftUI Canvasによるリアルタイム描画
   - 再生位置との同期
   - ピッチグラフとスペクトログラム同時表示

3. **パフォーマンス**
   - 長時間録音（5分以上）の処理時間
   - メモリ使用量
   - 各アルゴリズムの処理速度比較

## プロジェクト構成

```
pitch_detection_poc/
├── README.md                              # プロジェクト概要
├── PITCH_DETECTION_METHODS.md            # アルゴリズム詳細比較
└── PoC/
    ├── PoCApp.swift                       # アプリエントリーポイント
    ├── ContentView.swift                  # メイン画面
    ├── ComparisonView.swift              # 🆕 アルゴリズム比較画面
    ├── PitchDetectorComparison.swift     # 🆕 比較実装
    ├── PitchDetector.swift                # FFT+自己相関実装
    ├── AudioKitPitchDetector.swift        # AudioKit実装
    ├── SpectrumAnalyzer.swift             # スペクトル解析
    ├── PitchGraphView.swift               # ピッチグラフUI
    ├── SpectrumGraphView.swift            # スペクトログラムUI
    └── AudioRecorderViewModel.swift       # 録音・解析VM
```

## 技術スタック

- Swift 5.9+
- SwiftUI
- AVFoundation
- Accelerate framework (vDSP)

## 使い方

### 基本的なピッチ検出
1. アプリを起動
2. "Start Recording"で録音開始
3. 声を出す（「あー」など持続音推奨）
4. "Stop Recording"で録音停止
5. 自動的にピッチ解析が実行される
6. ピッチグラフとスペクトログラムが表示される

### アルゴリズム比較
1. メイン画面で"Compare Detection Methods"をタップ
2. "Start Recording"で録音開始
3. 声を出す（5-10秒程度）
4. "Stop & Compare"をタップ
5. 4つのアルゴリズムが同時に実行される
6. 処理時間、検出率、信頼度が表形式で表示される
7. 各アルゴリズムの詳細は展開して確認可能
8. 最適なアルゴリズムが自動的に推薦される

### 比較結果の見方
- **Processing Time**: 処理速度（秒）- 低いほど高速
- **Detection Rate**: 検出率（%）- 高いほど多くのウィンドウでピッチ検出成功
- **Average Confidence**: 平均信頼度（0.0-1.0）- 高いほど検出結果が信頼できる
- **Detected Points**: 検出されたピッチポイント数

## VocalisStudioへの統合推奨

詳細は [PITCH_DETECTION_METHODS.md](./PITCH_DETECTION_METHODS.md) を参照

### リアルタイム表示（RecordingView）
→ **FFT-based Detection** を推奨
- 理由: 低レイテンシ、スペクトログラム同時表示可能

### 録音後解析（AnalysisView）
→ **YIN Algorithm** を推奨
- 理由: 最高精度、音楽トレーニングに最適

### 音色分析（将来機能）
→ **Cepstrum Analysis** を推奨
- 理由: フォルマント抽出、声質評価に有用
