# iOS Simulator UITest Log Capture Guide

**検証日**: 2025-10-29
**検証環境**: Xcode 16, iOS Simulator 18.5, macOS Sonoma 14.6
**ステータス**: ✅ 完全動作確認済み

## 概要

このガイドは、iOS SimulatorでのUITest実行時に、アプリケーションログを確実に取得するための実証済み手順を記載しています。

**重要な発見**: `print()`や`NSLog()`ではログアーカイブに記録されません。iOS Unified Logging System（OSLog）を使用する必要があります。

---

## 成功した方法（実証済み手順）

### 1. アプリ側: OSLogでマーカーを出力

**実装箇所**: トリガーを検証したいアクションの先頭

**実装内容**: `os.Logger`を用い、`error`レベルでマーカー行を出力

```swift
import OSLog

struct RecordingControls: View {
    // ✅ static let で宣言（SwiftUIのvalue typeで共有リソースを扱うため必須）
    private static let logger = Logger(
        subsystem: "com.kazuasato.VocalisStudio",
        category: "RecordingControls"
    )

    var body: some View {
        Button("Start") {
            // ✅ Self.logger でstaticプロパティにアクセス
            Self.logger.error("UI_TEST_MARK: StartRecordingButton action called")
            onStart()
        }
    }

    var onStart: () -> Void = {}
}
```

**重要なポイント**:
- ✅ `error`レベルは永続化されやすく、後段の収集・抽出で確実に検出できる
- ✅ `static let`でViewの生成回数に依存せず参照可能
- ✅ `Self.logger`でstaticプロパティにアクセス
- ❌ `print()`や`NSLog()`ではアーカイブに記録されない

**よくあるエラーと解決策**:

```swift
// ❌ インスタンスプロパティ - SwiftUI ViewではNG
private let logger = Logger(...)
// エラー: Static member 'logger' cannot be used on instance of type

// ❌ privacy引数を使用 - このAPIでは不要
Self.logger.error("message", privacy: .public)
// エラー: Extra argument 'privacy' in call

// ✅ 正しい実装
private static let logger = Logger(subsystem: "...", category: "...")
Self.logger.error("message")
```

### 2. シミュレータのログ永続設定（事前）

**目的**: info/debugレベルも含め、当該サブシステムのログを永続アーカイブに残す

**実行例**:

```bash
UDID="508462B0-4692-4B9B-88F9-73A63F9B91F5"  # シミュレータのUDID
BUNDLE="com.kazuasato.VocalisStudio"         # アプリのBundle ID

xcrun simctl spawn "$UDID" log config \
  --subsystem "$BUNDLE" \
  --mode "level:debug,persist:debug"
```

**設定確認**:

```bash
xcrun simctl spawn "$UDID" log config --status --subsystem "$BUNDLE"
# 出力例: Mode for 'com.kazuasato.VocalisStudio' = DEBUG / PERSIST_DEBUG
```

### 3. テスト実行（同期）

**重要**: テスト完了を待つ（パイプ末尾に`|| true`を付けない）

同時に、UTC時刻で開始・終了時刻を記録:

```bash
START=$(date -u +"%Y-%m-%d %H:%M:%S")

xcodebuild \
  -project VocalisStudio.xcodeproj \
  -scheme VocalisStudio \
  -destination "id=$UDID" \
  -resultBundlePath /tmp/TestResult.xcresult \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  -only-testing:VocalisStudioUITests/VocalisStudioUITests/testTargetPitchShouldDisappearAfterStoppingPlayback \
  test 2>&1 | tee /tmp/xc_fixed_timing.out

# ✅ || true を付けずに同期実行を保証
TEST_EXIT_CODE=$?

END=$(date -u +"%Y-%m-%d %H:%M:%S")
echo "Test finished with exit code: $TEST_EXIT_CODE"
echo "Start time (UTC): $START"
echo "End time (UTC): $END"
```

**重要なポイント**:
- ✅ `-parallel-testing-enabled NO`と`-maximum-concurrent-test-simulator-destinations 1`で並列実行を無効化
- ✅ これによりデバイスのクローン切替を回避（成功時の設定）
- ❌ `|| true`を付けるとテスト完了を待たずに次の処理に進んでしまう

**過去の失敗例**:

```bash
# ❌ 失敗した例 - || true により即座に次の処理へ進む
xcodebuild ... test 2>&1 | tee output.txt || true
xcrun simctl spawn "$UDID" log collect ...  # テスト実行前に実行されてしまう

# 結果: アーカイブ作成 15:53:30 / テスト実行 15:54:25
#      → アーカイブが空（ヘッダーのみ）
```

### 4. 事後収集（log collect）

**タイミング**: テスト完了後に実行（これが重要）

対象UDIDを一時的に起動し、直近ウィンドウのログをアーカイブ化:

```bash
# シミュレータを起動（既に起動している場合はスキップ）
xcrun simctl boot "$UDID" 2>/dev/null || echo "Already booted"
sleep 2

# ログ収集（10分間の履歴）
xcrun simctl spawn "$UDID" log collect \
  --output /tmp/sim_fixed_timing.logarchive \
  --last 10m 2>&1

# アーカイブ作成確認
if [ -d /tmp/sim_fixed_timing.logarchive ]; then
  echo "✅ Archive created successfully"
  ls -lh /tmp/sim_fixed_timing.logarchive
  du -sh /tmp/sim_fixed_timing.logarchive
else
  echo "❌ Archive was not created!"
  exit 1
fi
```

**成功時の出力例**:

```
Archive created successfully
total 3744
drwxr-xr-x   3 user  wheel    96B Oct 29 16:13 00
[... 多数のディレクトリ ...]
-rw-r--r--@  1 user  staff   1.8M Oct 29 16:13 logdata.LiveData.tracev3
186M    /tmp/sim_fixed_timing.logarchive
```

**ポイント**: テスト後に収集したため、アーカイブが空（ヘッダーのみ）になる問題を回避できました。

### 5. オフライン抽出（log show --archive）

**重要な発見**: `log show --archive`はシミュレータの起動不要で動作

収集したアーカイブから、シミュレータの起動不要で抽出:

```bash
/usr/bin/log show --archive /tmp/sim_fixed_timing.logarchive \
  --style syslog --info --debug \
  --start "$START" --end "$END" \
  --predicate 'subsystem == "com.kazuasato.VocalisStudio" OR eventMessage CONTAINS "UI_TEST_MARK"' \
  2>&1 | tee /tmp/vs_fixed_timing.log
```

**パラメータ説明**:
- `--archive`: オフライン抽出（シミュレータ起動不要）
- `--style syslog`: 読みやすいタイムスタンプ付き形式
- `--info --debug`: infoとdebugレベルも含める
- `--start/--end`: UTC時刻で期間指定
- `--predicate`: フィルタ条件（サブシステム一致 OR マーカー含む）

**成功時の実例**:

```
Timestamp                       (process)[PID]
2025-10-29 16:12:26.882136+0900  localhost VocalisStudio[10396]: (VocalisStudio.debug.dylib) [com.kazuasato.VocalisStudio:viewmodel] File logging enabled
2025-10-29 16:12:26.882382+0900  localhost VocalisStudio[10396]: (VocalisStudio.debug.dylib) [com.kazuasato.VocalisStudio:viewmodel] Log file: /Users/.../Documents/logs/vocalis_2025-10-29T07:12:26.log
2025-10-29 16:12:27.618020+0900  localhost VocalisStudio[10396]: (VocalisStudio.debug.dylib) [com.kazuasato.VocalisStudio:viewmodel] RecordingStateViewModel initialized
2025-10-29 16:12:27.618317+0900  localhost VocalisStudio[10396]: (VocalisStudio.debug.dylib) [com.kazuasato.VocalisStudio:viewmodel] RecordingViewModel initialized with child ViewModels

★ 検証対象マーカー ★
2025-10-29 16:12:33.018988+0900  localhost VocalisStudio[10396]: (VocalisStudio.debug.dylib) [com.kazuasato.VocalisStudio:RecordingControls] UI_TEST_MARK: StartRecordingButton action called

2025-10-29 16:12:33.023650+0900  localhost VocalisStudio[10396]: (VocalisStudio.debug.dylib) [com.kazuasato.VocalisStudio:viewmodel] Starting recording with settings: 5-tone scale
2025-10-29 16:12:33.033721+0900  localhost VocalisStudio[10396]: (VocalisStudio.debug.dylib) [com.kazuasato.VocalisStudio:audio] AudioSessionManager initialized
2025-10-29 16:12:33.034540+0900  localhost VocalisStudio[10396]: (VocalisStudio.debug.dylib) [com.kazuasato.VocalisStudio:audio] Audio session activated
2025-10-29 16:12:36.235913+0900  localhost VocalisStudio[10396]: (VocalisStudio.debug.dylib) [com.kazuasato.VocalisStudio:useCase] Recording denied: dailyLimitExceeded
2025-10-29 16:12:36.238694+0900  localhost VocalisStudio[10396]: (VocalisStudio.debug.dylib) [com.kazuasato.VocalisStudio:viewmodel] [RecordingStateViewModel.swift:330] executeRecording(settings:) - Error: 1日の録音回数制限に達しました
```

