# Vocalis Studio - UIコンポーネント仕様書

## 1. 概要

本書は、Vocalis StudioアプリのUIコンポーネントの詳細仕様を定義する。各コンポーネントの構造、振る舞い、SwiftUI実装方法を記載する。

## 2. コンポーネント階層

```
VocalisStudio
├── Core Components（基礎コンポーネント）
│   ├── VocalisButton
│   ├── VocalisCard
│   ├── VocalisProgressRing
│   └── VocalisWaveform
├── Feature Components（機能別コンポーネント）
│   ├── RecordingControl
│   ├── ScaleVisualizer
│   ├── CountdownDisplay
│   └── RecordingCard
└── Layout Components（レイアウト）
    ├── VocalisNavigationBar
    ├── VocalisTabBar
    └── VocalisContainer
```

## 3. Core Components

### 3.1 VocalisButton

#### 概要
アプリ全体で使用される統一されたボタンコンポーネント

#### 仕様
```swift
enum VocalisButtonStyle {
    case primary    // メインアクション用
    case secondary  // サブアクション用
    case danger     // 削除等の破壊的操作
    case ghost      // 背景なし、テキストのみ
}

enum VocalisButtonSize {
    case large      // 高さ56pt
    case medium     // 高さ44pt
    case small      // 高さ32pt
    case micro      // 高さ24pt
}

struct VocalisButton: View {
    let title: String
    let icon: String?
    let style: VocalisButtonStyle
    let size: VocalisButtonSize
    let isLoading: Bool
    let action: () -> Void
}
```

#### デザイン仕様
- **Primary**:
  - 背景: #6C5CE7
  - テキスト: 白
  - 押下時: 明度-10%

- **Secondary**:
  - 背景: #E9ECEF（ライト）/ #3E4148（ダーク）
  - テキスト: #2D3436（ライト）/ #FFFFFF（ダーク）

- **Danger**:
  - 背景: #FF6B6B
  - テキスト: 白

#### アニメーション
- タップ: scaleEffect(0.95)
- duration: 0.1秒
- ローディング時: 回転するプログレスインジケーター

### 3.2 VocalisCard

#### 概要
情報をグループ化して表示するカードコンポーネント

#### 仕様
```swift
struct VocalisCard: View {
    let title: String?
    let subtitle: String?
    let content: AnyView
    let style: CardStyle
    let padding: EdgeInsets
}

enum CardStyle {
    case elevated   // 影あり
    case outlined   // 枠線あり
    case flat       // 背景のみ
}
```

#### デザイン仕様
- **背景**: #FFFFFF（ライト）/ #2C2F36（ダーク）
- **影**: 0 2px 8px rgba(0,0,0,0.1)
- **枠線**: 1pt, #E9ECEF
- **角丸**: 12pt

### 3.3 VocalisProgressRing

#### 概要
円形のプログレスインジケーター

#### 仕様
```swift
struct VocalisProgressRing: View {
    @Binding var progress: Double // 0.0〜1.0
    let size: CGFloat
    let lineWidth: CGFloat
    let primaryColor: Color
    let secondaryColor: Color
    let showPercentage: Bool
}
```

#### デザイン仕様
- **サイズ**: 60〜200pt（可変）
- **線の太さ**: サイズの1/10
- **背景色**: グレー（opacity: 0.2）
- **前景色**: グラデーション

#### アニメーション
- プログレス変更: スムーズアニメーション（0.3秒）
- 完了時: パルスエフェクト

### 3.4 VocalisWaveform

#### 概要
音声波形を表示するビジュアライザー

#### 仕様
```swift
struct VocalisWaveform: View {
    let audioLevels: [Float] // -1.0〜1.0
    let style: WaveformStyle
    let color: Color
    let isAnimating: Bool
}

enum WaveformStyle {
    case bars       // 棒グラフスタイル
    case line       // 波形ラインスタイル
    case mirror     // 上下対称スタイル
}
```

#### デザイン仕様
- **バー数**: 50〜100本
- **更新頻度**: 60fps
- **色**: グラデーション対応

## 4. Feature Components

### 4.1 RecordingControl

#### 概要
録音の開始/停止を制御するメインコントロール

