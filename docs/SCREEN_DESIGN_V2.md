# Vocalis Studio - 画面設計書 v2

## 1. 概要

### 1.1 画面構成
アプリは5つの画面で構成され、シンプルで明確なナビゲーションを提供する。

### 1.2 画面の向き
**デフォルト: 横画面（Landscape）**
- 録音画面でのリアルタイム表示を最大化
- スペクトルとピッチを横長に表示
- 縦画面もサポート（自動回転対応）

```
ホーム画面（新規）
  ├─→ 録音画面（既存改良）
  │     └─→ 一覧画面（既存改良）
  │           └─→ 分析画面（新規）
  ├─→ 一覧画面（既存改良）
  │     └─→ 分析画面（新規）
  └─→ 設定画面（新規）
```

## 2. 画面詳細設計

### 2.1 ホーム画面（HomeView）

#### 目的
アプリの起動地点として、主要な機能へのシンプルなアクセスを提供

#### レイアウト
```
┌───────────────────────────┐
│    Vocalis Studio         │
├───────────────────────────┤
│                           │
│      [アプリロゴ]          │
│                           │
├───────────────────────────┤
│                           │
│   ┌─────────────────┐    │
│   │   録音を開始     │    │
│   │   🎤            │    │
│   └─────────────────┘    │
│                           │
│   ┌─────────────────┐    │
│   │   録音一覧       │    │
│   │   📋            │    │
│   └─────────────────┘    │
│                           │
│   ┌─────────────────┐    │
│   │   設定          │    │
│   │   ⚙️            │    │
│   └─────────────────┘    │
│                           │
└───────────────────────────┘
```

#### 機能
- 録音画面への遷移
- 一覧画面への遷移
- 設定画面への遷移

#### 実装方針
```swift
struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Logo/Title
                VStack {
                    Image("AppLogo")
                    Text("Vocalis Studio")
                        .font(.largeTitle)
                }

                // Menu Buttons
                NavigationLink(destination: RecordingView(...)) {
                    MenuButton(title: "録音を開始", icon: "mic.fill")
                }

                NavigationLink(destination: RecordingListView(...)) {
                    MenuButton(title: "録音一覧", icon: "list.bullet")
                }

                NavigationLink(destination: SettingsView()) {
                    MenuButton(title: "設定", icon: "gearshape")
                }
            }
            .navigationTitle("ホーム")
        }
    }
}
```

### 2.2 録音画面（RecordingView）

#### 変更点
- **横画面レイアウトに最適化**
- **スケール選択機能の追加**（5トーン / オフ）
- 録音設定機能の追加（スタートピッチ、テンポ、上昇回数）
- **リアルタイムピッチ・スペクトル表示**
- ナビゲーションバーに一覧画面への遷移ボタンを追加

#### レイアウト（横画面）
```
┌──────────────────────────────────────────────────────────┐
│ [<] 録音                                         [一覧]  │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  左側: 設定パネル        │  右側: リアルタイム表示       │
│ ┌──────────────────┐    │ ┌──────────────────────────┐│
│ │ スケール設定      │    │ │  リアルタイムスペクトル  ││
│ │                  │    │ │  [周波数スペクトログラム] ││
│ │ スケール選択      │    │ │                          ││
│ │  [5トーン ▼]    │    │ └──────────────────────────┘│
│ │  ・5トーンスケール│    │ ┌──────────────────────────┐│
│ │  ・オフ          │    │ │  ピッチインジケーター     ││
│ │                  │    │ │                          ││
│ │ スタートピッチ    │    │ │   目標: ━━ ド レ ミ...   ││
│ │  [C3  ▼]        │    │ │   検出: ●  (C4 +5¢)     ││
│ │                  │    │ │                          ││
│ │ テンポ           │    │ └──────────────────────────┘│
│ │  [120 BPM]      │    │                             │
│ │  [▔▔▔●▔▔▔▔]    │    │  [    🎤 録音開始    ]       │
│ │  60 ←→ 180      │    │  [  ▶️ 最後の録音を再生 ]    │
│ │                  │    │                             │
│ │ 上昇回数         │    │  ※スケール「オフ」選択時は  │
│ │  [3回 ▼]        │    │   スタートピッチ・テンポ・  │
│ │                  │    │   上昇回数は無効化          │
│ │ [プリセット保存]  │    │                             │
│ └──────────────────┘    │                             │
└──────────────────────────────────────────────────────────┘
```