### 6. 検証

マーカーが抽出されたか確認:

```bash
if grep -q "UI_TEST_MARK" /tmp/vs_fixed_timing.log; then
  echo "✅ SUCCESS: Test markers found!"
  grep "UI_TEST_MARK" /tmp/vs_fixed_timing.log
elif grep -q "$BUNDLE" /tmp/vs_fixed_timing.log; then
  echo "⚠️  No UI_TEST_MARK, but VocalisStudio logs exist:"
  grep "$BUNDLE" /tmp/vs_fixed_timing.log | head -20
else
  echo "❌ No VocalisStudio logs found at all"
  echo "Total lines in extracted log: $(wc -l < /tmp/vs_fixed_timing.log)"
fi
```

---

## 成功した理由（観測に基づく事実）

### 1. OSLog（os.Logger）の使用

- ❌ `print()` / `NSLog()`ではアーカイブに載らない／載りにくい
- ✅ `os.Logger.error()`で出した明示的マーカー行は、収集→抽出で確実に取得できました

### 2. ログ永続設定の適用

```bash
log config --mode "level:debug,persist:debug"
```

- 対象サブシステムのinfo/debugを含めて永続化
- 以後の`log collect` → `log show --archive`で詳細ログも取得できました

### 3. 実行順序の是正（同期）

- `|| true`を外し、テスト完了後に`log collect`を実行
- その結果、アーカイブが空にならず、ログ行（186MB相当）が確保できました

### 4. オフライン抽出の採用

- `log show --archive`はシミュレータが起動していなくても動作
- シャットダウンタイミングに依存せず、後段で確実に抽出できました

### 5. 並列/クローンの抑止

```bash
-parallel-testing-enabled NO
-maximum-concurrent-test-simulator-destinations 1
```

- 意図外UDIDでの実行を回避
- 指定UDIDでの収集が安定しました

---

## 完全なスクリプト例

