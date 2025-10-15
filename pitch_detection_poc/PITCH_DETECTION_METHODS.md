# ピッチ検出アルゴリズム比較

VocalisStudio向けのピッチ検出アルゴリズムの詳細比較ドキュメント

## 実装されている4つの手法

### 1. FFT-based Detection（FFTベース検出）

#### 原理
- **周波数領域解析**: 高速フーリエ変換（FFT）で時間領域信号を周波数領域に変換
- **ピーク検出**: 周波数スペクトルの最大値を検出
- **放物線補間**: サブビン精度でピーク位置を推定

#### 実装の特徴
```swift
// Hamming窓関数の適用 → FFT → 振幅スペクトル計算 → ピーク検出
vDSP_hamm_window(&window, vDSP_Length(fftSize), 0)
vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection_Forward)
vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfSize))
```

#### 長所
- ✅ **高速処理**: Accelerate frameworkによるハードウェアアクセラレーション
- ✅ **周波数分解能**: FFTサイズを大きくすることで高精度化可能
- ✅ **ノイズ耐性**: 窓関数により周波数漏れを低減
- ✅ **スペクトル可視化**: 同時にスペクトログラムも取得可能

#### 短所
- ❌ **調波構造の無視**: 基音と倍音の区別が困難
- ❌ **時間分解能**: FFTサイズを大きくすると時間分解能が低下
- ❌ **低周波数精度**: 低い周波数ほど周波数分解能が粗くなる

#### 適用シーン
- リアルタイムピッチ検出（低レイテンシ要求）
- スペクトログラム表示と同時にピッチ検出
- 高周波数帯域の解析

---

### 2. Autocorrelation（自己相関法）

#### 原理
- **時間領域解析**: 信号と時間シフトした自分自身の相関を計算
- **周期性検出**: 相関が最大となる遅延（ラグ）が基本周期に対応
- **基音検出**: 基本周波数 = サンプリングレート / 最大相関ラグ

#### 実装の特徴
```swift
// 自己相関関数の計算
for (index, lag) in (minLag...maxLag).enumerated() {
    var sum: Float = 0
    for i in 0..<(fftSize - lag) {
        sum += windowedSamples[i] * windowedSamples[i + lag]
    }
    autocorrelation[index] = sum
}
```

#### 長所
- ✅ **調波構造考慮**: 倍音を含む周期的信号の基音を正確に検出
- ✅ **実装シンプル**: アルゴリズムが直感的で理解しやすい
- ✅ **人間の声に適応**: 声の周期性を効果的に捉える
- ✅ **低周波数精度**: 低周波数でも精度が高い

#### 短所
- ❌ **計算コスト**: ラグごとに全サンプルの積和が必要（O(N²)）
- ❌ **オクターブエラー**: 倍音を基音と誤検出する可能性
- ❌ **信頼度評価困難**: 相関値の絶対的な閾値設定が難しい

#### 適用シーン
- 音楽ピッチ検出（楽器・歌声）
- オフライン解析（計算時間が許容される場合）
- 低周波数帯域の正確な検出

---

### 3. YIN Algorithm（YINアルゴリズム）

#### 原理
- **改良自己相関**: 差分関数と累積平均正規化差分関数（CMNDF）を使用
- **絶対閾値**: 信頼できる最初の極小点を検出
- **放物線補間**: サブサンプル精度向上

#### 実装の特徴
```swift
// Step 1: 差分関数
difference[lag] = sum of (samples[i] - samples[i + lag])²

// Step 2: 累積平均正規化差分関数（CMNDF）
cmndf[lag] = difference[lag] / (runningSum / lag)

// Step 3: 絶対閾値で最初の極小点を検出
if cmndf[lag] < threshold { ... }
```

#### 長所
- ✅ **高精度**: 自己相関法の改良版で精度が向上
- ✅ **オクターブエラー低減**: 正規化により倍音誤検出を抑制
- ✅ **信頼度明確**: CMNDFの値が直接的に信頼度を示す
- ✅ **音楽アプリに最適**: 論文で実証済みの高精度

#### 短所
- ❌ **計算コスト高**: 自己相関よりも複雑な処理
- ❌ **パラメータ調整**: 閾値の最適値がデータ依存
- ❌ **低信号での弱さ**: 静かな音声での検出率低下

#### 適用シーン
- **推奨**: 音楽トレーニングアプリ
- 高精度が要求されるピッチ解析
- オクターブエラーが問題となる用途

