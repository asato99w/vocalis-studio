# Vocalis Studio - 利用規約・プライバシーポリシー

このディレクトリには、Vocalis Studioアプリの利用規約とプライバシーポリシーのHTMLファイルが含まれています。

## ファイル

- `terms.html` - 利用規約
- `privacy.html` - プライバシーポリシー

## 現在の状態

現在、アプリ内のリンクはダミーURL (`https://vocalis-studio.example.com/`) を使用しています。

## デプロイ方法

リリース前に、これらのHTMLファイルを実際のWebサーバーにデプロイし、アプリ内のURLを更新する必要があります。

### 推奨デプロイ方法

#### 1. GitHub Pages（無料・簡単）

```bash
# 1. GitHubリポジトリの設定でGitHub Pagesを有効化
# 2. webディレクトリの内容をgh-pagesブランチまたはdocsディレクトリに配置
# 3. https://[username].github.io/[repository]/terms.html でアクセス可能
```

#### 2. Netlify（無料・自動デプロイ）

```bash
# 1. Netlifyアカウント作成
# 2. このディレクトリをデプロイ
# 3. カスタムドメイン設定可能
```

#### 3. 独自ドメイン

```bash
# 独自ドメインを使用する場合:
# - ドメインを取得（例: vocalis-studio.com）
# - webディレクトリをホスティングサービスにアップロード
# - https://vocalis-studio.com/terms.html
# - https://vocalis-studio.com/privacy.html
```

## アプリ内URL更新箇所

デプロイ後、以下のファイルのURLを実際のURLに更新してください:

1. `VocalisStudio/Presentation/Views/SettingsView.swift`
   - Line 50: 利用規約URL
   - Line 61: プライバシーポリシーURL

2. `VocalisStudio/Presentation/Views/PaywallView.swift`
   - Line 202: 利用規約URL
   - Line 205: プライバシーポリシーURL

## App Store 審査要件

App Store審査時には、以下が必要です:

1. **プライバシーポリシーURL** - App Connect での登録が必須
2. **利用規約URL** - アプリ内からアクセス可能であることが推奨
3. **両方とも公開アクセス可能** - 認証なしでアクセスできる必要がある

## 内容の更新

利用規約・プライバシーポリシーを更新する場合:

1. HTMLファイルを編集
2. 「最終更新日」を更新
3. Webサーバーに再デプロイ
4. アプリの更新は不要（URLは変更しないため）

## ローカルでの確認

HTMLファイルをブラウザで開いて内容を確認できます:

```bash
open web/terms.html
open web/privacy.html
```