#### レイアウト（縦画面 - サブ対応）
```
┌───────────────────────────┐
│ [<] 録音          [一覧]  │
├───────────────────────────┤
│  設定                     │
│ ┌───────────────────────┐ │
│ │ スケール: 5トーン ▼   │ │
│ │ スタートピッチ: C3 ▼  │ │
│ │ テンポ: 120 BPM       │ │
│ │ 上昇回数: 3回 ▼      │ │
│ └───────────────────────┘ │
├───────────────────────────┤
│  リアルタイム表示         │
│ ┌───────────────────────┐ │
│ │ [スペクトル]          │ │
│ │ [ピッチ: C4 +5¢]     │ │
│ └───────────────────────┘ │
├───────────────────────────┤
│  [   🎤 録音開始   ]      │
│  [ ▶️ 最後の録音を再生 ]  │
└───────────────────────────┘
```

#### 設定項目の詳細

##### スケール選択
- **選択肢**:
  - **5トーンスケール**: ド→レ→ミ→ファ→ソの5音スケール（デフォルト）
  - **オフ**: スケールなし（録音のみ）
- **将来的な拡張**:
  - 7トーンスケール（ドレミファソラシ）
  - アルペジオパターン
  - カスタムスケール
- **動作**:
  - 「オフ」選択時は、スタートピッチ・テンポ・上昇回数が無効化（グレーアウト）
  - スケール選択で録音方式が切り替わる

##### スタートピッチ
- 選択範囲: C2 〜 C6（4オクターブ範囲）
- デフォルト: C3（男性向け）またはC4（女性向け）
- 半音単位で選択可能
- 表記: C, C#, D, D#, E, F, F#, G, G#, A, A#, B
- **スケール「オフ」時は無効**

##### テンポ
- 範囲: 60 〜 180 BPM
- デフォルト: 120 BPM
- スライダーで調整
- リアルタイムプレビュー可能
- **スケール「オフ」時は無効**

##### 上昇回数
- 範囲: 1 〜 10回
- デフォルト: 3回
- **意味**: スケール（ド→ソ）を上昇させる回数
  - 例: 3回 = ド→レ→ミ→ファ→ソ を3セット繰り返す
- **スケール「オフ」時は無効**

#### リアルタイム表示の詳細

##### スペクトル表示
- FFTベースのリアルタイムスペクトログラム
- 周波数範囲: 80Hz 〜 2000Hz（ボーカル範囲）
- 更新頻度: 30fps（録音中のみ）
- カラーマップ: ヒートマップ（青→緑→黄→赤）

##### ピッチインジケーター
- 検出ピッチをリアルタイム表示
- 目標音階（スケール）とのずれを表示
  - ±50セント範囲で表示
  - 0セントで緑、ずれるほど赤/青
- 音名表記（例: "C4 +12¢"）
- 信頼度が低い場合は非表示

#### 実装方針
```swift
struct RecordingView: View {
    @StateObject private var viewModel: RecordingViewModel
    @StateObject private var settingsViewModel: RecordingSettingsViewModel
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width > geometry.size.height {
                // 横画面レイアウト
                landscapeLayout
            } else {
                // 縦画面レイアウト
                portraitLayout
            }
        }
        .navigationTitle("録音")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: RecordingListView(...)) {
                    Image(systemName: "list.bullet")
                    Text("一覧")
                }
            }
        }
    }

    // 横画面レイアウト
    private var landscapeLayout: some View {
        HStack(spacing: 0) {
            // 左側: 設定パネル
            RecordingSettingsPanel(viewModel: settingsViewModel)
                .frame(width: 280)

            Divider()

            // 右側: リアルタイム表示 + コントロール
            VStack {
                RealtimeDisplayArea(
                    spectrogramData: viewModel.spectrogramData,
                    pitchData: viewModel.currentPitch,
                    targetPitch: viewModel.targetPitch
                )

                RecordingControls(
                    state: viewModel.recordingState,
                    onStart: { viewModel.startRecording() },
                    onStop: { viewModel.stopRecording() },
                    onPlayLast: { viewModel.playLastRecording() }
                )
                .padding()
            }
        }
    }

    // 縦画面レイアウト
    private var portraitLayout: some View {
        VStack {
            RecordingSettingsCompact(viewModel: settingsViewModel)

            RealtimeDisplayArea(
                spectrogramData: viewModel.spectrogramData,
                pitchData: viewModel.currentPitch,
                targetPitch: viewModel.targetPitch
            )

            RecordingControls(...)
        }
    }
}
```

