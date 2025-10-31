# UIテストカバレッジ向上計画

**作成日**: 2025-10-31
**対象**: VocalisStudioUITests

---

## 現在のカバレッジ状況

### 既存テスト（1件）

✅ **testTargetPitchShouldDisappearAfterStoppingPlayback**
- **カバー範囲**: 録音→再生→停止の基本フロー、ターゲットピッチ表示バグの回帰テスト
- **実行時間**: ~23秒
- **状態**: PASSED

### カバーされていない主要機能

1. **ナビゲーション**: Home → Recording → RecordingList → Analysis → Settings
2. **録音設定の変更**: スケール設定（開始音、終了音、テンポ）
3. **録音リストの管理**: 一覧表示、削除、個別再生
4. **サブスクリプション管理**: プラン確認、制限の動作確認
5. **エラーハンドリング**: 録音時間制限、ストレージ不足など

---

## 優先度別UIテストシナリオ

### 🔴 優先度：高（コア機能）

#### 1. testBasicRecordingFlow
**目的**: 基本的な録音フローの動作確認

**テストステップ**:
1. Home画面からRecording画面へ遷移
2. Start Recordingボタンをタップ
3. カウントダウン待機（3秒）
4. 録音中の状態確認（StopRecordingButtonが表示）
5. Stop Recordingボタンをタップ
6. 録音完了後の状態確認（Play Last Recordingボタンが表示）

**検証ポイント**:
- ✅ 画面遷移が正常に動作
- ✅ 各ボタンが適切なタイミングで表示/非表示
- ✅ 録音開始から完了までエラーなし

**所要時間（予想）**: ~10秒

---

#### 2. testRecordingListNavigation
**目的**: 録音リスト画面へのナビゲーションと一覧表示確認

**テストステップ**:
1. 録音を1件実行
2. Recording List画面へ遷移（タブバーまたはナビゲーション）
3. 録音が一覧に表示されることを確認
4. 録音項目をタップして詳細表示
5. 戻るボタンで一覧に戻る

**検証ポイント**:
- ✅ Recording List画面へのナビゲーション成功
- ✅ 録音項目が一覧に表示される
- ✅ 詳細画面への遷移と戻る動作

**所要時間（予想）**: ~15秒

**必要なAccessibility Identifier**:
- `RecordingListTab` - タブバーのRecording Listタブ
- `RecordingListItem_{index}` - 録音項目
- `BackButton` - ナビゲーションバーの戻るボタン

---

#### 3. testDeleteRecording
**目的**: 録音削除機能の動作確認

**テストステップ**:
1. 録音を1件実行
2. Recording List画面へ遷移
3. 録音項目を選択
4. 削除ボタンをタップ
5. 確認ダイアログで削除を実行
6. 録音がリストから消えることを確認

**検証ポイント**:
- ✅ 削除ボタンが表示される
- ✅ 確認ダイアログが表示される
- ✅ 削除実行後、リストから項目が消える
- ✅ 削除後のリスト状態が正常

**所要時間（予想）**: ~15秒

**必要なAccessibility Identifier**:
- `DeleteRecordingButton` - 削除ボタン
- `DeleteConfirmButton` - 確認ダイアログの削除ボタン
- `DeleteCancelButton` - 確認ダイアログのキャンセルボタン

---

#### 4. testPlaybackFullCompletion
**目的**: 録音の完全再生（自然終了まで）の動作確認

**テストステップ**:
1. 録音を1件実行（短時間: ~2秒）
2. Play Last Recordingボタンをタップ
3. 再生が開始されることを確認
4. 再生が自然終了するまで待機（~2秒 + 余裕1秒）
5. 再生完了後、ボタンが元の状態に戻ることを確認

**検証ポイント**:
- ✅ 再生開始時にStopPlaybackButtonが表示
- ✅ 再生中のUI状態が正常
- ✅ 再生完了後、Play Last Recordingボタンに戻る
- ✅ ターゲットピッチが正しくクリアされる

**所要時間（予想）**: ~8秒

---

### 🟡 優先度：中（重要な設定・機能）