#### 構成要素
```swift
struct RecordingControl: View {
    @Binding var state: RecordingState
    let onStart: () -> Void
    let onStop: () -> Void
    let onCancel: () -> Void
}

enum RecordingState {
    case idle
    case preparing
    case recording
}
```

#### デザイン仕様
- **アイドル状態**:
  - 円形ボタン（直径: 80pt）
  - 背景: #EE5A6F
  - アイコン: マイク（白、28pt）

- **録音中**:
  - 内側: 停止ボタン（正方形）
  - 外側: プログレスリング
  - パルスアニメーション

#### インタラクション
- **長押し**: 3秒後に自動録音開始
- **ダブルタップ**: 即座に録音開始（カウントダウンスキップ）

### 4.2 ScaleVisualizer

#### 概要
スケールの音階を視覚的に表示

#### 仕様
```swift
struct ScaleVisualizer: View {
    let notes: [MIDINote]
    let currentNote: MIDINote?
    let tempo: Int
    let style: VisualizerStyle
}

enum VisualizerStyle {
    case piano      // ピアノ鍵盤風
    case circles    // 円形配置
    case linear     // 横一列
}
```

#### デザイン仕様
- **ピアノスタイル**:
  - 白鍵: 幅40pt、高さ120pt
  - 黒鍵: 幅24pt、高さ80pt
  - アクティブ時: 色変化＋押下アニメーション

- **サークルスタイル**:
  - 円形配置（半径: 100pt）
  - 各音: 直径30ptの円
  - アクティブ時: スケール1.5倍

### 4.3 CountdownDisplay

#### 概要
録音開始前のカウントダウン表示

#### 仕様
```swift
struct CountdownDisplay: View {
    @Binding var count: Int
    let style: CountdownStyle
    let onComplete: () -> Void
}

enum CountdownStyle {
    case numeric    // 数字表示
    case circular   // 円形プログレス
    case dots       // ドット表示
}
```

#### デザイン仕様
- **数字スタイル**:
  - フォント: SF Pro Rounded 60pt
  - アニメーション: フェードイン＋スケール

- **円形スタイル**:
  - 直径: 120pt
  - ストローク: 8pt
  - 色: プライマリカラー

### 4.4 RecordingCard

#### 概要
録音項目を表示するリストカード

#### 仕様
```swift
struct RecordingCard: View {
    let recording: Recording
    let isPlaying: Bool
    let isSelected: Bool
    let onPlay: () -> Void
    let onDelete: () -> Void
    let onFavorite: () -> Void
}
```

#### レイアウト
```
┌─────────────────────────────────┐
│ [再生]  2025/10/14 15:30   [★]  │
│         5-tone Scale C Major     │
│ ━━━━━━━━━━━━━━━━━ 2:30/5:00     │
│ BPM:120  Quality:★★★★☆         │
└─────────────────────────────────┘
```

#### インタラクション
- **スワイプ右**: お気に入り追加（星アイコンアニメーション）
- **スワイプ左**: 削除オプション表示
- **タップ**: 再生/停止

## 5. Layout Components

### 5.1 VocalisNavigationBar

#### 概要
カスタムナビゲーションバー

#### 仕様
```swift
struct VocalisNavigationBar: View {
    let title: String
    let leftItem: NavigationItem?
    let rightItem: NavigationItem?
    let style: NavigationBarStyle
}

struct NavigationItem {
    let icon: String
    let action: () -> Void
}
```

#### デザイン仕様
- **高さ**: 44pt（標準）+ Safe Area
- **背景**: ブラー効果（.ultraThinMaterial）
- **タイトル**: センター配置、17pt Semibold

### 5.2 VocalisTabBar

#### 概要
下部タブバー（将来的な機能拡張用）

#### 仕様
```swift
struct VocalisTabBar: View {
    @Binding var selectedTab: Int
    let items: [TabItem]
}

struct TabItem {
    let title: String
    let icon: String
    let badge: Int?
}
```

#### デザイン仕様
- **高さ**: 49pt + Safe Area
- **アイテム数**: 2〜5個
- **選択時**: アイコン色変更＋バウンスアニメーション

### 5.3 VocalisContainer

#### 概要
画面全体のレイアウトコンテナ

#### 仕様
```swift
struct VocalisContainer<Content: View>: View {
    let content: Content
    let background: BackgroundStyle
    let safeAreaEdges: Edge.Set
}

enum BackgroundStyle {
    case solid(Color)
    case gradient([Color])
    case image(String)
}
```