#### 新規ViewModelの追加

```swift
enum ScaleType: String, CaseIterable, Identifiable {
    case fiveTone = "5トーンスケール"
    case off = "オフ"
    // 将来的な拡張
    // case sevenTone = "7トーンスケール"
    // case arpeggio = "アルペジオ"

    var id: String { rawValue }

    var isScaleEnabled: Bool {
        self != .off
    }
}

class RecordingSettingsViewModel: ObservableObject {
    @Published var scaleType: ScaleType = .fiveTone
    @Published var startPitch: MIDINote = MIDINote(60) // C3
    @Published var tempo: Int = 120
    @Published var ascendingCount: Int = 3  // 上昇回数

    // スケール選択に応じて他の設定を有効/無効化
    var isSettingsEnabled: Bool {
        scaleType.isScaleEnabled
    }

    // スケール設定の生成
    func generateScaleSettings() -> ScaleSettings? {
        guard scaleType.isScaleEnabled else {
            return nil  // スケールオフ
        }

        return ScaleSettings(
            startNote: startPitch,
            pattern: .fiveTone,  // ド→レ→ミ→ファ→ソ
            tempo: Tempo(bpm: tempo),
            ascendingCount: ascendingCount
        )
    }

    // プリセット保存機能
    func savePreset(name: String) {
        let preset = RecordingPreset(
            scaleType: scaleType,
            startPitch: startPitch,
            tempo: tempo,
            ascendingCount: ascendingCount
        )
        // UserDefaultsに保存
    }

    func loadPreset(name: String) {
        // プリセット読み込み
    }
}
```

**主な変更点**:
- **スケール選択**: Pickerで5トーン/オフを選択可能
- **上昇回数**: 繰り返し回数から名称変更、意味を明確化
- **条件付き無効化**: スケールオフ時は他の設定を無効化
- **拡張性**: 将来的なスケール追加に対応した設計
- 横画面/縦画面の自動レイアウト切り替え
- リアルタイム表示機能の統合
- ViewModelの分離（設定とメインロジック）

### 2.3 一覧画面（RecordingListView）

#### 変更点
- **sheet表示 → NavigationLinkによるページ遷移に変更**
- 各録音項目から分析画面への遷移追加
- dismissボタン削除（NavigationStackの戻るボタンを使用）

#### レイアウト
```
┌───────────────────────────┐
│ [<] 録音一覧               │
├───────────────────────────┤
│ ┌───────────────────────┐ │
│ │ 2025/10/14 15:30      │ │
│ │ 5-tone Scale          │ │
│ │ 2:30                  │ │
│ │ [▶️] [分析] [🗑️]      │ │
│ └───────────────────────┘ │
│ ┌───────────────────────┐ │
│ │ 2025/10/14 14:20      │ │
│ │ ...                   │ │
│ └───────────────────────┘ │
└───────────────────────────┘
```

#### 実装方針の変更
```swift
struct RecordingListView: View {
    @StateObject private var viewModel: RecordingListViewModel
    // @Environment(\.dismiss)を削除

    var body: some View {
        List {
            ForEach(viewModel.recordings) { recording in
                RecordingRow(
                    recording: recording,
                    isPlaying: viewModel.playingRecordingId == recording.id,
                    onPlay: { ... },
                    onDelete: { ... },
                    onAnalyze: {
                        // 分析画面へ遷移
                    }
                )
            }
        }
        .navigationTitle("録音一覧")
        .navigationBarTitleDisplayMode(.large)
        // ToolbarItemのcloseボタン削除
    }
}
```

