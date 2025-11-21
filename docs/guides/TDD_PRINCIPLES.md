# TDD（テスト駆動開発）の本質と実践

## ドキュメント情報
- **作成日**: 2025年10月5日
- **最終更新**: 2025年10月18日
- **目的**: TDDの本質的な意義を理解し、正しく実践するための指針

## プロジェクト固有のTDD方針

### レイヤー別のテスト戦略

本プロジェクトでは、**レイヤーごとに異なるテスト戦略**を採用します。

#### 1. ドメイン層（VocalisDomain）: **完全TDD**
- **方針**: Red-Green-Refactorサイクルを厳格に適用
- **理由**:
  - ビジネスロジックの中核で最も重要
  - 外部依存がなく高速にテスト可能（0.001-0.002秒）
  - 設計の誤りが後続の全レイヤーに影響
- **実行**: `swift test` （Swift Package Manager使用）

#### 2. その他の層（Application, Infrastructure, Presentation）: **実装後テスト**
- **方針**: 実装完了後にテストを作成
- **理由**:
  - シミュレータ起動のオーバーヘッドが大きい（2-3分）
  - 外部依存（AVFoundation, SwiftUI）のセットアップが複雑
  - 開発速度を優先
- **実行**: Xcode Test Navigator または `xcodebuild test`

### テストプラン構成

```
Fast.xctestplan（開発時に常時実行）
├─ Application層テスト（Use Cases）
├─ Presentation層テスト（ViewModels）
└─ Infrastructure層テスト（軽量なもののみ）

Slow.xctestplan（統合前に確認）
├─ RealtimePitchDetectorTests（音声処理）
└─ AudioSessionManagerTests（オーディオセッション）
```

### 開発フロー

```
1. ドメイン層の実装
   → TDDで開発（Red-Green-Refactor）
   → swift test で即座に確認

2. その他の層の実装
   → 実装を完了
   → テストを作成
   → Fast.xctestplanで確認

3. 統合前
   → Slow.xctestplanで重いテストを実行
   → 全体の品質を最終確認
```

## 反省: 何を間違えたか

### 今回の誤り
1. **実装を先に書いてしまった** - ドメイン層の全コードを書いてから、後付けでテストを追加
2. **テストを実行していない** - テストファイルを作成したが、動作確認せずに完了と判断
3. **フィードバックループがない** - Red-Green-Refactorのサイクルを回していない

### なぜこれが問題なのか
- **テストの価値が失われる**: 後付けのテストは、既存コードが動くことを確認するだけで、設計を導かない
- **欠陥の見落とし**: テストを実行しないと、バグやコンパイルエラーに気づけない
- **過剰な実装**: テストがないまま実装すると、不要な機能まで作り込んでしまう
- **リファクタリングの安全網がない**: テストが通っていないので、コードを改善する根拠がない

## TDDの本質的な意義

### 1. **設計ツールとしてのテスト**

TDDは単なる品質保証の手法ではなく、**設計手法**である。

#### テストが設計を導く
```
❌ 間違った順序:
1. クラスを設計する
2. 実装する
3. テストを書く（後付け）

✅ 正しい順序:
1. 使い方（テスト）を書く
2. それを実現する最小限の実装
3. リファクタリング
```

#### 具体例
```swift
// ❌ 間違い: 実装から始める
public struct MIDINote {
    public let value: UInt8
    // ... 実装を全部書く
}

// その後でテストを書く
func testInit() {
    let note = try MIDINote(60)  // 既にあるコードを確認するだけ
}
```

```swift
// ✅ 正しい: テストから始める
func testInit_ValidValue_Success() throws {
    // まずこう使いたい、という願望を書く
    let note = try MIDINote(60)
    XCTAssertEqual(note.value, 60)
}
// → コンパイルエラー。MIDINoteが存在しない
// → では、MIDINoteをどう設計すべきか？
// → このテストが通る最小限の実装を考える

public struct MIDINote {
    public let value: UInt8
    public init(_ value: UInt8) throws {
        self.value = value  // まず最小限
    }
}
// → テストが通る（Green）
// → では、バリデーションを追加しよう（次のテストを書く）

func testInit_OutOfRange_ThrowsError() {
    XCTAssertThrowsError(try MIDINote(128))
}
// → このテストは失敗する（Red）
// → バリデーションを追加する実装
```

### 2. **即座のフィードバックループ**

TDDの核心は**数秒〜数分単位の高速フィードバックループ**を回すこと。

#### Red-Green-Refactor サイクル（1サイクル = 数分）
```
🔴 Red (30秒-1分):
   - 失敗するテストを1つ書く
   - 実行して、期待通り失敗することを確認

🟢 Green (1-2分):
   - テストを通す最小限のコード
   - 実行して、成功を確認

🔵 Refactor (1-2分):
   - 重複を除去、可読性向上
   - テストを再実行して、まだ通ることを確認

→ 次のサイクルへ（3-5分で1サイクル）
```