#### 5. testChangeScaleSettings
**目的**: スケール設定変更機能の動作確認

**テストステップ**:
1. Settings画面へ遷移
2. スケール設定セクションを開く
3. 開始音を変更（例: C4 → D4）
4. 終了音を変更（例: C5 → D5）
5. テンポを変更（例: 60 BPM → 80 BPM）
6. 設定を保存
7. Recording画面に戻って録音
8. 変更したスケールで録音されることを確認（スクリーンショット）

**検証ポイント**:
- ✅ Settings画面への遷移成功
- ✅ 各設定項目の変更が可能
- ✅ 設定保存が正常に動作
- ✅ 変更後の録音で新しい設定が反映される

**所要時間（予想）**: ~20秒

**必要なAccessibility Identifier**:
- `SettingsTab` - タブバーのSettingsタブ
- `StartNotePicker` - 開始音ピッカー
- `EndNotePicker` - 終了音ピッカー
- `TempoPicker` - テンポピッカー
- `SaveSettingsButton` - 設定保存ボタン

---

#### 6. testFreeTierRecordingLimit
**目的**: Free Tierの録音時間制限（30秒）の動作確認

**テストステップ**:
1. Free Tierの状態を確認（デバッグ設定で強制的にFree Tier）
2. Recording画面で録音開始
3. カウントダウン完了後、30秒間待機
4. 制限時間到達で自動停止を確認
5. エラーメッセージ表示を確認

**検証ポイント**:
- ✅ 30秒で自動停止
- ✅ エラーメッセージが表示される
- ✅ 録音が保存されない（または制限時間分のみ保存）

**所要時間（予想）**: ~35秒

**必要な機能**:
- テスト用のサブスクリプションティア強制設定
- Launch Argumentsで`-UITestFreeTier`を設定

---

#### 7. testMultipleRecordings
**目的**: 複数録音の実行と管理の確認

**テストステップ**:
1. 1つ目の録音を実行（~2秒）
2. Recording画面に戻る
3. 2つ目の録音を実行（~2秒）
4. Recording List画面へ遷移
5. 2つの録音が表示されることを確認
6. それぞれの録音を個別に再生できることを確認

**検証ポイント**:
- ✅ 複数録音が正常に保存される
- ✅ Recording Listに複数項目が表示される
- ✅ 各録音を個別に再生可能
- ✅ 録音の順序が正しい（最新が上）

**所要時間（予想）**: ~20秒

---

#### 8. testFullNavigationFlow
**目的**: アプリ全体のナビゲーションフローの確認

**テストステップ**:
1. Home画面からスタート
2. Recording画面へ遷移
3. Recording List画面へ遷移
4. Analysis画面へ遷移（タブバー）
5. Settings画面へ遷移（タブバー）
6. 各画面で基本要素が表示されることを確認
7. 戻るボタン・タブバーでのナビゲーション確認

**検証ポイント**:
- ✅ 全画面への遷移が成功
- ✅ 各画面の基本要素が表示される
- ✅ タブバーでの切り替えが正常
- ✅ ナビゲーションバーの戻るボタンが正常動作

**所要時間（予想）**: ~15秒

**必要なAccessibility Identifier**:
- `HomeTab` - タブバーのHomeタブ
- `RecordingTab` - タブバーのRecordingタブ
- `RecordingListTab` - タブバーのRecording Listタブ
- `AnalysisTab` - タブバーのAnalysisタブ
- `SettingsTab` - タブバーのSettingsタブ

---

#### 9. testAnalysisViewDisplay ⭐ 分析機能テスト
**目的**: 録音分析画面の表示と基本機能の確認

**テストステップ**:
1. 録音を1件実行（~2秒）
2. Recording List画面へ遷移
3. 録音項目をタップ
4. Analysis画面が表示されることを確認
5. スペクトログラムの表示を確認
6. ピッチグラフの表示を確認
7. 再生コントロール（Play/Pauseボタン）の存在確認
8. 再生ボタンをタップ
9. 再生中の状態を確認（Pauseボタンに変化）
10. Pauseボタンをタップ
11. 再生停止の確認

