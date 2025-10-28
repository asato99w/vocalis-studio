# Code Smells Reference - Martin Fowler

## 概要

「Code Smells（コードの不吉な匂い）」は、Martin Fowlerの著書「Refactoring: Improving the Design of Existing Code」で紹介された概念です。コードの表面的な特徴から、深層的な設計問題を示唆する「匂い」を嗅ぎ取ることで、リファクタリングの必要性を判断します。

**重要**: Code Smellは必ずしも「バグ」ではありません。しかし、将来的なバグの温床となったり、保守性を低下させたり、理解を困難にする可能性があります。

## Vocalis Studioで検出されたCode Smells

### 1. Divergent Change（変更の分散）

**定義**: 1つのクラスが異なる理由で頻繁に変更される

**Vocalis Studioでの例**:
- `RecordingStateViewModel`: 録音制御とスケール再生の両方の理由で変更される
- `PitchDetectionViewModel`: ピッチ検出とスケール進行監視の両方の理由で変更される

**問題点**:
- Single Responsibility Principle（単一責任の原則）の違反
- 変更の影響範囲が不明確
- テストが困難

**リファクタリング手法**:
- Extract Class（クラスの抽出）
- Extract Method（メソッドの抽出）

**推奨アクション**: ScalePlaybackCoordinatorを導入し、スケール再生の責任を分離

---

### 2. Duplicated Code（重複コード）

**定義**: 同じコード構造が複数箇所に存在する

**Vocalis Studioでの例**:
```swift
// RecordingStateViewModel.swift (line 224-225)
let scaleElements = settings.generateScaleWithKeyChange()
try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)

// PitchDetectionViewModel.swift (line 67-68)
let scaleElements = settings.generateScaleWithKeyChange()
try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)
```

**問題点**:
- 修正が必要な場合、すべての箇所を変更する必要がある
- 変更漏れによるバグのリスク
- コードの保守性低下

**リファクタリング手法**:
- Extract Method（メソッドの抽出）
- Pull Up Method（メソッドの引き上げ）

**推奨アクション**: `loadScaleForPlayback(settings:)` メソッドを共通化

---

### 3. Long Method（長いメソッド）

**定義**: メソッドが長すぎて理解が困難

**Vocalis Studioでの例**:
```swift
// RecordingStateViewModel.swift: playLastRecording() - 42行
public func playLastRecording() async {
    // 42 lines of code with multiple responsibilities
}
```

**問題点**:
- メソッドの意図が不明確
- テストが困難
- 再利用が困難

**リファクタリング手法**:
- Extract Method（メソッドの抽出）
- Decompose Conditional（条件の分解）

**推奨アクション**:
- `loadScaleForPlayback(settings:)` を抽出
- `startBackgroundScalePlayback(elements:tempo:)` を抽出
- `playRecordingAudio(url:)` を抽出

---

### 4. Temporal Coupling（時間的結合）

**定義**: コードの実行順序が暗黙的に依存している

**Vocalis Studioでの例**:
```swift
// RecordingStateViewModel.stopPlayback() - scalePlayer.stop()の呼び出しがない
public func stopPlayback() async {
    await audioPlayer.stop()
    isPlayingRecording = false
    // scalePlayer.stop() の呼び出しが欠落
}

// PitchDetectionViewModel.stopTargetPitchMonitoring() - 実行順序が重要
public func stopTargetPitchMonitoring() async {
    progressMonitorTask?.cancel()  // 1. タスクをキャンセル
    _ = await progressMonitorTask?.value  // 2. 完了を待つ
    progressMonitorTask = nil  // 3. nilにする
    targetPitch = nil  // 4. 状態をクリア
}
```

**問題点**:
- 実行順序を変更するとバグが発生
- 非同期コードでレースコンディションのリスク
- テストが非決定的

**リファクタリング手法**:
- Introduce Explaining Variable（説明用変数の導入）
- Replace Temp with Query（一時変数のクエリへの置き換え）
- State Machine Pattern（状態機械パターン）

**推奨アクション**: 状態機械パターンで明示的な状態遷移を管理

---

### 5. Feature Envy（機能への嫉妬）

**定義**: あるメソッドが自分のクラスよりも他のクラスのデータに興味を持っている

**Vocalis Studioでの例**:
```swift
// PitchDetectionViewModel が scalePlayer の内部状態に強く依存
public func startTargetPitchMonitoring(settings: ScaleSettings) async throws {
    try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)

    // scalePlayer.currentScaleElement に頻繁にアクセス
    if let currentElement = self.scalePlayer.currentScaleElement {
        await self.updateTargetPitchFromScaleElement(currentElement)
    }
}
```

