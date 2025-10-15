# VocalisStudio ピッチ検出統合計画

ハイブリッドピッチ検出戦略：FFT（リアルタイム）+ YIN（詳細分析）

## 戦略概要

### 基本方針
- **リアルタイム表示**: FFT-based Detection（低レイテンシ優先）
- **録音後分析**: YIN Algorithm（高精度優先）

### 根拠
- FFT: 0.15秒で10秒音声を処理 → リアルタイム要求に対応
- YIN: 0.48秒で10秒音声を処理 → 録音後なら許容可能
- YIN: 検出率92%、信頼度0.85 → 音楽トレーニングに最適

---

## Phase 1: FFTピッチ検出器の統合（RecordingView）

### 目的
録音中にリアルタイムでピッチを表示し、ユーザーに即座のフィードバックを提供

### 実装場所
- **Infrastructure/Audio/**
  - `FFTPitchDetector.swift` （新規作成）

### ファイル構成

#### 1. FFTPitchDetector.swift
```swift
import Foundation
import AVFoundation
import Accelerate

/// Real-time pitch detector using FFT
/// Optimized for low-latency performance
class FFTPitchDetector {

    // Configuration optimized for real-time
    private let fftSize: Int = 1024        // Small for low latency
    private let sampleRate: Double = 44100.0
    private let minFrequency: Double = 80.0
    private let maxFrequency: Double = 1000.0

    private var fftSetup: FFTSetup?
    private let log2n: vDSP_Length

    init() {
        self.log2n = vDSP_Length(log2(Double(fftSize)))
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
    }

    deinit {
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }

    /// Detect pitch from audio buffer (real-time)
    func detectPitch(buffer: AVAudioPCMBuffer) -> PitchResult? {
        guard let floatChannelData = buffer.floatChannelData else { return nil }

        let samples = Array(UnsafeBufferPointer(
            start: floatChannelData[0],
            count: Int(buffer.frameLength)
        ))

        // Ensure we have enough samples
        guard samples.count >= fftSize else { return nil }

        // Use only the latest fftSize samples for lowest latency
        let windowSamples = Array(samples.suffix(fftSize))

        return detectPitchFFT(samples: windowSamples)
    }

    // FFT implementation (same as PitchDetectorComparison.swift)
    private func detectPitchFFT(samples: [Float]) -> PitchResult? {
        // ... FFT implementation ...
    }
}

/// Result from pitch detection
struct PitchResult {
    let frequency: Double      // Hz
    let midiNote: Double       // MIDI note number
    let noteName: String       // e.g., "A4"
    let confidence: Double     // 0.0-1.0
    let cents: Int            // Cents deviation from nearest note
}
```

#### 2. RecordingViewModel への統合

```swift
// RecordingViewModel.swift に追加

import AVFoundation

@MainActor
class RecordingViewModel: ObservableObject {

    // Existing properties...
    @Published var currentPitch: PitchResult?
    @Published var realtimePitchHistory: [PitchResult] = []

    // Pitch detector
    private let realtimePitchDetector = FFTPitchDetector()

    // Audio engine for real-time monitoring
    private let audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?

    func startRealtimeMonitoring() {
        inputNode = audioEngine.inputNode
        let recordingFormat = inputNode!.outputFormat(forBus: 0)

        // Install tap for real-time analysis
        inputNode?.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: recordingFormat
        ) { [weak self] buffer, time in
            guard let self = self else { return }

            Task { @MainActor in
                // Detect pitch from buffer
                if let pitch = self.realtimePitchDetector.detectPitch(buffer: buffer) {
                    self.currentPitch = pitch
                    self.realtimePitchHistory.append(pitch)

                    // Keep only last 100 points (10 seconds at 10Hz)
                    if self.realtimePitchHistory.count > 100 {
                        self.realtimePitchHistory.removeFirst()
                    }
                }
            }
        }

        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    func stopRealtimeMonitoring() {
        inputNode?.removeTap(onBus: 0)
        audioEngine.stop()
    }
}
```

#### 3. RecordingView UI 更新

```swift
// RecordingView.swift の MockPitchIndicator を実際のデータに接続

struct RealtimePitchIndicator: View {
    let currentPitch: PitchResult?
    let targetScale: [String]  // e.g., ["C", "D", "E", "F", "G"]

    var body: some View {
        VStack(spacing: 8) {
            // Target scale (same as before)
            HStack(spacing: 6) {
                Text("recording.pitch_target".localized)
                    .font(.caption)

                ForEach(targetScale, id: \.self) { note in
                    Text(note)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(3)
                }
            }

            // Detected pitch (real data)
            HStack(spacing: 8) {
                Text("recording.pitch_detected".localized)
                    .font(.caption)

                if let pitch = currentPitch {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(centsColor(pitch.cents))
                            .frame(width: 10, height: 10)

                        Text(pitch.noteName)
                            .font(.callout)
                            .fontWeight(.bold)

                        Text(pitch.cents >= 0 ? "+\(pitch.cents)¢" : "\(pitch.cents)¢")
                            .font(.caption)
                            .foregroundColor(centsColor(pitch.cents))
                    }
                } else {
                    Text("--")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(6)
    }

    private func centsColor(_ cents: Int) -> Color {
        if abs(cents) < 10 {
            return .green
        } else if abs(cents) < 25 {
            return .orange
        } else {
            return .red
        }
    }
}
```

### タスク一覧

- [ ] `FFTPitchDetector.swift` を Infrastructure/Audio/ に作成
- [ ] PitchDetectorComparison.swift から FFT実装をコピー
- [ ] PitchResult 構造体を Domain/Entities/ に作成
- [ ] RecordingViewModel に FFTPitchDetector を統合
- [ ] AVAudioEngine のタップを設定してリアルタイム解析
- [ ] RecordingView の MockPitchIndicator を実データに接続
- [ ] RealtimePitchIndicator を作成
- [ ] テスト：録音中にピッチが表示されることを確認

### 期待される結果

- ✅ 録音開始と同時にピッチインジケーターが動作
- ✅ 約50ms以下のレイテンシで即座にフィードバック
- ✅ 音名（C4, D4など）とセント値（±50¢）が表示
- ✅ 色分けで正確さを視覚的に表示（緑=正確、赤=ずれ）

---

## Phase 2: YINピッチ分析器の統合（AnalysisView）

### 目的
録音後に高精度なピッチ分析を行い、詳細な音程評価を提供

### 実装場所
- **Infrastructure/Audio/**
  - `YINPitchAnalyzer.swift` （新規作成）

### ファイル構成

#### 1. YINPitchAnalyzer.swift

```swift
import Foundation
import AVFoundation
import Accelerate

/// High-accuracy pitch analyzer using YIN algorithm
/// Optimized for offline analysis of recorded audio
class YINPitchAnalyzer {

    // Configuration optimized for accuracy
    private let fftSize: Int = 4096        // Large for high accuracy
    private let hopSize: Int = 2048        // ~46ms intervals
    private let sampleRate: Double = 44100.0
    private let minFrequency: Double = 80.0
    private let maxFrequency: Double = 1000.0

    /// Analyze recorded audio file
    func analyze(audioFile: URL) async throws -> [PitchData] {
        let (samples, sampleRate) = try loadAudioFile(audioFile)
        return analyzeBuffer(samples: samples, sampleRate: sampleRate)
    }

    private func analyzeBuffer(samples: [Float], sampleRate: Double) -> [PitchData] {
        var pitchData: [PitchData] = []

        let windowCount = (samples.count - fftSize) / hopSize + 1

        for windowIndex in 0..<windowCount {
            let startIndex = windowIndex * hopSize
            let endIndex = min(startIndex + fftSize, samples.count)

            guard endIndex - startIndex == fftSize else { continue }

            let windowSamples = Array(samples[startIndex..<endIndex])
            let timestamp = Double(startIndex) / sampleRate

            if let (frequency, confidence) = detectPitchYIN(
                samples: windowSamples,
                sampleRate: sampleRate
            ) {
                if frequency >= minFrequency && frequency <= maxFrequency && confidence > 0.3 {
                    pitchData.append(PitchData(
                        timestamp: timestamp,
                        frequency: frequency,
                        confidence: confidence
                    ))
                }
            }
        }

        return pitchData
    }

    // YIN implementation (same as PitchDetectorComparison.swift)
    private func detectPitchYIN(samples: [Float], sampleRate: Double) -> (frequency: Double, confidence: Double)? {
        // ... YIN implementation ...
    }

    private func loadAudioFile(_ url: URL) throws -> ([Float], Double) {
        // ... file loading ...
    }
}
```

#### 2. AnalyzeRecordingUseCase の作成

```swift
// Application/UseCases/AnalyzeRecordingUseCase.swift

protocol AnalyzeRecordingUseCaseProtocol {
    func execute(recording: Recording) async throws -> PitchAnalysisResult
}

class AnalyzeRecordingUseCase: AnalyzeRecordingUseCaseProtocol {

    private let pitchAnalyzer: YINPitchAnalyzer

    init(pitchAnalyzer: YINPitchAnalyzer) {
        self.pitchAnalyzer = pitchAnalyzer
    }

    func execute(recording: Recording) async throws -> PitchAnalysisResult {
        // Analyze pitch using YIN
        let pitchData = try await pitchAnalyzer.analyze(audioFile: recording.fileURL)

        // Calculate statistics
        let avgFrequency = pitchData.isEmpty ? 0 : pitchData.reduce(0) { $0 + $1.frequency } / Double(pitchData.count)
        let avgConfidence = pitchData.isEmpty ? 0 : pitchData.reduce(0) { $0 + $1.confidence } / Double(pitchData.count)

        // Compare with target scale (if available)
        var accuracyScore: Double = 0
        if let scaleSettings = recording.scaleSettings {
            accuracyScore = calculateAccuracy(pitchData: pitchData, scaleSettings: scaleSettings)
        }

        return PitchAnalysisResult(
            pitchData: pitchData,
            averageFrequency: avgFrequency,
            averageConfidence: avgConfidence,
            accuracyScore: accuracyScore
        )
    }

    private func calculateAccuracy(pitchData: [PitchData], scaleSettings: ScaleSettings) -> Double {
        // Calculate how accurately the user sang the target scale
        // Compare detected pitches with expected scale notes
        // Return score 0.0-1.0

        // TODO: Implement scale comparison logic
        return 0.85  // Placeholder
    }
}

struct PitchAnalysisResult {
    let pitchData: [PitchData]
    let averageFrequency: Double
    let averageConfidence: Double
    let accuracyScore: Double  // 0.0-1.0
}
```

#### 3. AnalysisView への統合

```swift
// AnalysisView.swift を実データに接続

@StateObject private var viewModel: AnalysisViewModel

// ViewModel
@MainActor
class AnalysisViewModel: ObservableObject {
    @Published var pitchAnalysis: PitchAnalysisResult?
    @Published var isAnalyzing = false

    private let analyzeUseCase: AnalyzeRecordingUseCaseProtocol

    init(analyzeUseCase: AnalyzeRecordingUseCaseProtocol) {
        self.analyzeUseCase = analyzeUseCase
    }

    func analyzePitch(recording: Recording) async {
        isAnalyzing = true

        do {
            pitchAnalysis = try await analyzeUseCase.execute(recording: recording)
        } catch {
            print("Analysis failed: \(error)")
        }

        isAnalyzing = false
    }
}

// View integration
public var body: some View {
    VStack {
        if viewModel.isAnalyzing {
            ProgressView("Analyzing pitch...")
        } else if let analysis = viewModel.pitchAnalysis {
            // Display real pitch graph
            PitchGraphView(
                pitchData: analysis.pitchData,
                duration: recording.duration.seconds,
                playbackPosition: playbackPosition
            )

            // Display accuracy score
            AccuracyScoreCard(score: analysis.accuracyScore)
        }
    }
    .task {
        await viewModel.analyzePitch(recording: recording)
    }
}
```

### タスク一覧

- [ ] `YINPitchAnalyzer.swift` を Infrastructure/Audio/ に作成
- [ ] PitchDetectorComparison.swift から YIN実装をコピー
- [ ] `AnalyzeRecordingUseCase.swift` を Application/UseCases/ に作成
- [ ] PitchAnalysisResult を Domain/Entities/ に作成
- [ ] AnalysisViewModel を作成
- [ ] AnalysisView を実データに接続
- [ ] PitchGraphView を PoC からコピー
- [ ] スケールとの比較ロジックを実装
- [ ] 正確さスコアの計算アルゴリズムを実装
- [ ] テスト：録音後に高精度なピッチグラフが表示されることを確認

### 期待される結果

- ✅ 録音後、自動的に高精度ピッチ分析が実行される
- ✅ 詳細なピッチグラフが表示される（時間 vs 周波数）
- ✅ 目標スケールとの比較が表示される
- ✅ 正確さスコア（0-100%）が表示される
- ✅ 各音符ごとの評価（正確/やや外れ/大きく外れ）

---

## Phase 3: DependencyContainer への登録

### DependencyContainer.swift の更新

```swift
@MainActor
class DependencyContainer {
    static let shared = DependencyContainer()

    // MARK: - Pitch Detection

    lazy var fftPitchDetector: FFTPitchDetector = {
        FFTPitchDetector()
    }()

    lazy var yinPitchAnalyzer: YINPitchAnalyzer = {
        YINPitchAnalyzer()
    }()

    // MARK: - Use Cases

    lazy var analyzeRecordingUseCase: AnalyzeRecordingUseCaseProtocol = {
        AnalyzeRecordingUseCase(pitchAnalyzer: yinPitchAnalyzer)
    }()

    // MARK: - ViewModels (updated)

    lazy var recordingViewModel: RecordingViewModel = {
        RecordingViewModel(
            startRecordingUseCase: startRecordingUseCase,
            stopRecordingUseCase: stopRecordingUseCase,
            audioPlayer: audioPlayer,
            realtimePitchDetector: fftPitchDetector  // 🆕 Added
        )
    }()

    func makeAnalysisViewModel(recording: Recording) -> AnalysisViewModel {
        AnalysisViewModel(
            recording: recording,
            analyzeUseCase: analyzeRecordingUseCase  // 🆕 Added
        )
    }
}
```

---

## 実装の優先順位

### 優先度: 高

1. ✅ **FFTPitchDetector の作成** (Phase 1)
   - リアルタイムフィードバックの基盤
   - ユーザー体験への直接的な影響大

2. ✅ **RecordingView への統合** (Phase 1)
   - すぐにユーザーが恩恵を受けられる
   - MVP機能の完成度向上

### 優先度: 中

3. ✅ **YINPitchAnalyzer の作成** (Phase 2)
   - 高精度分析の実現
   - 音楽トレーニングアプリとしての差別化

4. ✅ **AnalysisView への統合** (Phase 2)
   - 詳細なフィードバック提供
   - ユーザーの上達支援

### 優先度: 低（将来拡張）

5. ⭕ **スケール比較の高度化**
   - 各音符ごとの詳細評価
   - 上達記録の追跡

6. ⭕ **Cepstrum Analysis の追加**
   - 音色分析機能
   - フォルマント抽出

---

## パフォーマンス目標

### RecordingView（FFT）
- ⏱️ レイテンシ: < 50ms
- 📊 CPU使用率: < 15%
- 🔋 バッテリー影響: 最小限
- 📈 更新頻度: 10Hz (100ms間隔)

### AnalysisView（YIN）
- ⏱️ 処理時間: 10秒音声を0.5秒以内
- 📊 CPU使用率: 処理時のみ（バックグラウンドで実行）
- 🎯 検出精度: 92%以上
- 💯 信頼度: 0.85以上

---

## テスト計画

### 単体テスト
- [ ] FFTPitchDetector のピッチ検出精度テスト
- [ ] YINPitchAnalyzer のピッチ検出精度テスト
- [ ] スケール比較ロジックのテスト
- [ ] 正確さスコア計算のテスト

### 統合テスト
- [ ] RecordingView でのリアルタイム表示テスト
- [ ] AnalysisView での録音後分析テスト
- [ ] 長時間録音（5分）のパフォーマンステスト
- [ ] メモリリークテスト

### ユーザビリティテスト
- [ ] レイテンシが許容範囲か確認
- [ ] ピッチインジケーターが直感的か確認
- [ ] 正確さスコアが理解しやすいか確認

---

## 成功の指標

### 技術指標
- ✅ FFT: レイテンシ < 50ms
- ✅ YIN: 処理時間 < 1秒（10秒音声）
- ✅ 検出率: > 85%（FFT）、> 90%（YIN）
- ✅ クラッシュ率: 0%

### ユーザー体験指標
- ✅ リアルタイムフィードバックが"即座"に感じられる
- ✅ ピッチインジケーターが音程の正確さを明確に示す
- ✅ 分析結果が練習の改善に役立つ
- ✅ アプリがスムーズに動作する

---

## まとめ

### ハイブリッド戦略の利点

1. **最適なユーザー体験**
   - リアルタイム: FFTで即座のフィードバック
   - 詳細分析: YINで正確な評価

2. **パフォーマンスの最適化**
   - FFT: 低レイテンシ、低CPU使用率
   - YIN: オフラインなので処理時間許容

3. **段階的な実装**
   - Phase 1（FFT）だけでも価値提供
   - Phase 2（YIN）で完成度向上

4. **将来の拡張性**
   - Cepstrumで音色分析を追加可能
   - 複数アルゴリズムの組み合わせも可能

この戦略により、VocalisStudioは本格的な音楽トレーニングアプリとして完成します！🎵