#### RecordingRowの変更
```swift
struct RecordingRow: View {
    let recording: Recording
    let isPlaying: Bool
    let onPlay: () -> Void
    let onDelete: () -> Void
    let onAnalyze: () -> Void  // 新規追加

    var body: some View {
        HStack {
            // Play button
            Button(action: onPlay) { ... }

            // Recording info
            VStack(alignment: .leading) {
                Text(recording.formattedDate)
                Text(recording.duration.formatted)
            }

            Spacer()

            // 分析ボタン（新規）
            NavigationLink(destination: AnalysisView(recording: recording)) {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())

            // Delete button
            Button(action: { showDeleteConfirmation = true }) { ... }
        }
    }
}
```

### 2.4 分析画面（AnalysisView）★新規

#### 目的
個別録音の詳細分析を提供（スペクトル・ピッチ分析）
**横画面レイアウトを標準として設計**

#### レイアウト（横画面）
```
┌────────────────────────────────────────────────────────────────┐
│ [<] 録音分析                                                    │
├────────────────────────────────────────────────────────────────┤
│  左側: 情報・コントロール  │  右側: グラフ表示エリア          │
│ ┌──────────────────┐      │ ┌──────────────────────────────┐│
│ │ 録音情報          │      │ │  スペクトログラム            ││
│ │ 日時: 10/14 15:30│      │ │  [時間軸 × 周波数軸]         ││
│ │ 長さ: 2:30       │      │ │  ▼                          ││
│ │ スケール: 5トーン│      │ │  2000Hz ▓▓▓░░░▓▓▓           ││
│ │ ピッチ: C3       │      │ │  1000Hz ░▓▓▓▓▓░░            ││
│ │ テンポ: 120BPM   │      │ │  500Hz  ░░▓▓▓░░░            ││
│ │ 上昇回数: 3回    │      │ │  200Hz  ░░░▓▓░░░            ││
│ └──────────────────┘      │ │         0s    1s    2s       ││
│                           │ └──────────────────────────────┘│
│ ┌──────────────────┐      │ ┌──────────────────────────────┐│
│ │ 再生コントロール  │      │ │  ピッチ分析グラフ             ││
│ │                  │      │ │  Hz                          ││
│ │ [◀◀][▶️/⏸][▶▶] │      │ │  500 ┬ ●─●─●─●─●  検出ピッチ││
│ │                  │      │ │  400 ┼ ───────────  目標音階││
│ │ ━●━━━━━━━━━━━━   │      │ │  300 ┼                      ││
│ │ 00:15 / 02:30    │      │ │  200 ┴                      ││
│ └──────────────────┘      │ │      ド レ ミ ファ ソ        ││
│                           │ └──────────────────────────────┘│
│                           │                                 │
│                           │                                 │
│                           │                                 │
└────────────────────────────────────────────────────────────────┘
```

#### レイアウト（縦画面 - サブ対応）
```
┌───────────────────────────┐
│ [<] 録音分析               │
├───────────────────────────┤
│ 録音情報                  │
│ 10/14 15:30 | 2:30        │
│ 5トーン | C3 | 120BPM    │
│ 上昇回数: 3回             │
├───────────────────────────┤
│ 再生コントロール          │
│ [◀◀] [▶️/⏸] [▶▶]        │
│ ━●━━━━━━ 00:15 / 02:30   │
├───────────────────────────┤
│ スペクトログラム          │
│ ┌───────────────────────┐ │
│ │ [時間 × 周波数]       │ │
│ │                       │ │
│ └───────────────────────┘ │
├───────────────────────────┤
│ ピッチ分析                │
│ ┌───────────────────────┐ │
│ │ [ピッチグラフ]        │ │
│ │ 検出 vs 目標          │ │
│ └───────────────────────┘ │
└───────────────────────────┘
```

#### 機能詳細

##### スペクトル表示
- FFT（高速フーリエ変換）によるスペクトログラム
- 時間軸 × 周波数軸のヒートマップ
- リアルタイム再生位置の表示

##### ピッチ分析
- 録音全体のピッチ検出
- スケール音階との比較表示
  - 目標音階（ド・レ・ミ・ファ・ソ）をライン表示
  - 実際の検出ピッチを重ねて表示

##### 再生コントロール
- 再生/一時停止
- シーク（早送り・巻き戻し）
- プログレスバー