**検証ポイント**:
- ✅ Analysis画面への遷移が成功
- ✅ 録音情報パネルが表示される（日時、長さ、スケール設定）
- ✅ スペクトログラム領域が表示される
- ✅ ピッチグラフ領域が表示される
- ✅ 再生コントロールが正常動作（Play → Pause → Stop）
- ✅ ローディング状態が適切に表示される
- ✅ エラーなく分析データが取得される

**所要時間（予想）**: ~20秒

**必要なAccessibility Identifier**:
- `AnalysisPlayPauseButton` - 再生/一時停止ボタン
- `AnalysisSeekBackButton` - 5秒戻るボタン
- `AnalysisSeekForwardButton` - 5秒進むボタン
- `AnalysisProgressSlider` - 再生位置スライダー
- `SpectrogramView` - スペクトログラム表示領域
- `PitchGraphView` - ピッチグラフ表示領域
- `RecordingInfoPanel` - 録音情報パネル

**実装上の注意**:
- 分析処理は非同期なので、`waitForExistence(timeout:)` で分析完了を待つ
- ローディング状態のテストも含める（分析中のProgressView表示確認）
- エラー状態のシミュレーションテストは Phase 3 の testErrorRecovery に含める

---

### 🟢 優先度：低（エッジケース・追加機能）

#### 10. testSettingsPersistence
**目的**: 設定の永続化確認

**テストステップ**:
1. Settings画面でスケール設定を変更
2. アプリを終了（バックグラウンドから削除）
3. アプリを再起動
4. Settings画面で設定が保持されていることを確認

**検証ポイント**:
- ✅ 設定変更が保存される
- ✅ アプリ再起動後も設定が保持される

**所要時間（予想）**: ~20秒

**実装上の注意**:
- `XCUIApplication().terminate()` でアプリ終了
- 再度`XCUIApplication().launch()` で起動

---

#### 11. testSubscriptionManagement
**目的**: サブスクリプション管理画面の表示確認

**テストステップ**:
1. Settings画面へ遷移
2. Subscription Management項目をタップ
3. 現在のプラン表示を確認
4. プラン変更画面への遷移確認（実際の課金は行わない）

**検証ポイント**:
- ✅ Subscription Management画面への遷移
- ✅ 現在のプラン情報が表示される
- ✅ プラン変更UIが表示される

**所要時間（予想）**: ~10秒

**必要なAccessibility Identifier**:
- `SubscriptionManagementButton` - Settings画面のサブスクリプション管理ボタン
- `CurrentPlanLabel` - 現在のプラン表示
- `UpgradePlanButton` - プランアップグレードボタン

---

#### 12. testErrorRecovery
**目的**: エラー状態からの回復確認

**テストステップ**:
1. 意図的にエラーを発生させる（例: ストレージ不足シミュレーション）
2. エラーメッセージ表示を確認
3. エラー状態から正常状態へ回復できることを確認
4. 回復後、録音が正常に実行できることを確認

**検証ポイント**:
- ✅ エラーメッセージが適切に表示される
- ✅ エラー状態から回復可能
- ✅ 回復後の機能が正常動作

**所要時間（予想）**: ~15秒

**実装上の注意**:
- エラーシミュレーションのための特別なLaunch Arguments設定
- 例: `-UITestSimulateStorageError`

---

## 推奨実装順序

### Phase 1: コア機能テスト（優先度：高）- 目標: 1週間

1. ✅ **testBasicRecordingFlow** - 最も基本的なフロー
2. ✅ **testRecordingListNavigation** - リスト表示の基本
3. ✅ **testDeleteRecording** - 削除機能
4. ✅ **testPlaybackFullCompletion** - 完全再生

**合計所要時間（予想）**: ~48秒

---

### Phase 2: 設定・制限・分析テスト（優先度：中）- 目標: 2週間

5. ✅ **testChangeScaleSettings** - 設定変更
6. ✅ **testFreeTierRecordingLimit** - 時間制限
7. ✅ **testMultipleRecordings** - 複数録音
8. ✅ **testFullNavigationFlow** - ナビゲーション全体
9. ✅ **testAnalysisViewDisplay** - 分析機能 ⭐ NEW