```bash
#!/usr/bin/env bash
set -euo pipefail

# Configuration
UDID="508462B0-4692-4B9B-88F9-73A63F9B91F5"
BUNDLE="com.kazuasato.VocalisStudio"
SCHEME="VocalisStudio"
PROJECT="VocalisStudio.xcodeproj"
TEST_TARGET="VocalisStudioUITests/VocalisStudioUITests/testTargetPitchShouldDisappearAfterStoppingPlayback"

# Output paths
RESULT_BUNDLE="/tmp/TestResult.xcresult"
ARCHIVE="/tmp/sim_fixed_timing.logarchive"
EXTRACTED_LOG="/tmp/vs_fixed_timing.log"
XCODE_OUTPUT="/tmp/xc_fixed_timing.out"

# Navigate to project directory
cd /Users/asatokazu/Documents/dev/mine/music/vocalis-studio/VocalisStudio

echo "=== 1) Pre-boot simulator ==="
xcrun simctl boot "$UDID" 2>/dev/null || echo "Already booted"
sleep 2

echo ""
echo "=== 2) Configure logging ==="
xcrun simctl spawn "$UDID" log config \
  --subsystem "$BUNDLE" \
  --mode "level:debug,persist:debug"

# Verify configuration
xcrun simctl spawn "$UDID" log config --status --subsystem "$BUNDLE"

echo ""
echo "=== 3) Record start time and execute test ==="
START=$(date -u +"%Y-%m-%d %H:%M:%S")
echo "Start time (UTC): $START"

# Execute test synchronously (no || true)
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "id=$UDID" \
  -resultBundlePath "$RESULT_BUNDLE" \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  -only-testing:"$TEST_TARGET" \
  -allowProvisioningUpdates \
  test 2>&1 | tee "$XCODE_OUTPUT"

TEST_EXIT_CODE=$?

END=$(date -u +"%Y-%m-%d %H:%M:%S")
echo ""
echo "Test finished with exit code: $TEST_EXIT_CODE"
echo "End time (UTC): $END"

echo ""
echo "=== 4) Now collecting logs AFTER test completion ==="
# Ensure simulator is booted for log collect
xcrun simctl boot "$UDID" 2>/dev/null || echo "Already booted"
sleep 2

echo "Collecting logs from $START to $END..."
xcrun simctl spawn "$UDID" log collect --output "$ARCHIVE" --last 10m 2>&1

if [ -d "$ARCHIVE" ]; then
  echo "✅ Archive created successfully"
  ls -lh "$ARCHIVE"
  du -sh "$ARCHIVE"
else
  echo "❌ Archive was not created!"
  exit 1
fi

echo ""
echo "=== 5) Extract logs offline ==="
/usr/bin/log show --archive "$ARCHIVE" --style syslog --info --debug \
  --start "$START" --end "$END" \
  --predicate 'subsystem == "'"$BUNDLE"'" OR eventMessage CONTAINS "UI_TEST_MARK"' \
  2>&1 | tee "$EXTRACTED_LOG"

echo ""
echo "===== VERIFICATION ====="
if grep -q "UI_TEST_MARK" "$EXTRACTED_LOG"; then
  echo "✅ SUCCESS: Test markers found!"
  grep "UI_TEST_MARK" "$EXTRACTED_LOG"
elif grep -q "$BUNDLE" "$EXTRACTED_LOG"; then
  echo "⚠️  No UI_TEST_MARK, but VocalisStudio logs exist:"
  grep "$BUNDLE" "$EXTRACTED_LOG" | head -20
else
  echo "❌ No VocalisStudio logs found at all"
  echo "Total lines in extracted log: $(wc -l < "$EXTRACTED_LOG")"
fi

echo ""
echo "=== 6) Shutdown simulator ==="
xcrun simctl shutdown "$UDID" 2>/dev/null || true

echo ""
echo "=== Complete ==="
exit 0
```

---

## トラブルシューティング

### 問題: 空のログファイル（ヘッダーのみ）

**症状**:
```
Timestamp                       (process)[PID]
```
（1行のみ、実際のログ行が0）

**原因**: タイミング問題 - ログ収集がテスト実行前に実行された

**解決策**:
1. `|| true`を削除して同期実行を保証
2. テスト完了後に`log collect`を実行

### 問題: Logger初期化エラー

**症状**:
```
Static member 'logger' cannot be used on instance of type 'RecordingControls'
```

**原因**: SwiftUI Viewはvalue type（struct）のため、インスタンスプロパティで初期化すると問題が発生

**解決策**:
```swift
// ❌ インスタンスプロパティ
private let logger = Logger(...)

// ✅ staticプロパティ
private static let logger = Logger(...)

// 使用時
Self.logger.error("...")
```

### 問題: privacy引数エラー

**症状**:
```
Extra argument 'privacy' in call
Cannot infer contextual base in reference to member 'public'
```

**解決策**:
```swift
// ❌ privacy引数を使用
logger.error("message", privacy: .public)

// ✅ privacy引数を削除
Self.logger.error("message")
```

### 問題: シミュレータクローニング

**症状**: 指定したUDIDと異なるデバイスでテストが実行される

**解決策**:
```bash
-parallel-testing-enabled NO
-maximum-concurrent-test-simulator-destinations 1
```

**注意**: `-cloned-destination-behavior never`フラグはXcode 16では利用不可

---

## ログ設定のベストプラクティス

### サブシステムとカテゴリの命名

```swift
// プロジェクト全体で統一したサブシステム
subsystem: "com.kazuasato.VocalisStudio"

// 機能別にカテゴリで分類
category: "RecordingControls"  // UI components
category: "viewmodel"           // ViewModels
category: "audio"               // Audio related
category: "useCase"             // Use cases
```

### ログレベルの使い分け

```swift
// 開発中の詳細情報（頻繁に出力される）
Self.logger.debug("Detailed information: \(value)")

// 通常フローの重要なイベント
Self.logger.info("User started recording")

// 注目すべき重要なイベント
Self.logger.notice("Configuration changed")

// エラーやテストマーカー（必ず記録される）
Self.logger.error("UI_TEST_MARK: ButtonTapped")
Self.logger.error("Operation failed: \(error)")

// 致命的エラー（システムに重大な影響）
Self.logger.fault("Critical system failure")
```