**問題点**:
- クラス間の結合度が高い
- 変更の影響が予測困難
- カプセル化の破壊

**リファクタリング手法**:
- Move Method（メソッドの移動）
- Extract Method（メソッドの抽出）

**推奨アクション**: ScalePlayerが進行状態を通知する仕組みを導入

---

### 6. Data Clumps（データの群れ）

**定義**: 同じデータ項目が複数箇所で一緒に出現する

**Vocalis Studioでの例**:
```swift
// settings, scaleElements, tempo が常に一緒に渡される
try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)
```

**問題点**:
- パラメータリストが長くなる
- データの関係性が不明確
- 変更時に複数箇所を修正

**リファクタリング手法**:
- Extract Class（クラスの抽出）
- Introduce Parameter Object（パラメータオブジェクトの導入）

**推奨アクション**: `ScalePlaybackConfiguration` オブジェクトを導入

---

### 7. Middle Man（仲介者）

**定義**: クラスが他のクラスへの単純な委譲ばかりしている

**Vocalis Studioでの例**:
```swift
// PitchDetectionViewModel の多くのメソッドが scalePlayer への委譲
public func startTargetPitchMonitoring(settings: ScaleSettings) async throws {
    let scaleElements = settings.generateScaleWithKeyChange()
    try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)
    // ... 独自のロジックは少ない
}
```

**問題点**:
- 不要な間接層
- コードの複雑性増加
- 責任の所在が不明確

**リファクタリング手法**:
- Remove Middle Man（仲介者の除去）
- Inline Method（メソッドのインライン化）

**推奨アクション**: PitchDetectionViewModelの責任を再検討し、必要なら統合

---

### 8. Shotgun Surgery（散弾銃手術）

**定義**: 1つの変更のために多くのクラスを修正する必要がある

**Vocalis Studioでの例**:
スケール再生のロジックを変更する場合:
- `RecordingStateViewModel.playLastRecording()` を修正
- `PitchDetectionViewModel.startTargetPitchMonitoring()` を修正
- `AVAudioEngineScalePlayer` を修正
- テストコードも複数箇所修正

**問題点**:
- 変更コストが高い
- 変更漏れのリスク
- 責任の分散

**リファクタリング手法**:
- Move Method（メソッドの移動）
- Move Field（フィールドの移動）
- Inline Class（クラスのインライン化）

**推奨アクション**: ScalePlaybackCoordinatorに責任を集約

---

### 9. Primitive Obsession（基本型への執着）

**定義**: ドメイン概念を基本型で表現している

**Vocalis Studioでの例**:
```swift
// AVAudioEngineScalePlayer.swift
private var _isPlaying: Bool = false  // 再生状態をBoolで表現
private var _currentNoteIndex: Int = -1  // インデックスをIntで表現
```

**問題点**:
- ドメイン知識がコードに埋め込まれない
- 不正な状態を防げない
- 型安全性の欠如

**リファクタリング手法**:
- Replace Data Value with Object（値オブジェクトへの置き換え）
- Replace Type Code with Class（型コードのクラスへの置き換え）
- Extract Class（クラスの抽出）

**推奨アクション**:
```swift
enum PlaybackState {
    case idle
    case playing(currentIndex: Int)
    case paused(currentIndex: Int)
}
```

---

### 10. Comments（コメント）

**定義**: コメントが多いのは、コードが複雑すぎる証拠

**Vocalis Studioでの例**:
```swift
// RecordingStateViewModel.swift (line 223)
// If we have scale settings, play muted scale for target pitch tracking

// AVAudioEngineScalePlayer.swift (line 34)
// Returns nil when stopped
```

**問題点**:
- コメントがコードと乖離する可能性
- コードの意図が不明確
- リファクタリングの必要性を示唆

**リファクタリング手法**:
- Extract Method（メソッドの抽出）
- Introduce Assertion（アサーションの導入）
- Rename Method（メソッドのリネーム）

**推奨アクション**: メソッド名や変数名で意図を表現し、コメントを削減

---

## Martin Fowlerのリファクタリングカタログ

### よく使われるリファクタリング手法

#### 1. Extract Method（メソッドの抽出）
**目的**: 長いメソッドを小さな意味のある単位に分割

**Before**:
```swift
func complexMethod() {
    // 10 lines of validation
    // 20 lines of business logic
    // 10 lines of cleanup
}
```

**After**:
```swift
func complexMethod() {
    validate()
    processBusinessLogic()
    cleanup()
}

private func validate() { /* ... */ }
private func processBusinessLogic() { /* ... */ }
private func cleanup() { /* ... */ }
```

---

#### 2. Move Method（メソッドの移動）
**目的**: メソッドを最も適切なクラスに配置

