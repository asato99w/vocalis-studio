# VocalisStudio 実機ビルド セットアップガイド

実機でVocalisStudioアプリを動かすための完全ガイド

## 前提条件

- ✅ Mac（macOS Sonoma 14.0+）
- ✅ Xcode 15.0+
- ✅ iPhone（iOS 15.0+）
- ✅ USBケーブル（Lightning or USB-C）
- ✅ Apple ID（無料でOK）

## セットアップ手順

### ステップ1: Apple IDアカウントの追加

1. Xcodeを開く
2. メニューバー: **Xcode > Settings...** (⌘+,)
3. **Accounts** タブを選択
4. 左下の **+** ボタンをクリック
5. **Add Account...** を選択
6. **Apple ID** を選択して Continue
7. Apple IDとパスワードを入力してサインイン

**確認**: Accountsリストに自分のApple IDが表示される

---

### ステップ2: プロジェクトの署名設定

1. Xcodeで以下を開く:
   ```
   /Users/asatokazu/Documents/dev/mine/music/vocalis-studio/VocalisStudio/VocalisStudio.xcodeproj
   ```

2. Project Navigatorで **VocalisStudio** プロジェクト（青いアイコン）をクリック

3. TARGETSセクションで **VocalisStudio** を選択

4. **Signing & Capabilities** タブをクリック

5. **Team** ドロップダウンをクリック

6. 追加したApple IDのチーム（Personal Team）を選択

7. **Automatically manage signing** にチェックが入っていることを確認

8. **Bundle Identifier** を確認:
   - デフォルト: `com.kazuasato.VocalisStudio`
   - エラーが出た場合: `com.asatokazu.VocalisStudio` に変更

**確認**: "Signing for 'VocalisStudio' succeeded" と表示される

---

### ステップ3: iPhoneの接続

1. **iPhoneをMacにUSBケーブルで接続**

2. iPhone側でダイアログが表示される:
   ```
   このコンピュータを信頼しますか？
   ```
   → **信頼** をタップ

3. パスコードを入力（求められた場合）

4. Xcodeのツールバーを確認:
   ```
   [デバイス選択] ◀︎ ここをクリック
   ```

5. 接続したiPhoneを選択:
   ```
   例: asatokazu's iPhone
   ```

**確認**: ツールバーに自分のiPhone名が表示される

---

### ステップ4: ビルド＆実行

1. Xcodeで **⌘+B** を押してビルド

2. ビルドが成功したら **⌘+R** で実行

3. **初回のみ**: iPhoneに以下のエラーが表示される場合:
   ```
   App "VocalisStudio"を検証できませんでした
   ```

4. iPhoneで開発者を信頼する設定を行う:

   **iPhone設定アプリを開く**
   ↓
   **一般** をタップ
   ↓
   **VPNとデバイス管理** をタップ
   ↓
   **デベロッパApp** セクション
   ↓
   **自分のApple ID** をタップ
   ↓
   **"〇〇@〇〇.com" を信頼** をタップ
   ↓
   確認ダイアログで **信頼** をタップ

5. Xcodeに戻って再度 **⌘+R** で実行

6. iPhoneでアプリが起動し、マイクアクセス許可を求められる:
   ```
   "VocalisStudio"がマイクへのアクセスを求めています
   ```
   → **許可** をタップ

**確認**: iPhoneでVocalisStudioアプリが起動し、ホーム画面が表示される

---

## トラブルシューティング

### 🔴 エラー: "Failed to create provisioning profile"

**原因**: Bundle Identifierが既に使用されている

**解決方法**:
1. Signing & Capabilities タブを開く
2. Bundle Identifier を変更:
   ```
   例: com.asatokazu.VocalisStudio.dev
   ```
3. 保存して再ビルド

---

### 🔴 エラー: "The maximum number of apps for free development profiles has been reached"

**原因**: 無料アカウントは同時に3つまでしかアプリを登録できない

**解決方法1（Xcode側）**:
1. Xcode > Settings > Accounts
2. Apple IDを選択
3. **Manage Certificates...** ボタンをクリック
4. 不要なプロファイルを選択して削除