#### 参考文献
- [YIN, a fundamental frequency estimator for speech and music (2002)](http://audition.ens.fr/adc/pdf/2002_JASA_YIN.pdf)

---

### 4. Cepstrum Analysis（ケプストラム解析）

#### 原理
- **二重フーリエ変換**: FFT → log → 逆FFT（ケプストラム = スペクトルのスペクトル）
- **ケフレンシー**: 時間領域に似た「ケフレンシー」領域でのピーク検出
- **基音分離**: 調波構造をケプストラム領域で明示的に分離

#### 実装の特徴
```swift
// FFT → log magnitude → Inverse FFT
vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, Forward)
vvlogf(&logMagnitudes, magnitudes, &count)
vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, Inverse)
```

#### 長所
- ✅ **調波構造明確化**: 基音と倍音を完全に分離
- ✅ **フォルマント解析**: 声道の共鳴特性（フォルマント）も同時に取得可能
- ✅ **音色分析**: ピッチと音色の分離が可能
- ✅ **ノイズ耐性**: 調波構造がはっきりしている音声に強い

#### 短所
- ❌ **計算コスト最大**: 二重FFTで処理時間が最も長い
- ❌ **非周期信号に弱い**: 調波構造が不明瞭な音声では精度低下
- ❌ **実装複雑度**: アルゴリズムの理解が難しい

#### 適用シーン
- 音色分析（声質の評価）
- フォルマント抽出（母音認識など）
- 音声合成の前処理

---

## 性能比較表

| 項目 | FFT | Autocorrelation | YIN | Cepstrum |
|------|-----|-----------------|-----|----------|
| **処理速度** | ⭐⭐⭐⭐⭐ 最速 | ⭐⭐⭐ 中速 | ⭐⭐ 遅い | ⭐ 最遅 |
| **精度（人声）** | ⭐⭐⭐ 良好 | ⭐⭐⭐⭐ 高精度 | ⭐⭐⭐⭐⭐ 最高精度 | ⭐⭐⭐⭐ 高精度 |
| **オクターブエラー** | ⭐⭐ 発生しやすい | ⭐⭐⭐ 発生可能 | ⭐⭐⭐⭐⭐ ほぼなし | ⭐⭐⭐⭐ 少ない |
| **ノイズ耐性** | ⭐⭐⭐⭐ 強い | ⭐⭐⭐ 普通 | ⭐⭐⭐ 普通 | ⭐⭐⭐⭐ 強い |
| **低周波数精度** | ⭐⭐ 低い | ⭐⭐⭐⭐ 高い | ⭐⭐⭐⭐⭐ 最高 | ⭐⭐⭐⭐ 高い |
| **実装難易度** | ⭐⭐ 簡単 | ⭐ 最も簡単 | ⭐⭐⭐ 中程度 | ⭐⭐⭐⭐ 複雑 |
| **リアルタイム性** | ⭐⭐⭐⭐⭐ 最適 | ⭐⭐⭐ 可能 | ⭐⭐ 厳しい | ⭐ 不向き |

---

## VocalisStudioへの推奨

### 使用場面ごとの推奨

#### 1. リアルタイムピッチインジケーター（RecordingView）
**推奨: FFT-based Detection**
- 理由: 低レイテンシが要求されるため処理速度最優先
- 実装: 小さいFFTサイズ（1024-2048）で高速処理
- 補足: スペクトログラム表示も同時に可能

#### 2. 録音後のピッチ分析（AnalysisView）
**推奨: YIN Algorithm**
- 理由: 精度が最重要、処理時間は許容可能
- 実装: 大きいウィンドウサイズで高精度検出
- 補足: 音楽トレーニングアプリに最適

#### 3. 音色評価・フォルマント解析（将来機能）
**推奨: Cepstrum Analysis**
- 理由: ピッチと音色の分離が必要
- 実装: フォルマント周波数の同時抽出
- 補足: 声質フィードバック機能に活用

### 実装戦略

```swift
// ハイブリッドアプローチ
class VocalisStudioPitchDetector {
    let realtimeDetector = FFTBasedDetector()      // リアルタイム用
    let analysisDetector = YINDetector()           // 高精度解析用
    let timbreAnalyzer = CepstrumAnalyzer()        // 音色分析用

    func detectRealtimePitch(buffer: AVAudioPCMBuffer) -> PitchData {
        return realtimeDetector.detect(buffer)
    }

    func analyzeRecording(url: URL) async -> [PitchData] {
        return await analysisDetector.analyze(url)  // YIN使用
    }

    func analyzeTimbre(url: URL) async -> TimbreData {
        return await timbreAnalyzer.analyze(url)
    }
}
```

---

## テスト方法

### 比較実験の実施手順

1. **PoCアプリでの比較**
   ```
   1. 同じ音声で4つの手法を実行
   2. 処理時間、検出率、信頼度を記録
   3. ピッチグラフを視覚的に比較
   ```

2. **評価指標**
   - 処理時間（秒）
   - 検出率（%）：ピッチを検出できたウィンドウの割合
   - 平均信頼度（0.0-1.0）
   - オクターブエラー率

3. **テストケース**
   - 安定した持続音（「あー」5秒）
   - 音階上昇（ドレミファソラシド）
   - 速いパッセージ
   - ささやき声（低信号）
   - 背景ノイズあり

---

## 参考文献・リソース

### 論文
1. **YIN Algorithm**: de Cheveigné, A., & Kawahara, H. (2002). "YIN, a fundamental frequency estimator for speech and music." JASA.
2. **Autocorrelation**: Rabiner, L. R. (1977). "On the use of autocorrelation analysis for pitch detection." IEEE TASSP.
3. **Cepstrum**: Noll, A. M. (1967). "Cepstrum pitch determination." JASA.

### 実装リファレンス
- [AudioKit](https://github.com/AudioKit/AudioKit) - PitchTap implementation
- [Accelerate Framework](https://developer.apple.com/documentation/accelerate) - Apple's DSP library
- [librosa](https://librosa.org/) - Python audio analysis library

### オンラインリソース
- [Pitch Detection Algorithms Overview](http://www.fon.hum.uva.nl/paul/papers/pitch_JASA2002.pdf)
- [DSP Guide - Pitch Detection](http://www.dspguide.com/)