**合計所要時間（予想）**: ~110秒

---

### Phase 3: エッジケース（優先度：低）- 目標: 1週間

10. ✅ **testSettingsPersistence** - 設定永続化
11. ✅ **testSubscriptionManagement** - サブスクリプション
12. ✅ **testErrorRecovery** - エラーハンドリング

**合計所要時間（予想）**: ~45秒

---

## 実装前の準備作業

### 1. Accessibility Identifierの追加

**必要な追加箇所**:

#### HomeView.swift
```swift
Button("録音を開始") {
    // ...
}
.accessibilityIdentifier("HomeRecordButton") // ✅ 既存
```

#### RecordingView.swift
```swift
Button("Start Recording") {
    // ...
}
.accessibilityIdentifier("StartRecordingButton") // ✅ 既存

Button("Stop Recording") {
    // ...
}
.accessibilityIdentifier("StopRecordingButton") // ✅ 既存

Button("Play Last Recording") {
    // ...
}
.accessibilityIdentifier("PlayLastRecordingButton") // ✅ 既存

Button("Stop Playback") {
    // ...
}
.accessibilityIdentifier("StopPlaybackButton") // ✅ 既存
```

#### RecordingListView.swift
```swift
// ❌ 追加必要
ForEach(recordings) { recording in
    RecordingRow(recording: recording)
        .accessibilityIdentifier("RecordingListItem_\(recording.id)")
}

Button("削除") {
    // ...
}
.accessibilityIdentifier("DeleteRecordingButton")
```

#### SettingsView.swift
```swift
// ❌ 追加必要
Picker("開始音", selection: $startNote) {
    // ...
}
.accessibilityIdentifier("StartNotePicker")

Picker("終了音", selection: $endNote) {
    // ...
}
.accessibilityIdentifier("EndNotePicker")

Picker("テンポ", selection: $tempo) {
    // ...
}
.accessibilityIdentifier("TempoPicker")

Button("保存") {
    // ...
}
.accessibilityIdentifier("SaveSettingsButton")
```

#### TabBar（主要画面のタブ）
```swift
// ❌ 追加必要
TabView {
    HomeView()
        .tabItem { Label("Home", systemImage: "house") }
        .accessibilityIdentifier("HomeTab")

    RecordingView()
        .tabItem { Label("Recording", systemImage: "mic") }
        .accessibilityIdentifier("RecordingTab")

    RecordingListView()
        .tabItem { Label("List", systemImage: "list.bullet") }
        .accessibilityIdentifier("RecordingListTab")

    AnalysisView()
        .tabItem { Label("Analysis", systemImage: "chart.bar") }
        .accessibilityIdentifier("AnalysisTab")

    SettingsView()
        .tabItem { Label("Settings", systemImage: "gear") }
        .accessibilityIdentifier("SettingsTab")
}
```

#### AnalysisView.swift ⭐ NEW
```swift
// ❌ 追加必要 - 分析画面の再生コントロール
// PlaybackControl構造体内のボタン (line 268, 272)
Button(action: onPlayPause) {
    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
        .font(.system(size: 40))
}
.accessibilityIdentifier("AnalysisPlayPauseButton")

// 5秒戻るボタン (line 263)
Button(action: { onSeek(max(0, currentTime - 5)) }) {
    Image(systemName: "backward.fill")
        .font(.callout)
}
.accessibilityIdentifier("AnalysisSeekBackButton")

// 5秒進むボタン (line 273)
Button(action: { onSeek(min(duration, currentTime + 5)) }) {
    Image(systemName: "forward.fill")
        .font(.callout)
}
.accessibilityIdentifier("AnalysisSeekForwardButton")

// 再生位置スライダー (line 281)
Slider(value: Binding(...), in: 0...duration)
    .accessibilityIdentifier("AnalysisProgressSlider")

// スペクトログラム表示領域 (line 314) - 構造体全体に追加
VStack(alignment: .leading, spacing: 6) {
    Text("analysis.spectrogram_title".localized)
    // ...
}
.accessibilityIdentifier("SpectrogramView")

// ピッチグラフ表示領域 (line 464) - 構造体全体に追加
VStack(alignment: .leading, spacing: 6) {
    Text("analysis.pitch_graph_title".localized)
    // ...
}
.accessibilityIdentifier("PitchGraphView")

// 録音情報パネル (line 167) - 構造体全体に追加
VStack(alignment: .leading, spacing: 8) {
    Text("analysis.info_title".localized)
    // ...
}
.accessibilityIdentifier("RecordingInfoPanel")
```

