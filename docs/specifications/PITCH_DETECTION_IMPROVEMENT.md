# ピッチ検出精度改善ロードマップ

## 目次
1. [概要と目的](#1-概要と目的)
2. [改善方針](#2-改善方針)
3. [自動評価の仕組み](#3-自動評価の仕組み)
4. [パラメータ最適化フレームワーク](#4-パラメータ最適化フレームワーク)
5. [実装ロードマップ](#5-実装ロードマップ)
6. [付録A: 現状分析](#付録a-現状分析)
7. [付録B: 改善アプローチ詳細](#付録b-改善アプローチ詳細)
8. [付録C: 評価メトリクスと技術参考資料](#付録c-評価メトリクスと技術参考資料)

---

## 1. 概要と目的

### 1.1 問題の本質

現在のピッチ検出実装（FFT + HPS）には以下の課題があります：

**精度の問題**：
- テストコードで440Hzの純音すら安定検出できない
- オクターブエラー（1オクターブ違いを検出）が発生
- 低信頼度での検出失敗が頻発

**周波数範囲の制限**：
- 現状: 100-800Hz（リアルタイム）、100-500Hz（ファイル解析）
- 問題: 能力の高い歌手の音域をカバーできない
  - 男声低音（C2=65Hz以下）
  - 女声高音（C6=1047Hz以上）

### 1.2 改善の目標

**精度目標**（4週間後）:
- Gross Pitch Error (GPE): <5%（±50cent以上のエラー率）
- Fine Pitch Error (FPE): <10 cent（平均絶対誤差）
- Octave Error: <2%（オクターブエラー発生率）

**周波数範囲目標**:
- 標準モード: 60-1400Hz（C2-F6相当、99%の歌手をカバー）

**開発体験目標**:
- 人間の介在なしに自動的に改善を進められる仕組み
- 低コストで反復実験可能

---

## 2. 改善方針

### 2.1 基本方針

**「自律的な反復改善」を可能にする仕組みを構築**

人間が個別のパラメータ値を調整するのではなく、システムが自動的に：
1. 評価を実行
2. 問題を発見
3. パラメータを最適化
4. 効果を検証

このサイクルを低コストで回せる環境を整備します。

### 2.2 3段階アプローチ

#### **Phase 1: スケール再生ベース自動評価（最優先）**
**コスト**: 低（既存機能活用）
**期間**: 3-4日
**効果**: 中〜高（パラメータ最適化可能）

**仕組み**:
```
スケール再生（既存機能）
    ↓（スピーカー音）
マイク入力
    ↓（既存のピッチ検出）
自動比較・評価
    ↓
メトリクス算出（GPE, FPE等）
```

**利点**:
- ✅ 既存機能を活用（追加実装最小）
- ✅ 実環境での評価（実際のマイク、スピーカー、部屋の反響）
- ✅ 完全自動化（人間不要）
- ✅ CI/CDで継続的検証可能

**想定される制約**:
- デバイス依存性（マイク・スピーカー性能）
- 環境ノイズの影響
- 音量設定への依存

→ これらの制約を**測定・可視化**し、許容範囲を定義

#### **Phase 2: アルゴリズム改良（中コスト、高効果）**
**コスト**: 中
**期間**: 5-7日
**効果**: 高（オクターブエラー大幅削減）

**追加要素**:
- YINアルゴリズム実装（自己相関ベース）
- FFT+HPS と YIN の投票メカニズム
- Phase 1の自動評価で効果を継続検証

#### **Phase 3: ログベース継続改善（低コスト、長期効果）**
**コスト**: 低
**期間**: 3-4日（基盤構築）
**効果**: 長期的な精度向上

**仕組み**:
- 実使用時のピッチ検出ログを記録
- 低信頼度、検出失敗、オクターブジャンプのパターンを分析
- 問題のある音域・条件を特定
- パラメータの継続的微調整

---

## 3. 自動評価の仕組み

### 3.1 スケール再生ベース自動評価

#### アーキテクチャ

```
┌─────────────────────────────────────┐
│   AutoPitchEvaluator               │
│                                     │
│  1. スケール再生指示                 │
│     → ScalePlayer                   │
│                                     │
│  2. ピッチ検出開始                   │
│     → RealtimePitchDetector        │
│                                     │
│  3. リアルタイム比較                 │
│     expected vs detected            │
│                                     │
│  4. メトリクス計算                   │
│     → GPE, FPE, Octave Error       │
└─────────────────────────────────────┘
```

#### 評価フロー

**ステップ1: スケール再生**
```swift
// Do-Re-Mi-Fa-So（C4-D4-E4-F4-G4）を再生
let scaleNotes: [MIDINote] = [
    MIDINote(noteNumber: 60), // C4 (262Hz)
    MIDINote(noteNumber: 62), // D4 (294Hz)
    MIDINote(noteNumber: 64), // E4 (330Hz)
    MIDINote(noteNumber: 65), // F4 (349Hz)
    MIDINote(noteNumber: 67)  // G4 (392Hz)
]
```

**ステップ2: リアルタイム検出と記録**
```
時刻    | 再生音  | 検出結果  | 誤差
--------|---------|-----------|------
0.0-1.0s| C4(262Hz)| 260Hz    | -8 cent
1.0-2.0s| D4(294Hz)| 147Hz!   | -1200 cent (オクターブエラー)
2.0-3.0s| E4(330Hz)| nil      | 検出失敗
...
```

**ステップ3: メトリクス計算**
```
GPE = (オクターブエラー + 検出失敗) / 総フレーム数
FPE = 平均(|検出cent - 正解cent|)  ※正しく検出されたフレームのみ
Octave Error = オクターブエラーフレーム / 検出フレーム数
```

### 3.2 評価の自動化

#### 開発時の使用方法

```bash
# テストとして実行
xcodebuild test -only-testing:AutoPitchEvaluationTests

# 結果出力例:
# ✅ GPE: 12.3% (目標: <5%)
# ✅ FPE: 15.2 cent (目標: <10 cent)
# ❌ Octave Error: 8.1% (目標: <2%)
```

#### CI/CDでの継続的検証

```yaml
# GitHub Actions等で定期実行
- name: Pitch Detection Evaluation
  run: xcodebuild test -only-testing:AutoPitchEvaluationTests

- name: Check Metrics Threshold
  run: |
    if [ $GPE -gt 5 ]; then
      echo "❌ GPE regression detected"
      exit 1
    fi
```

### 3.3 制約の測定と管理

**デバイス依存性の測定**:
- 複数デバイスで評価を実行
- デバイスごとの精度を記録
- 許容範囲の定義（例: ±10%以内の変動は許容）

**環境ノイズの影響評価**:
- 静寂環境 vs 通常環境での比較
- ノイズレベルと精度の関係を可視化
- 閾値の設定（例: SNR>20dBで信頼できる評価）

**音量設定の影響**:
- 音量50%, 75%, 100%での評価比較
- 推奨音量設定の決定
- 音量不足時の警告メカニズム

---

## 4. パラメータ最適化フレームワーク

### 4.1 最適化対象パラメータ

```swift
struct PitchDetectorParameters {
    // 基本パラメータ
    let bufferSize: Int          // [4096, 8192, 16384]
    let minFreq: Double           // [60, 80, 100]
    let maxFreq: Double           // [800, 1000, 1200, 1400]

    // アルゴリズムパラメータ
    let hpsHarmonics: Int         // [3, 5, 7]
    let confidenceThreshold: Double  // [0.2, 0.3, 0.4, 0.5]

    // 周波数依存閾値（オプション）
    let lowFreqThreshold: Double  // 60-100Hz帯域
    let midFreqThreshold: Double  // 100-500Hz帯域
    let highFreqThreshold: Double // 500-1400Hz帯域
}
```

### 4.2 グリッドサーチによる最適化

#### 段階的探索戦略

**ステージ1: 粗探索（組み合わせ数: ~100）**
```swift
// 主要パラメータのみ
bufferSize: [4096, 8192]
minFreq: [60, 100]
maxFreq: [800, 1400]
confidenceThreshold: [0.3, 0.4]

→ 約 2×2×2×2 = 16通り（音階5つ×5秒 = 25秒/回 → 合計約7分）
```

**ステージ2: 精密探索（組み合わせ数: ~50）**
```swift
// ステージ1で最良だったパラメータ周辺を探索
bufferSize: [bestSize-1024, bestSize, bestSize+1024]
minFreq: [bestMin-10, bestMin, bestMin+10]
...

→ さらに詳細な最適化
```

**ステージ3: 周波数依存閾値の調整**
```swift
// 最適な基本パラメータで、周波数帯域ごとの閾値を調整
低音域: [0.4, 0.5, 0.6]
中音域: [0.3, 0.35, 0.4]
高音域: [0.35, 0.4, 0.45]
```

### 4.3 自動最適化フレームワーク

```swift
class AutoParameterOptimizer {
    func optimize() async -> OptimizationResult {
        // ステージ1: 粗探索
        let coarseParams = await coarseGridSearch()
        print("✅ Coarse search complete: \(coarseParams)")

        // ステージ2: 精密探索
        let fineParams = await fineGridSearch(around: coarseParams)
        print("✅ Fine search complete: \(fineParams)")

        // ステージ3: 周波数依存閾値
        let finalParams = await optimizeFrequencyThresholds(base: fineParams)
        print("✅ Final optimization complete")

        return OptimizationResult(
            parameters: finalParams,
            metrics: await evaluator.evaluate(with: finalParams)
        )
    }

    private func coarseGridSearch() async -> PitchDetectorParameters {
        var bestParams: PitchDetectorParameters?
        var bestScore: Double = 0

        for params in generateCoarseGrid() {
            let metrics = await evaluateWithScalePlay(params)
            let score = calculateOverallScore(metrics)

            if score > bestScore {
                bestScore = score
                bestParams = params
                print("  New best: \(params) → score: \(score)")
            }
        }

        return bestParams!
    }
}
```

### 4.4 スコアリング関数

```swift
func calculateOverallScore(metrics: PitchEvaluationMetrics) -> Double {
    // 重み付き総合スコア
    let gpeScore = max(0, 1.0 - metrics.grossPitchError / 5.0)  // 目標5%
    let fpeScore = max(0, 1.0 - metrics.finePitchError / 10.0)  // 目標10cent
    let octaveScore = max(0, 1.0 - metrics.octaveErrorRate / 2.0)  // 目標2%

    // 重み: GPE>オクターブエラー>FPE
    return 0.5 * gpeScore + 0.3 * octaveScore + 0.2 * fpeScore
}
```

---

## 5. 実装ロードマップ

### Phase 1: 自動評価基盤（Week 1）

**目標**: パラメータを自動的に最適化できる環境を構築

#### タスク1.1: スケール再生ベース自動評価システム
**優先度**: 🔴 最高
**工数**: 2-3日

**成果物**:
- `AutoPitchEvaluator`クラス
- スケール再生とピッチ検出の連携
- メトリクス計算（GPE, FPE, Octave Error）
- XCTestとして実行可能

**実装場所**:
```
VocalisStudio/VocalisStudioTests/Infrastructure/Audio/
├── AutoPitchEvaluator.swift
└── AutoPitchEvaluationTests.swift
```

**検証項目**:
- [ ] スケール再生が正常に動作
- [ ] マイク入力がピッチ検出に正しく渡される
- [ ] 期待値と検出値の時刻同期が正確
- [ ] メトリクスが正しく計算される

#### タスク1.2: ベースライン測定
**優先度**: 🔴 最高
**工数**: 0.5日

**実施内容**:
1. 現在のパラメータで自動評価実行
2. ベースライン精度を記録
3. 改善目標との差分を確認

**期待される結果**:
```
【ベースライン測定結果】
GPE: XX.X% (目標: <5%)
FPE: XX.X cent (目標: <10 cent)
Octave Error: X.X% (目標: <2%)
```

#### タスク1.3: パラメータ最適化フレームワーク
**優先度**: 🟡 高
**工数**: 2-3日

**成果物**:
- `AutoParameterOptimizer`クラス
- グリッドサーチ実装（粗探索 → 精密探索）
- 最適パラメータの自動発見

**実装場所**:
```
VocalisStudio/VocalisStudioTests/Infrastructure/Audio/
└── AutoParameterOptimizer.swift
```

**実行方法**:
```swift
// テストとして実行
let optimizer = AutoParameterOptimizer()
let result = await optimizer.optimize()

print("✅ Best parameters found:")
print("  Buffer size: \(result.parameters.bufferSize)")
print("  Min freq: \(result.parameters.minFreq)")
print("  Max freq: \(result.parameters.maxFreq)")
print("  Confidence threshold: \(result.parameters.confidenceThreshold)")
print("")
print("📊 Metrics with best parameters:")
print("  GPE: \(result.metrics.grossPitchError)%")
print("  FPE: \(result.metrics.finePitchError) cent")
print("  Octave Error: \(result.metrics.octaveErrorRate)%")
```

#### タスク1.4: 最適パラメータの適用
**優先度**: 🟡 高
**工数**: 0.5日

**実施内容**:
1. 最適パラメータを`RealtimePitchDetector`に反映
2. 再度自動評価を実行して効果確認
3. Phase 1完了時の精度を記録

**目標**:
- GPE: <15%
- FPE: <20 cent
- Octave Error: <10%

---

### Phase 2: アルゴリズム改良（Week 2-3）

**目標**: オクターブエラーを大幅削減

#### タスク2.1: YINアルゴリズムの実装
**優先度**: 🔴 最高
**工数**: 5-7日

**成果物**:
- `YINPitchDetector`クラス
- YINアルゴリズムの完全実装
- 単体テスト

**実装場所**:
```
VocalisStudio/VocalisStudio/Infrastructure/Audio/
├── YINPitchDetector.swift
VocalisStudio/VocalisStudioTests/Infrastructure/Audio/
└── YINPitchDetectorTests.swift
```

**参考資料**:
- 論文: "YIN, a fundamental frequency estimator for speech and music"
- オープンソース実装: TarsosDSP (Java), aubio (C)

#### タスク2.2: ハイブリッド検出器の実装
**優先度**: 🟡 高
**工数**: 2-3日

**成果物**:
- `HybridPitchDetector`クラス
- FFT+HPS と YIN の投票メカニズム
- 自動評価による効果検証

**統合ロジック**:
- 両方の検出器を並行実行
- 信頼度と結果の一致度で最終判定
- 不一致時の競合解決ロジック

#### タスク2.3: パラメータ再最適化
**優先度**: 🟢 中
**工数**: 1日

**実施内容**:
1. ハイブリッド検出器で自動最適化を再実行
2. YIN固有のパラメータ（閾値等）も探索
3. 最適パラメータセットの決定

**目標**:
- GPE: <10%
- FPE: <15 cent
- Octave Error: <5%

---

### Phase 3: ログベース継続改善（Week 4以降）

**目標**: 実使用データから継続的に改善

#### タスク3.1: ログ収集機構の実装
**優先度**: 🟢 中
**工数**: 2-3日

**成果物**:
- `PitchDetectionLogger`クラス
- ログフォーマット定義
- プライバシー配慮（ユーザー同意、匿名化）

**ログ項目**:
```swift
struct PitchDetectionLog {
    let timestamp: Date
    let detectedPitch: DetectedPitch?  // nil = 検出失敗
    let confidence: Double
    let spectralFeatures: SpectralFeatures  // ノイズレベル等

    // 疑わしいパターンのフラグ
    let isOctaveJump: Bool  // 前フレームとの差が±1200cent
    let isLowConfidence: Bool  // 閾値以下
}
```

#### タスク3.2: ログ分析ツールの実装
**優先度**: 🟢 中
**工数**: 2-3日

**成果物**:
- ログ解析スクリプト
- 問題パターンの自動検出
- レポート生成

**分析内容**:
- 低信頼度が頻発する音域の特定
- 検出失敗が多発する条件の特定
- オクターブエラーのパターン分析
- 推奨パラメータ調整の提案

#### タスク3.3: 継続的パラメータ調整
**優先度**: 🟢 中
**工数**: 継続的

**運用フロー**:
1. 月次でログ分析実行
2. 問題パターンに基づくパラメータ微調整
3. 自動評価で効果検証
4. パラメータ更新

**目標**:
- GPE: <5%
- FPE: <10 cent
- Octave Error: <2%

---

## 次のステップ

**Phase 1のタスク1.1（スケール再生ベース自動評価システム）** から実装を開始します。

実装の際は：
1. TDDアプローチで進める（テスト → 実装 → リファクタ）
2. 各タスク完了時に自動評価を実行して効果を測定
3. 問題があれば柔軟にアプローチを調整

---

## 付録A: 現状分析

### A.1 現在の実装

**アルゴリズム**: FFT（高速フーリエ変換）+ HPS（Harmonic Product Spectrum）

**主要パラメータ**:
- バッファサイズ: 4096サンプル
- ホップサイズ: 2048サンプル
- サンプリングレート: 44,100 Hz
- 窓関数: Hanning窓
- 周波数範囲:
  - リアルタイム検出: 100-800 Hz
  - ファイル解析: 100-500 Hz
- HPS設定: 5つのハーモニクス（倍音）を使用
- 信頼度閾値:
  - リアルタイム: 0.4
  - ファイル解析: 0.3
- 補間手法: 放物線補間（サブビン精度向上）

### A.2 精度問題の分類

#### A.2.1 アルゴリズム固有の限界
- **倍音依存性**: HPSは倍音構造に依存するため、倍音が弱い声質では精度が低下
- **オクターブエラー**: 1オクターブ高い/低いピッチを誤検出する傾向
- **時間-周波数分解能トレードオフ**:
  - 4096サンプル @ 44.1kHz = 約93ms
  - 低音の精度向上には長い窓が必要だが、時間分解能が低下
  - 高音の時間分解能向上には短い窓が必要だが、周波数分解能が低下

#### A.2.2 前処理の問題
- ノイズ除去なし
- プリエンファシス（高周波数強調）なし
- ダイナミックレンジ処理なし

#### A.2.3 パラメータ調整の問題
- 固定窓サイズ（全周波数帯で同じ）
- 経験的閾値（理論的根拠が弱い）
- 狭い周波数範囲（詳細はA.3参照）

#### A.2.4 後処理の不足
- 時間的連続性未考慮
- 外れ値除去なし
- 平滑化なし

#### A.2.5 実用上の問題
- ビブラート対応不足
- 子音・無声音での誤検出
- 複数音への対応不足

### A.3 周波数範囲の制限

**現状の周波数範囲**:
- リアルタイム検出: 100-800 Hz
- ファイル解析: 100-500 Hz

**能力の高い歌手の音域**:

| 声種 | 音域 | 周波数範囲 |
|------|------|-----------|
| バス（極低音） | C2 - E4 | 65Hz - 330Hz |
| バリトン | A2 - A4 | 110Hz - 440Hz |
| テノール | C3 - F5 | 131Hz - 698Hz |
| アルト | F3 - F5 | 175Hz - 698Hz |
| メゾソプラノ | A3 - A5 | 220Hz - 880Hz |
| ソプラノ | C4 - C6 | 262Hz - 1047Hz |
| コロラトゥーラ | C4 - F6 | 262Hz - 1397Hz |

**カバレッジの問題**:
- ❌ バスの極低音（C2=65Hz）未対応
- ❌ ソプラノ・コロラトゥーラの高音域（C6=1047Hz以上）未対応

**推奨周波数範囲**: 60-1400Hz（C2-F6相当）

---

## 付録B: 改善アプローチ詳細

### B.1 後処理パイプライン

#### メディアンフィルタ
```swift
class PitchPostProcessor {
    private var pitchHistory: [DetectedPitch?] = []
    private let windowSize = 5

    func applyMedianFilter(_ pitch: DetectedPitch?) -> DetectedPitch? {
        pitchHistory.append(pitch)
        if pitchHistory.count > windowSize {
            pitchHistory.removeFirst()
        }

        // 中央値を取得
        let validPitches = pitchHistory.compactMap { $0 }
        guard validPitches.count >= 3 else { return pitch }

        let sorted = validPitches.sorted { $0.frequency < $1.frequency }
        return sorted[sorted.count / 2]
    }
}
```

#### 移動平均平滑化
```swift
func applyMovingAverage(_ pitch: DetectedPitch?, alpha: Double = 0.3) -> DetectedPitch? {
    guard let current = pitch, let previous = previousPitch else {
        return pitch
    }

    // 指数平滑化
    let smoothedFreq = alpha * current.frequency + (1 - alpha) * previous.frequency
    return DetectedPitch.fromFrequency(smoothedFreq, confidence: current.confidence)
}
```

#### オクターブエラー検出＆修正
```swift
func detectAndFixOctaveError(_ pitch: DetectedPitch?) -> DetectedPitch? {
    guard let current = pitch, let previous = previousPitch else {
        return pitch
    }

    let centDiff = abs(current.cents - previous.cents)

    // 1オクターブ（1200cent）近くのジャンプを検出
    if abs(centDiff - 1200) < 100 {
        // 1オクターブ下げて修正
        let correctedFreq = current.frequency / 2.0
        return DetectedPitch.fromFrequency(correctedFreq, confidence: current.confidence * 0.8)
    }

    return pitch
}
```

### B.2 YINアルゴリズムの概要

**YIN (de Cheveigné & Kawahara, 2002)**は自己相関ベースのピッチ検出アルゴリズムです。

**特徴**:
- FFTではなく時間領域の差分関数を使用
- オクターブエラーに強い
- 倍音構造が弱い音でも検出可能

**基本原理**:
1. 差分関数の計算
2. 累積平均正規化差分関数（CMNDF）の計算
3. 絶対閾値でピーク検出
4. 放物線補間

**実装の参考**:
- TarsosDSP (Java): https://github.com/JorenSix/TarsosDSP
- aubio (C): https://github.com/aubio/aubio

### B.3 ハイブリッド検出の投票メカニズム

```swift
class HybridPitchDetector {
    private let fftHpsDetector: RealtimePitchDetector
    private let yinDetector: YINPitchDetector

    func detectPitch(_ samples: [Float]) -> DetectedPitch? {
        let fftResult = fftHpsDetector.analyze(samples)
        let yinResult = yinDetector.analyze(samples)

        // 両方が高信頼度の場合
        if fftResult.confidence > 0.8 && yinResult.confidence > 0.8 {
            let freqDiff = abs(fftResult.frequency - yinResult.frequency)

            if freqDiff < 10 {  // 一致
                return fftResult.confidence > yinResult.confidence ? fftResult : yinResult
            } else {
                // 不一致: 追加検証
                return resolveConflict(fftResult, yinResult)
            }
        }

        // 片方または両方が低信頼度
        return fftResult.confidence > yinResult.confidence ? fftResult : yinResult
    }

    private func resolveConflict(_ fft: DetectedPitch, _ yin: DetectedPitch) -> DetectedPitch? {
        // オクターブ関係をチェック
        let ratio = fft.frequency / yin.frequency
        if abs(ratio - 2.0) < 0.1 || abs(ratio - 0.5) < 0.1 {
            // オクターブ関係 → YINを信用（YINはオクターブエラーに強い）
            return yin
        }

        // それ以外 → 信頼度が高い方
        return fft.confidence > yin.confidence ? fft : yin
    }
}
```

---

## 付録C: 評価メトリクスと技術参考資料

### C.1 評価メトリクス

#### Gross Pitch Error (GPE)
**定義**: ±50cent（半音の半分）以上のエラー率

```
GPE = (誤検出フレーム数 / 総フレーム数) × 100%
```

**目標**: <5%

#### Fine Pitch Error (FPE)
**定義**: 正しく検出されたフレームにおける平均絶対誤差（cent単位）

```
FPE = (1/N) × Σ |detected_cent - true_cent|
```
N = 正しく検出されたフレーム数

**目標**: <10 cent

#### Voicing Decision Accuracy
**定義**: 有声音と無声音の判定精度

```
Accuracy = (正しく判定されたフレーム数 / 総フレーム数) × 100%
```

**目標**: >95%

#### Octave Error Rate
**定義**: 1オクターブ高い/低いピッチを誤検出した割合

```
Octave Error = (オクターブエラーフレーム数 / 検出フレーム数) × 100%
```

**目標**: <2%

### C.2 技術参考資料

#### 学術論文

**YINアルゴリズム**:
- タイトル: "YIN, a fundamental frequency estimator for speech and music"
- 著者: Alain de Cheveigné, Hideki Kawahara
- 出版: Journal of the Acoustical Society of America, 2002
- URL: https://asa.scitation.org/doi/10.1121/1.1458024

**CREPE**:
- タイトル: "CREPE: A Convolutional Representation for Pitch Estimation"
- 著者: Jong Wook Kim, et al.
- 出版: ICASSP 2018
- URL: https://arxiv.org/abs/1802.06182

#### オープンソース実装

**TarsosDSP (Java)**:
- URL: https://github.com/JorenSix/TarsosDSP
- 内容: YIN, FFT, Autocorrelation等の実装
- ライセンス: GPL v3

**aubio (C/Python)**:
- URL: https://github.com/aubio/aubio
- 内容: YIN, YINFFT等、音声解析ライブラリ
- ライセンス: GPL v3

#### Apple Developer Documentation
- vDSP: https://developer.apple.com/documentation/accelerate/vdsp
- AVFoundation: https://developer.apple.com/documentation/avfoundation

---

## まとめ

本ロードマップの核心は、**自律的な反復改善を可能にする仕組みの構築**です。

**3つの柱**:
1. **スケール再生ベース自動評価**: 既存機能を活用した低コスト評価
2. **パラメータ最適化フレームワーク**: グリッドサーチによる自動最適化
3. **ログベース継続改善**: 実使用データからの継続的学習

この仕組みにより、人間の介在を最小限にしながら、段階的に精度を向上させることができます。

**次のアクション**: Phase 1のタスク1.1（スケール再生ベース自動評価システム）の実装を開始