#### 実装方針
```swift
struct AnalysisView: View {
    let recording: Recording
    @StateObject private var viewModel: AnalysisViewModel

    init(recording: Recording) {
        self.recording = recording
        _viewModel = StateObject(wrappedValue: AnalysisViewModel(recording: recording))
    }

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width > geometry.size.height {
                // 横画面レイアウト
                landscapeLayout
            } else {
                // 縦画面レイアウト
                portraitLayout
            }
        }
        .navigationTitle("録音分析")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.analyze()
        }
    }

    // 横画面レイアウト
    private var landscapeLayout: some View {
        HStack(spacing: 0) {
            // 左側: 情報・コントロール
            VStack(spacing: 16) {
                RecordingInfoPanel(recording: recording)

                PlaybackControl(
                    isPlaying: viewModel.isPlaying,
                    currentTime: viewModel.currentTime,
                    duration: recording.duration,
                    onPlayPause: { viewModel.togglePlayback() },
                    onSeek: { time in viewModel.seek(to: time) }
                )

                Spacer()
            }
            .frame(width: 280)
            .padding()

            Divider()

            // 右側: グラフエリア
            VStack(spacing: 16) {
                // スペクトログラム（上半分）
                SpectrogramView(
                    spectrogramData: viewModel.spectrogramData,
                    currentTime: viewModel.currentTime
                )
                .frame(maxHeight: .infinity)

                Divider()

                // ピッチ分析グラフ（下半分）
                PitchAnalysisView(
                    pitchData: viewModel.pitchData,
                    scaleNotes: viewModel.scaleNotes,
                    currentTime: viewModel.currentTime
                )
                .frame(maxHeight: .infinity)
            }
            .padding()
        }
    }

    // 縦画面レイアウト
    private var portraitLayout: some View {
        ScrollView {
            VStack(spacing: 16) {
                RecordingInfoCompact(recording: recording)

                PlaybackControl(
                    isPlaying: viewModel.isPlaying,
                    currentTime: viewModel.currentTime,
                    duration: recording.duration,
                    onPlayPause: { viewModel.togglePlayback() },
                    onSeek: { time in viewModel.seek(to: time) }
                )

                SpectrogramView(
                    spectrogramData: viewModel.spectrogramData,
                    currentTime: viewModel.currentTime
                )
                .frame(height: 200)

                PitchAnalysisView(
                    pitchData: viewModel.pitchData,
                    scaleNotes: viewModel.scaleNotes,
                    currentTime: viewModel.currentTime
                )
                .frame(height: 200)
            }
            .padding()
        }
    }
}
```

**横画面レイアウトの利点**:
- **スペクトログラム**: 時間軸を横長に表示して詳細確認
- **ピッチグラフ**: 音の推移を見やすく表示
- **画面分割**: 情報/コントロールとグラフを同時表示
- **視認性**: 全体を一目で把握できる

#### データ構造
```swift
struct SpectrogramData {
    let frequencies: [Float]      // 周波数ビン
    let timeFrames: [[Float]]     // 時間フレームごとの強度
    let sampleRate: Double
}

struct PitchData {
    let timeStamps: [Double]      // 時刻
    let frequencies: [Float]      // 検出されたピッチ（Hz）
    let confidences: [Float]      // 信頼度
}

struct ScaleNote {
    let name: String              // "C", "D", "E", "F", "G"
    let frequency: Float          // Hz
    let startTime: Double         // スケール再生開始時刻
    let duration: Double          // 音の長さ
}
```

### 2.5 設定画面（SettingsView）★新規

#### 目的
アプリの基本設定（まずは言語設定のみ）

#### レイアウト
```
┌───────────────────────────┐
│ [<] 設定                  │
├───────────────────────────┤
│ 言語設定                  │
│ ┌───────────────────────┐ │
│ │ 日本語            ✓   │ │
│ │ English               │ │
│ └───────────────────────┘ │
├───────────────────────────┤
│ バージョン情報            │
│ v1.0.0                    │
└───────────────────────────┘
```