## 6. アニメーション仕様

### 6.1 標準トランジション
```swift
extension AnyTransition {
    static var vocalisSlide: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    static var vocalisPop: AnyTransition {
        .scale.combined(with: .opacity)
    }
}
```

### 6.2 タイミング関数
```swift
extension Animation {
    static var vocalisEase: Animation {
        .timingCurve(0.4, 0.0, 0.2, 1.0, duration: 0.3)
    }

    static var vocalisBounce: Animation {
        .interpolatingSpring(stiffness: 300, damping: 20)
    }
}
```

## 7. カスタムモディファイア

### 7.1 影効果
```swift
extension View {
    func vocalisShadow(_ style: ShadowStyle) -> some View {
        modifier(VocalisShadowModifier(style: style))
    }
}

enum ShadowStyle {
    case small  // 0 1px 3px
    case medium // 0 4px 6px
    case large  // 0 10px 15px
}
```

### 7.2 ハプティックフィードバック
```swift
extension View {
    func vocalisHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) -> some View {
        self.onTapGesture {
            let impactFeedback = UIImpactFeedbackGenerator(style: style)
            impactFeedback.impactOccurred()
        }
    }
}
```

## 8. カラーテーマ管理

### 8.1 テーマプロトコル
```swift
protocol VocalisTheme {
    var primaryColor: Color { get }
    var secondaryColor: Color { get }
    var backgroundColor: Color { get }
    var surfaceColor: Color { get }
    var textPrimaryColor: Color { get }
    var textSecondaryColor: Color { get }
    var errorColor: Color { get }
    var successColor: Color { get }
}
```

### 8.2 環境値
```swift
struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: VocalisTheme = LightTheme()
}

extension EnvironmentValues {
    var vocalisTheme: VocalisTheme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}
```

## 9. アクセシビリティ

### 9.1 ラベル定義
```swift
extension View {
    func vocalisAccessibility(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
    }
}
```

### 9.2 フォーカス管理
```swift
extension View {
    func vocalisFocusable(
        _ condition: Bool = true,
        onFocusChange: @escaping (Bool) -> Void = { _ in }
    ) -> some View {
        self
            .focusable(condition)
            .onFocusChange(onFocusChange)
    }
}
```

## 10. 実装例

### 10.1 録音ボタンの実装
```swift
struct ContentView: View {
    @State private var isRecording = false

    var body: some View {
        VocalisContainer(
            content: {
                RecordingControl(
                    state: .constant(isRecording ? .recording : .idle),
                    onStart: { startRecording() },
                    onStop: { stopRecording() },
                    onCancel: { cancelRecording() }
                )
                .vocalisShadow(.large)
                .vocalisHaptic(.medium)
            },
            background: .gradient([.purple, .blue]),
            safeAreaEdges: .all
        )
    }
}
```

### 10.2 録音カードリストの実装
```swift
struct RecordingListView: View {
    @State private var recordings: [Recording] = []
    @State private var playingId: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(recordings) { recording in
                    RecordingCard(
                        recording: recording,
                        isPlaying: playingId == recording.id,
                        isSelected: false,
                        onPlay: { togglePlay(recording) },
                        onDelete: { delete(recording) },
                        onFavorite: { toggleFavorite(recording) }
                    )
                    .transition(.vocalisSlide)
                }
            }
            .padding()
        }
    }
}
```

## 11. パフォーマンス最適化

### 11.1 メモリ管理
- LazyVStackの使用でメモリ効率化
- 画像キャッシュの実装
- 不要なビュー再レンダリングの防止

### 11.2 アニメーション最適化
- GPUレンダリングの活用
- 60fps維持のための軽量化
- 必要に応じた簡易モード

## 12. テスト戦略

### 12.1 ユニットテスト
- 各コンポーネントの表示確認
- プロパティ変更時の挙動確認
- アクセシビリティ属性の検証

### 12.2 スナップショットテスト
- 各状態での表示確認
- ダークモード/ライトモードの確認
- 異なるデバイスサイズでの表示

### 12.3 UIテスト
- ユーザーインタラクションのテスト
- アニメーションの動作確認
- アクセシビリティ機能のテスト

## 更新履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|----------|
| 2025-10-15 | 1.0 | 初版作成 |