### UIテスト用ログパターン

```swift
struct RecordingControls: View {
    private static let logger = Logger(
        subsystem: "com.kazuasato.VocalisStudio",
        category: "RecordingControls"
    )

    var body: some View {
        Button("Start") {
            // テスト検証用マーカー
            Self.logger.error("UI_TEST_MARK: StartButtonTapped")

            // 状態遷移記録
            Self.logger.info("State transition: idle → recording")

            onStart()
        }
    }
}

// ViewModelでのエラーログ
class RecordingViewModel {
    private static let logger = Logger(
        subsystem: "com.kazuasato.VocalisStudio",
        category: "viewmodel"
    )

    func startRecording() async {
        do {
            try await startRecordingUseCase.execute()
        } catch {
            // ファイル名と行番号を含めたエラーログ
            Self.logger.error("[\(#file):\(#line)] \(#function) - Error: \(error)")
        }
    }
}
```

---

## 参考情報

### よく使うコマンド

```bash
# シミュレータUIDDの取得
xcrun simctl list devices | grep "iPhone"

# ログ設定の確認
xcrun simctl spawn "$UDID" log config --status --subsystem "$BUNDLE"

# ログ設定のリセット
xcrun simctl spawn "$UDID" log config --subsystem "$BUNDLE" --reset

# アーカイブ内容の確認（全ログ）
/usr/bin/log show --archive "$ARCHIVE" | head -100

# 特定カテゴリのログのみ抽出
/usr/bin/log show --archive "$ARCHIVE" \
  --predicate 'category == "RecordingControls"'

# 特定プロセスのログのみ抽出
/usr/bin/log show --archive "$ARCHIVE" \
  --predicate 'process == "VocalisStudio"'

# エラーレベルのみ抽出
/usr/bin/log show --archive "$ARCHIVE" \
  --predicate 'messageType == "Error"'
```

### トラブルシューティング早見表

| 問題 | 原因 | 解決策 |
|------|------|--------|
| 空のログファイル | タイミング問題 | `\|\| true`削除、同期実行 |
| Logger初期化エラー | value typeでのインスタンスプロパティ | `static let`使用 |
| privacy引数エラー | API誤用 | privacy引数削除 |
| クローン問題 | 並列実行 | `-parallel-testing-enabled NO` |
| マーカーが見つからない | print()使用 | `os.Logger.error()`使用 |
| アーカイブが作成されない | 起動タイミング | `simctl boot`確認、sleep追加 |

---

## 検証結果サマリー

### ✅ 動作確認済み項目

1. ✅ OSLog実装が正常動作
2. ✅ UI_TEST_MARKマーカー検出成功
3. ✅ 186MBのログアーカイブ作成
4. ✅ オフライン抽出成功
5. ✅ 時系列で正確なログ記録
6. ✅ CLI完全自動化達成

### 実証ログの要点

- **アーカイブサイズ**: 186MB
- **抽出ログ内容**:
  - File logging enabled（初期化ログ）
  - UI_TEST_MARK: StartRecordingButton action called（マーカー検出）
  - 付随するviewmodel / audio / useCaseカテゴリの詳細ログ
  - マイクロ秒単位の正確なタイムスタンプ

### 今回使用しなかったもの（不要だったもの）

- ❌ シミュレータ起動中の`simctl spawn ... log show`（オフライン抽出で代替）
- ❌ `print()` / `NSLog()`（アーカイブに記録されず）
- ❌ `--start/--end`を省いた相対抽出（正確な期間指定の方が確実）
- ❌ `-cloned-destination-behavior never`（Xcode 16では利用不可）

---

## まとめ

このガイドで説明した手順は、2025年10月29日に完全動作確認されました。

**重要なポイント**:
1. **OSLogを使用する**（`print()`ではダメ）
2. **ログ永続設定を適用する**
3. **同期実行を保証する**（`|| true`を付けない）
4. **テスト完了後にログ収集する**（タイミングが重要）
5. **オフライン抽出を活用する**（シミュレータ起動不要）

これにより、CLI環境での完全自動化されたログ取得システムが実現できます。