#### なぜ即座に実行するのか
- **コンパイルエラーに即座に気づく** - タイポや型ミスを数秒で発見
- **ロジックエラーに即座に気づく** - 期待と異なる動作をすぐ修正
- **進捗を実感できる** - Green になるたびに達成感、モチベーション維持
- **デバッグが簡単** - 変更箇所が小さいので、問題の特定が容易

### 3. **リファクタリングの安全網**

テストが通っている状態は、**リファクタリングの許可証**である。

#### テストなしのリファクタリング
```swift
// この実装、もっと良くできるかも？
// でもテストがない...
// 変更したら動かなくなるかも...
// → 怖くて触れない → 技術的負債が蓄積
```

#### テストありのリファクタリング
```swift
// テストが全部通っている
// → リファクタリングしてみよう
// → テストを再実行
// → 全部通った！安心して変更できた
```

### 4. **最小限の実装（YAGNI原則）**

テストが要求するものだけを実装する = **過剰実装を防ぐ**

#### 間違った実装
```swift
// テストなしで実装
public struct ScaleSettings {
    // 将来使うかもしれないから実装しておこう
    public var transposition: Int?
    public var customIntervals: [Int]?
    public var loopCount: Int?
    // ... 実際には使わない機能
}
```

#### TDDの実装
```swift
// テストが要求する機能だけ
public struct ScaleSettings {
    public let startNote: MIDINote
    public let endNote: MIDINote
    // テストで必要になったら追加する
}
```

## TDDの正しい実践方法

### Step 1: 最小のテストから始める

```swift
// ❌ いきなり複雑なテスト
func testGenerateScale_CompleteChromatic() {
    // 複雑すぎて、何をテストしているか不明
}

// ✅ 最小のテスト
func testInit_CreatesInstance() throws {
    let note = try MIDINote(60)
    XCTAssertNotNil(note)
}
```

### Step 2: 実行して失敗を確認（Red）

```bash
# テストを実行
xcodebuild test ...

# 結果:
# ❌ MIDINote is not defined
# → OK、期待通り失敗した
```

**この「失敗の確認」が重要**:
- テストが正しく書けているか確認
- 実装がないと本当に失敗するか確認
- テストの意図が明確になる

### Step 3: 最小限の実装で通す（Green）

```swift
// テストを通すだけの最小実装
public struct MIDINote {
    public let value: UInt8
    public init(_ value: UInt8) {
        self.value = value
    }
}
```

```bash
# テスト実行
# ✅ Test passed
# → やった！
```

### Step 4: 次のテストを書く

```swift
func testInit_OutOfRange_ThrowsError() {
    XCTAssertThrowsError(try MIDINote(128))
}
```

```bash
# 実行
# ❌ Expected error but succeeded
# → バリデーションがないから失敗する（期待通り）
```

### Step 5: 実装を追加

```swift
public init(_ value: UInt8) throws {
    guard value <= 127 else {
        throw MIDINoteError.outOfRange(value)
    }
    self.value = value
}
```

```bash
# 実行
# ✅ All tests passed
```

### Step 6: リファクタリング

```swift
// 重複があれば除去
// 可読性を向上
// → テストを再実行して、まだ通ることを確認
```

## テスト実行の重要性

### なぜ毎回実行するのか

1. **コンパイルエラーの検出**
   - タイポ、インポート忘れ、型ミス
   - 実行しないと気づかない

2. **ロジックエラーの検出**
   - 期待と異なる挙動
   - 境界値のバグ

3. **退行の防止**
   - 新しいコードが既存機能を壊していないか
   - すべてのテストを毎回実行

4. **心理的安全性**
   - テストが通っている = 安心
   - テストが通っていない = 不安
   - この感覚が重要

### 実行方法

#### IDE統合（推奨）
```
Xcode: ⌘+U
- 数秒で結果が見える
- どのテストが失敗したか一目瞭然
- 失敗したテストにジャンプできる
```

#### コマンドライン
```bash
# 特定のテストクラスのみ
xcodebuild test -only-testing:VocalisStudioTests/MIDINoteTests

# 特定のテストメソッドのみ
xcodebuild test -only-testing:VocalisStudioTests/MIDINoteTests/testInit

# 素早く実行
swift test  # Swift Package の場合
```

## TDDのリズム

### 理想的な開発の流れ（1時間の例）

```
00:00 - テスト1本目を書く（1分）
00:01 - 実行 → Red（10秒）
00:01 - 実装（2分）
00:03 - 実行 → Green（10秒）
00:03 - リファクタリング（1分）
00:04 - 実行 → Green（10秒）

00:05 - テスト2本目を書く（1分）
00:06 - 実行 → Red（10秒）
00:06 - 実装（3分）
00:09 - 実行 → Green（10秒）
...

00:60 - 1時間で10-15サイクル回せる
```