---

### 2. Launch Argumentsの設定

**テスト用の特別な起動引数**:

```swift
// VocalisStudioUITests.swift

func launchAppWithResetRecordingCount() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-UITestResetRecordingCount"]
    app.launch()
    return app
}

func launchAppWithFreeTier() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-UITestFreeTier"]
    app.launch()
    return app
}

func launchAppWithStorageError() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-UITestSimulateStorageError"]
    app.launch()
    return app
}
```

**アプリ側での処理** (VocalisStudioApp.swift):
```swift
init() {
    // UIテスト用の初期化
    if CommandLine.arguments.contains("-UITestResetRecordingCount") {
        // 録音カウントをリセット
    }

    if CommandLine.arguments.contains("-UITestFreeTier") {
        // Free Tierに強制設定
    }

    if CommandLine.arguments.contains("-UITestSimulateStorageError") {
        // ストレージエラーをシミュレート
    }
}
```

---

### 3. テストの安定性向上のためのベストプラクティス

**1. 適切な待機時間の使用**
```swift
// ✅ Good: waitForExistence使用
XCTAssertTrue(button.waitForExistence(timeout: 5), "Button should exist")

// ❌ Bad: Thread.sleepの多用
Thread.sleep(forTimeInterval: 2.0)
```

**2. スクリーンショット撮影**
```swift
let screenshot = app.screenshot()
let attachment = XCTAttachment(screenshot: screenshot)
attachment.name = "test_state_description"
attachment.lifetime = .keepAlways
add(attachment)
```

**3. 具体的なエラーメッセージ**
```swift
// ✅ Good: 具体的なメッセージ
XCTAssertTrue(button.exists, "Start Recording button should exist after navigating to Recording screen")

// ❌ Bad: 一般的なメッセージ
XCTAssertTrue(button.exists, "Button not found")
```

**4. テストの独立性確保**
```swift
override func setUp() async throws {
    // 各テスト前に状態をリセット
    continueAfterFailure = false
}

override func tearDown() async throws {
    // テスト後のクリーンアップ
}
```

---

## カバレッジ目標

### 現在のカバレッジ
- **UIテスト数**: 1件
- **カバー範囲**: 録音→再生→停止の基本フロー

### Phase 1完了後の目標
- **UIテスト数**: 5件
- **カバー範囲**: 録音基本機能、リスト表示、削除、完全再生

### Phase 2完了後の目標
- **UIテスト数**: 10件
- **カバー範囲**: 設定変更、時間制限、複数録音、ナビゲーション全体、**分析機能** ⭐ NEW

### Phase 3完了後の目標（最終）
- **UIテスト数**: 13件
- **カバー範囲**: 全主要機能（分析機能含む） + エッジケース

---

## 参考資料

- **既存UIテスト**: `VocalisStudioUITests/VocalisStudioUITests.swift`
- **Accessibility Identifier命名規則**: `{ComponentType}{Description}` (例: `HomeRecordButton`)
- **XCTest公式ドキュメント**: [Apple Developer - XCTest](https://developer.apple.com/documentation/xctest)
- **UI Testing Best Practices**: [WWDC Videos - UI Testing](https://developer.apple.com/videos/play/wwdc2019/413/)

---

## 次のステップ

1. **Phase 1の実装開始**: testBasicRecordingFlowから実装
2. **Accessibility Identifierの追加**: RecordingListView, SettingsView, TabBarに追加
3. **Launch Argumentsの実装**: Free Tier強制設定などの追加
4. **テスト実行と検証**: 各テストが安定して成功することを確認

実装を開始しますか？どのテストから始めるか指示をお願いします。