**解決方法2（iPhone側）**:
1. iPhone設定 > 一般 > VPNとデバイス管理
2. 古いデベロッパAppを削除

---

### 🔴 エラー: "Unable to install app"

**原因**: 開発者信頼設定が完了していない

**解決方法**:
1. 上記の「ステップ4」の手順4を実行
2. iPhone設定 > 一般 > VPNとデバイス管理
3. 自分のApple IDを信頼

---

### 🔴 エラー: "iPhone is busy: Copying cache files from device"

**原因**: Xcodeが初回接続時にキャッシュをコピー中

**解決方法**:
- 数分待つ（初回のみ、数分かかる場合があります）
- 完了後に再度ビルド

---

### 🔴 エラー: "Could not launch app"

**原因**: アプリがクラッシュした、またはマイク権限がない

**解決方法**:
1. iPhone設定 > VocalisStudio > マイク
2. マイクアクセスを**オン**に設定
3. アプリを再起動

---

### ⚠️ 注意: 無料Apple IDの制限

無料のApple Developer Account（個人用）には以下の制限があります：

| 項目 | 制限 |
|------|------|
| **同時登録可能なアプリ** | 3個まで |
| **証明書の有効期限** | 7日間（その後再ビルド必要） |
| **App Store配布** | 不可 |
| **プッシュ通知** | 不可 |
| **App Groups** | 制限あり |

**7日後にアプリが起動しなくなる**場合:
→ Xcodeで再度 ⌘+R でビルドしてインストールし直す

---

## ワイヤレスデバッグの設定（オプション）

USBケーブルなしでビルドしたい場合：

### 前提条件
- MacとiPhoneが同じWi-Fiネットワークに接続されている
- 初回はUSBケーブルでの接続が必要

### 設定手順

1. **iPhoneでデベロッパモードを有効化**:
   - 設定 > プライバシーとセキュリティ > デベロッパモード
   - オンに設定
   - iPhoneを再起動

2. **Xcodeでワイヤレス接続を有効化**:
   - Window > Devices and Simulators (⌘+Shift+2)
   - 接続されているiPhoneを選択
   - "Connect via network" にチェックを入れる
   - Wi-Fiアイコンがデバイス名の横に表示される

3. **USBケーブルを抜く**

4. 以降はWi-Fi経由でビルド可能

---

## 実機ビルドの利点

### シミュレーターと比較した実機の利点:

✅ **実際のマイク入力**: 本物のマイクでピッチ検出をテスト
✅ **リアルなパフォーマンス**: 実際のCPU/メモリ性能を確認
✅ **タッチ操作**: 実際の画面サイズと操作感を体験
✅ **カメラ・センサー**: 実デバイスのハードウェアを使用
✅ **バッテリー消費**: 実際のバッテリー消費を測定
✅ **外出先テスト**: Macがなくても7日間は使用可能

### 特にVocalisStudioでは:
- 🎤 **マイク録音**: シミュレーターではマイク入力が制限される
- 🎵 **リアルタイムピッチ検出**: 実際の音声でアルゴリズム比較
- 📊 **パフォーマンス測定**: FFT処理の実際の速度を確認
- 🔊 **音質確認**: スピーカー出力の実際の品質を確認

---

## チェックリスト

実機ビルドする前に確認：

- [ ] Apple IDをXcodeに追加済み
- [ ] プロジェクトでTeamを選択済み
- [ ] Bundle Identifierがユニーク
- [ ] iPhoneをUSBケーブルで接続
- [ ] iPhoneでコンピュータを信頼
- [ ] Xcodeで実機を選択（シミュレーターではない）
- [ ] ビルド成功（⌘+B）
- [ ] iPhoneで開発者を信頼（初回のみ）
- [ ] マイクアクセス許可を付与
- [ ] アプリが正常に起動

全てチェックできたら実機でVocalisStudioを楽しめます！🎉

---

## 参考リソース

- [Apple Developer - Running Your App on a Device](https://developer.apple.com/documentation/xcode/running-your-app-in-simulator-or-on-a-device)
- [Free Provisioning Profiles](https://developer.apple.com/support/apple-id/)
- [Xcode Help](https://help.apple.com/xcode/)