#### 実装方針
```swift
struct SettingsView: View {
    @AppStorage("appLanguage") private var language = "ja"

    var body: some View {
        Form {
            Section("言語設定") {
                Picker("言語", selection: $language) {
                    Text("日本語").tag("ja")
                    Text("English").tag("en")
                }
                .pickerStyle(.inline)
            }

            Section("情報") {
                HStack {
                    Text("バージョン")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("設定")
        .onChange(of: language) { newValue in
            // 言語変更の処理
            updateLocalization(newValue)
        }
    }
}
```

## 3. ナビゲーション実装

### 3.1 NavigationStackによる管理
```swift
@main
struct VocalisStudioApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(DependencyContainer.shared)
        }
    }
}
```

### 3.2 画面遷移フロー
```
HomeView
  ├─ NavigationLink → RecordingView
  │                      └─ NavigationLink (toolbar) → RecordingListView
  │                                                        └─ NavigationLink → AnalysisView(recording)
  ├─ NavigationLink → RecordingListView
  │                      └─ NavigationLink → AnalysisView(recording)
  └─ NavigationLink → SettingsView
```

**遷移パターン**:
1. ホーム → 録音 → 一覧 → 分析
2. ホーム → 一覧 → 分析
3. ホーム → 設定

## 4. 技術的実装要件

### 4.1 分析機能の実装

#### スペクトル分析
```swift
class SpectrogramAnalyzer {
    func analyze(audioURL: URL) async throws -> SpectrogramData {
        // AVAudioFileで音声ファイル読み込み
        // vDSPでFFT処理
        // スペクトログラムデータ生成
    }
}
```

#### ピッチ検出
```swift
class PitchDetector {
    func detectPitch(audioURL: URL) async throws -> PitchData {
        // AVAudioEngineでリアルタイム分析
        // YIN algorithmまたはAutocorrelation
        // ピッチデータ生成
    }
}
```

#### スケール同期
```swift
class ScaleSynchronizer {
    func synchronizePitch(
        pitchData: PitchData,
        scaleSettings: ScaleSettings
    ) -> SynchronizedPitchData {
        // スケール再生タイミングとピッチデータを同期
        // 各音階ごとの精度計算
        // 可視化データ生成
    }
}
```

### 4.2 リアルタイム分析の実装

#### リアルタイムスペクトル分析
```swift
class RealtimeSpectrogramAnalyzer {
    private let fftSize = 2048
    private let sampleRate: Double = 44100
    private var fftSetup: vDSP_DFT_Setup?

    func analyze(audioBuffer: AVAudioPCMBuffer) -> [Float] {
        // AVAudioEngineからリアルタイムでバッファ取得
        // vDSPでFFT処理（高速）
        // スペクトルデータ生成
        // 30fps相当にデータ間引き
    }
}
```

#### リアルタイムピッチ検出
```swift
class RealtimePitchDetector {
    func detectPitch(audioBuffer: AVAudioPCMBuffer) -> PitchResult? {
        // YIN algorithm実装
        // または Autocorrelation法
        // 信頼度計算
        // セント偏差計算
    }
}

struct PitchResult {
    let frequency: Float      // Hz
    let note: String          // "C4"
    let cents: Int            // ±50セント
    let confidence: Float     // 0.0〜1.0
}
```

#### 録音中の処理フロー
```swift
class RecordingViewModel: ObservableObject {
    @Published var spectrogramData: [Float] = []
    @Published var currentPitch: PitchResult?
    @Published var targetPitch: MIDINote?

    private var audioEngine: AVAudioEngine
    private var spectrogramAnalyzer: RealtimeSpectrogramAnalyzer
    private var pitchDetector: RealtimePitchDetector

    func setupRealtimeAnalysis() {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, time in
            guard let self = self else { return }

            // スペクトル分析（30fps制限）
            DispatchQueue.main.async {
                self.spectrogramData = self.spectrogramAnalyzer.analyze(audioBuffer: buffer)
            }

            // ピッチ検出（60fps制限）
            if let pitch = self.pitchDetector.detectPitch(audioBuffer: buffer) {
                DispatchQueue.main.async {
                    self.currentPitch = pitch
                }
            }
        }
    }
}
```

### 4.3 画面の向き設定

#### Info.plistの設定
```xml
<key>UISupportedInterfaceOrientations</key>
<array>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
    <string>UIInterfaceOrientationPortrait</string>
</array>
<key>UIInterfaceOrientationPreferred</key>
<string>UIInterfaceOrientationLandscapeLeft</string>
```