**Before**:
```swift
class ViewModelA {
    func operateOnClassB(b: ClassB) {
        // b のデータばかり使っている
    }
}
```

**After**:
```swift
class ClassB {
    func operate() {
        // このクラスのデータを直接使える
    }
}
```

---

#### 3. Replace Temp with Query（一時変数のクエリへの置き換え）
**目的**: 一時変数を計算メソッドに置き換える

**Before**:
```swift
let basePrice = quantity * itemPrice
let discount = basePrice * 0.1
return basePrice - discount
```

**After**:
```swift
return basePrice() - discount()

func basePrice() -> Double { quantity * itemPrice }
func discount() -> Double { basePrice() * 0.1 }
```

---

#### 4. Introduce Parameter Object（パラメータオブジェクトの導入）
**目的**: 関連するパラメータをオブジェクトにまとめる

**Before**:
```swift
func load(elements: [ScaleElement], tempo: Double, settings: ScaleSettings)
```

**After**:
```swift
struct ScalePlaybackConfiguration {
    let elements: [ScaleElement]
    let tempo: Double
    let settings: ScaleSettings
}

func load(configuration: ScalePlaybackConfiguration)
```

---

#### 5. Replace Conditional with Polymorphism（条件分岐のポリモーフィズムへの置き換え）
**目的**: switch/if-else を継承とポリモーフィズムで置き換える

**Before**:
```swift
func handle(element: ScaleElement) {
    switch element {
    case .scaleNote: // ...
    case .chordLong: // ...
    case .chordShort: // ...
    case .silence: // ...
    }
}
```

**After**:
```swift
protocol ScaleElementHandler {
    func handle()
}

class ScaleNoteHandler: ScaleElementHandler { /* ... */ }
class ChordLongHandler: ScaleElementHandler { /* ... */ }
```

---

## リファクタリングの原則

### 1. 小さなステップで進める
一度に大きな変更をせず、小さなリファクタリングを積み重ねる

### 2. テストを常に実行
各リファクタリング後に必ずテストを実行し、動作が変わっていないことを確認

### 3. Red-Green-Refactor
TDDのリファクタリングフェーズでコードの品質を改善

### 4. 2つの帽子
- **機能追加の帽子**: 新機能を追加、既存コードは変更しない
- **リファクタリングの帽子**: コード構造を改善、機能は変更しない
- 同時に両方の帽子をかぶらない

### 5. リファクタリングのタイミング
- **準備のためのリファクタリング**: 新機能を追加しやすくする
- **理解のためのリファクタリング**: コードを理解するために構造を明確にする
- **ゴミ拾いリファクタリング**: コードレビュー中に小さな改善を積み重ねる

---

## Vocalis Studioへの適用

### 短期的アクション（Phase 1）
1. **Extract Method**: `playLastRecording()` を小さなメソッドに分割
2. **Move Method**: スケール読み込みロジックを適切な場所に移動
3. **Introduce Parameter Object**: `ScalePlaybackConfiguration` を導入

### 中期的アクション（Phase 2）
1. **Extract Class**: `ScalePlaybackCoordinator` を抽出
2. **Move Method**: スケール関連メソッドをCoordinatorに移動
3. **Replace Temp with Query**: 状態フラグをクエリメソッドに置き換え

### 長期的アクション（Phase 3）
1. **Replace Type Code with State/Strategy**: State Machineパターンを導入
2. **Replace Conditional with Polymorphism**: ScaleElement処理をポリモーフィックに
3. **Introduce Gateway**: 非同期処理の境界を明確化

---

## 参考文献

- **Refactoring: Improving the Design of Existing Code (2nd Edition)** - Martin Fowler
  - Code Smellsカタログの原典
  - リファクタリング手法の詳細な解説

- **Refactoring to Patterns** - Joshua Kerievsky
  - リファクタリングとデザインパターンの統合

- **Working Effectively with Legacy Code** - Michael Feathers
  - テストのないコードのリファクタリング手法

---

## まとめ

Code Smellsは「問題の兆候」であり、リファクタリングの機会を示しています。Vocalis Studioプロジェクトで検出されたCode Smellsは、主に以下のカテゴリに分類されます：

1. **責任の問題**: Divergent Change, Feature Envy, Shotgun Surgery
2. **重複の問題**: Duplicated Code, Data Clumps
3. **複雑性の問題**: Long Method, Middle Man, Temporal Coupling
4. **抽象化の問題**: Primitive Obsession

これらのCode Smellsに対して、段階的なリファクタリングを適用することで、コードの保守性、テスタビリティ、理解しやすさを改善できます。

**重要**: リファクタリングは「動作を変えずに構造を改善する」ことです。各リファクタリングステップの後に必ずテストを実行し、デグレードがないことを確認してください。