**頻繁に実行 = 小さく確実に進む**

## アンチパターン（避けるべき）

### ❌ パターン1: 実装ファーストTDD

```
1. 全部実装する
2. 後からテストを書く
3. 「TDDやってます」と言う

問題:
- テストが設計を導いていない
- 実装の確認テストになっている
- 過剰実装が発生
```

### ❌ パターン2: テストを書くが実行しない

```
1. テストを書く
2. 実装する
3. テスト実行せず次へ

問題:
- コンパイルエラーに気づかない
- ロジックエラーに気づかない
- テストが通っているか不明
```

### ❌ パターン3: 一度に大量のテストを書く

```
1. 20個のテストを一気に書く
2. 全部実装する
3. まとめて実行

問題:
- フィードバックが遅い
- どこで間違えたか特定困難
- デバッグが大変
```

### ❌ パターン4: テスト不在のリファクタリング

```
1. テストなしで実装
2. 「もっと良くできる」とリファクタリング
3. 動作確認なし

問題:
- 壊れても気づかない
- デグレードの温床
```

## 正しいTDDの実践（今後のルール）

### 絶対ルール

1. **テストを先に書く**
   - 1行でも実装コードを書く前に、テストを書く
   - 例外なし

2. **実行してRedを確認**
   - テストが失敗することを確認
   - 失敗理由が期待通りか確認

3. **最小限の実装でGreen**
   - テストを通す最小限のコード
   - 過剰実装しない

4. **テストを再実行してGreen確認**
   - 実装後、必ず実行
   - すべてのテストが通ることを確認

5. **リファクタリング後も実行**
   - コード改善後、必ず実行
   - デグレードしていないことを確認

### 開発の流れ（具体例）

#### 1機能 = 複数のテストケース

```swift
// 機能: MIDINote値オブジェクト

// Test 1: 正常系
func testInit_ValidValue_Success() { ... }
// → 実装 → Green

// Test 2: 境界値（最小）
func testInit_MinValue_Success() { ... }
// → 既存実装で通る → Green

// Test 3: 境界値（最大）
func testInit_MaxValue_Success() { ... }
// → 既存実装で通る → Green

// Test 4: 異常系
func testInit_OutOfRange_ThrowsError() { ... }
// → バリデーション追加 → Green

// Test 5: 比較機能
func testComparable() { ... }
// → Comparable実装 → Green
```

**1つずつ、確実に、小刻みに**

## TDDの効果

### 短期的効果
- コンパイルエラーに即座に気づく
- ロジックエラーを早期発見
- 実装の進捗が可視化される
- デバッグ時間が削減

### 中期的効果
- 設計が洗練される
- 過剰実装が減る
- リファクタリングが安全
- コードレビューが楽

### 長期的効果
- 技術的負債が蓄積しにくい
- 保守性が高い
- 新メンバーがコードを理解しやすい
- 仕様がテストコードに記録される

## まとめ: TDDの本質

TDDは単なる「テストを書く」手法ではなく:

1. **設計手法** - テストがAPIの使いやすさを検証
2. **フィードバックループ** - 数分単位で確実に進む
3. **リファクタリングの安全網** - 恐れずにコード改善
4. **最小限主義** - 必要なものだけ実装

**核心: 小さく、速く、確実に進むこと**

## 今後の実践方針

### Phase 1: インフラ層（次のステップ）

```
1. ScalePlayerのテストを1つ書く
2. 実行 → Red
3. 最小実装
4. 実行 → Green
5. 次のテストへ

（実装全体を書いてからテストを書く、は絶対にしない）
```

### Phase 2: 実行を習慣化

- テストを書いたら即実行（10秒以内）
- 実装したら即実行（10秒以内）
- 1サイクル5分以内を目指す

### Phase 3: テスト実行結果の確認

- 失敗理由を読む
- 成功を喜ぶ
- カバレッジを確認

## 参考: TDDの名言

> "Write a test, watch it fail, make it pass, refactor, repeat."
> — Kent Beck（TDD提唱者）

> "Code without tests is broken by design."
> — Michael Feathers

> "The act of writing a unit test is more an act of design than of verification."
> — Robert C. Martin

## 振り返りチェックリスト

毎回の開発セッション後、以下を確認:

- [ ] テストを先に書いたか？
- [ ] Redを確認したか？
- [ ] Greenを確認したか？
- [ ] リファクタリング後にテスト実行したか？
- [ ] サイクル時間は5分以内だったか？
- [ ] すべてのテストが通っているか？

**1つでもNoなら、TDDができていない**