#### 画面ごとの向き制御
```swift
struct RecordingView: View {
    var body: some View {
        // 横画面優先だが縦画面もサポート
        .onAppear {
            // 横画面を推奨するヒント（強制ではない）
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeLeft.rawValue, forKey: "orientation")
        }
    }
}
```

### 4.4 必要なフレームワーク
- **AVFoundation**: 音声処理、リアルタイム入力
- **Accelerate**: FFT/DSP処理（vDSP）
- **Charts**: グラフ表示（iOS 16+）
- **CoreGraphics**: スペクトログラム描画

## 5. 実装優先順位

### Phase 1: 基本ナビゲーションと設定機能
1. HomeView作成
2. NavigationStack実装
3. 既存画面の遷移方法変更
4. 設定画面（言語設定）
5. 横画面対応の基礎実装

### Phase 2: 録音画面の拡張
1. ScaleType enumの実装
2. RecordingSettingsViewModel実装
3. 録音設定UI（スケール選択、スタートピッチ、テンポ、上昇回数）
4. スケールオフ時の無効化ロジック
5. 横画面レイアウトの実装
6. 縦画面レイアウトの実装

### Phase 3: リアルタイム表示機能
1. リアルタイムスペクトル分析実装
2. リアルタイムピッチ検出実装
3. スペクトル表示UI
4. ピッチインジケーターUI
5. パフォーマンス最適化（30fps/60fps制限）

### Phase 4: 分析画面の実装
1. AnalysisView UI作成
2. 録音情報表示
3. 再生コントロール実装
4. オフライン分析（スペクトル・ピッチ）
5. スケール同期表示
6. 精度計算

### 技術的優先順位
1. **最優先**: ナビゲーション、設定画面（Phase 1）
2. **高優先**: 録音設定機能（Phase 2）
3. **中優先**: リアルタイム表示（Phase 3）
4. **低優先**: 詳細分析画面（Phase 4）

## 6. UI/UXの改善ポイント

### 6.1 横画面対応による改善
- **視認性向上**: スペクトルとピッチを横長に表示
- **操作性向上**: 設定パネルとビジュアルを同時表示
- **没入感**: 録音に集中できる画面構成
- **自然な持ち方**: 横向きで安定した録音姿勢

### 6.2 録音設定機能の追加
- **スケールのオンオフ**: 必要に応じてスケールなしで録音可能
- **柔軟な練習**: 自分の音域に合わせたスタートピッチ
- **段階的トレーニング**: テンポ調整で難易度コントロール
- **集中練習**: 上昇回数で練習量を調整
- **拡張性**: 将来的に7トーンやアルペジオを追加可能
- **プリセット**: よく使う設定を保存

### 6.3 リアルタイム表示の利点
- **即座のフィードバック**: 録音中に音程を確認
- **視覚的ガイド**: スペクトルで声の状態を把握
- **モチベーション**: 改善をリアルタイムで実感
- **練習効率**: 問題点をその場で修正

### 6.4 一覧画面の改善
- sheet表示 → 通常のページ遷移でより自然な操作感
- 分析ボタン追加で機能発見性向上
- ホームと録音画面の両方から遷移可能

### 6.5 ナビゲーションの改善
- NavigationStackによる統一的な遷移
- パンくずリスト（戻るボタン）で階層が明確
- 複数の導線でアクセス性向上

### 6.6 新機能の追加
- 分析画面で詳細なフィードバック
- 設定画面で言語カスタマイズ

## 更新履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|----------|
| 2025-10-15 | 2.0 | ユーザーヒアリング基づく全面改訂 |
| 2025-10-15 | 2.1 | 録音画面から一覧画面への遷移を追加 |
| 2025-10-15 | 2.2 | 横画面対応、録音設定機能、リアルタイム表示機能を追加 |
| 2025-10-15 | 2.3 | 分析画面も横画面標準レイアウトに変更 |
| 2025-10-15 | 2.4 | スケール選択機能追加、繰り返し→上昇回数に変更 |
| 2025-10-15 | 2.5 | 分析画面の精度・統計情報を削除、シンプル化 |