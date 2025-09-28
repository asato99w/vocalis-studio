# Vocalis Studio 🎵

ボイストレーニングをサポートするiOSアプリケーション

## 概要

Vocalis Studioは、歌唱力向上を目指す方のためのボイストレーニング補助アプリです。5トーンスケールなどの音源を再生しながら録音ができ、自分の歌声を確認・改善できます。

## 主な機能

### 現在実装予定の機能（MVP）
- 🎹 5トーンスケール音源の再生
- 🎤 音源再生中の同時録音
- 💾 録音データの保存・管理
- 🔊 録音の再生機能

### 今後の拡張予定
- 📊 ピッチ解析と視覚化
- 📈 練習履歴の管理
- 🎼 様々な音階パターン
- 📱 クラウド同期

## 技術スタック

- **言語**: Swift 5.9+
- **UI Framework**: SwiftUI
- **最小iOS**: iOS 15.0
- **アーキテクチャ**: クリーンアーキテクチャ + MVVM
- **主要Framework**: AVFoundation, Combine

## 開発手法

- **テスト駆動開発（TDD）**: テストを先に書いてから実装
- **ドメイン駆動設計（DDD）**: ボイストレーニングドメインの正確なモデリング
- **クリーンアーキテクチャ**: ビジネスロジックの独立性とテスタビリティ確保

## プロジェクト構造

```
vocalis_studio/
├── docs/                      # プロジェクトドキュメント
│   ├── PROJECT_OVERVIEW.md    # プロジェクト概要
│   ├── TECHNICAL_SPEC.md      # 技術仕様書（TDD/DDD/Clean Architecture）
│   ├── ROADMAP.md             # 開発ロードマップ
│   └── ARCHITECTURE.md        # クリーンアーキテクチャ設計
├── VocalisStudio/             # Xcodeプロジェクト
│   ├── VocalisStudio.xcodeproj/    # Xcodeプロジェクトファイル
│   └── VocalisStudio/              # ソースコード
│       ├── Domain/                 # ドメイン層（Entities, Value Objects）
│       ├── Application/            # アプリケーション層（Use Cases）
│       ├── Infrastructure/         # インフラ層（外部連携）
│       ├── Presentation/           # プレゼンテーション層（Views, ViewModels）
│       └── App/                    # アプリエントリーポイント
└── README.md                  # このファイル
```

## 開発環境のセットアップ

### 必要な環境
- macOS Sonoma 14.0以降
- Xcode 15.0以降
- iOS実機またはシミュレーター（iOS 15.0以降）

### セットアップ手順
```bash
# リポジトリをクローン
git clone [repository-url]
cd vocalis_studio

# Xcodeプロジェクトを開く
open VocalisStudio/VocalisStudio.xcodeproj
```

## ドキュメント

詳細な情報は以下のドキュメントをご参照ください：

- [プロジェクト概要](docs/PROJECT_OVERVIEW.md) - プロジェクトのビジョンと目標
- [技術仕様書](docs/TECHNICAL_SPEC.md) - 技術的な詳細仕様
- [開発ロードマップ](docs/ROADMAP.md) - 開発スケジュールとマイルストーン
- [アーキテクチャ設計](docs/ARCHITECTURE.md) - アプリケーションの設計詳細

## 開発スケジュール

| フェーズ | 期間 | 内容 |
|---------|------|------|
| Phase 1 | 2025年10月〜11月 | MVP開発（基本機能） |
| Phase 2 | 2025年11月〜12月 | 品質向上とデータ管理 |
| Phase 3 | 2026年1月〜2月 | 高度な機能追加 |
| Phase 4 | 2026年3月〜 | ユーザー体験向上 |

## ライセンス

[ライセンスを後で決定]

## コントリビューション

現在は個人開発プロジェクトです。

## 連絡先

[連絡先情報を追加]

---

🚀 **開発状況**: 設計・仕様策定フェーズ