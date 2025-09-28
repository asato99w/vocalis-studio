# 技術仕様書 - Vocalis Studio

## 1. システム要件

### 対応デバイス
- iPhone（iOS 15.0以降）
- iPad対応（将来的な拡張）

### 開発環境
- Xcode 15.0以降
- Swift 5.9以降
- macOS Sonoma 14.0以降

## 2. 開発手法

### テスト駆動開発（TDD）
- **Red-Green-Refactor サイクル**
  - テストを先に書く（Red）
  - 実装してテストを通す（Green）
  - コードをリファクタリング（Refactor）
- **テストカバレッジ目標**: 80%以上
- **テストピラミッド戦略**
  - Unit Tests: 70%
  - Integration Tests: 20%
  - UI/E2E Tests: 10%

### ドメイン駆動設計（DDD）
- **ドメインモデル中心設計**
  - ボイストレーニングドメインの概念をコードで表現
  - ユビキタス言語の確立
- **境界づけられたコンテキスト**
  - Recording Context（録音）
  - Training Context（トレーニング）
  - Analysis Context（分析）
- **戦術的パターン**
  - Entity: Recording, TrainingSession
  - Value Object: AudioLevel, Pitch, Duration
  - Repository: RecordingRepository
  - Domain Service: AudioProcessingService

### クリーンアーキテクチャ
- **依存性の逆転原則**
  - ビジネスロジックはフレームワークに依存しない
  - 外側のレイヤーが内側に依存
- **レイヤー分離**
  - 各レイヤーは独立してテスト可能
  - インターフェース経由の疎結合

## 3. アプリケーションアーキテクチャ

### クリーンアーキテクチャによるレイヤー構成
```
┌─────────────────────────────────────┐
│    Presentation Layer               │
│  (SwiftUI Views, ViewModels)        │
├─────────────────────────────────────┤
│    Application Layer                │
│    (Use Cases, DTOs)                │
├─────────────────────────────────────┤
│      Domain Layer                   │
│  (Entities, Value Objects,          │
│   Domain Services, Repositories)    │
├─────────────────────────────────────┤
│    Infrastructure Layer             │
│ (Data Sources, External Services)   │
└─────────────────────────────────────┘

依存性の方向: ↓ (外側から内側へ)
```

### 各レイヤーの責務

#### Domain Layer（最内層）
- **責務**: ビジネスロジックとドメインモデル
- **依存**: なし（完全に独立）
- **含むもの**:
  - Entities（Recording, TrainingSession）
  - Value Objects（Pitch, Duration, AudioQuality）
  - Domain Services
  - Repository Interfaces

#### Application Layer
- **責務**: アプリケーション固有のビジネスルール
- **依存**: Domain Layer のみ
- **含むもの**:
  - Use Cases（RecordWithScaleUseCase, AnalyzePitchUseCase）
  - Application Services
  - DTOs（Data Transfer Objects）

#### Infrastructure Layer
- **責務**: 外部システムとの連携
- **依存**: Domain Layer, Application Layer
- **含むもの**:
  - Repository実装
  - AVFoundation連携
  - ファイルシステムアクセス
  - ネットワーク通信

#### Presentation Layer（最外層）
- **責務**: ユーザーインターフェース
- **依存**: Application Layer
- **含むもの**:
  - SwiftUI Views
  - ViewModels
  - UI Components

## 4. 主要機能の技術仕様

### 4.1 音源再生機能
#### 使用フレームワーク
- **AVFoundation**: オーディオ再生・録音の基盤
- **AVAudioEngine**: 高度なオーディオ処理

#### 実装詳細
```swift
- AVAudioPlayer: 音源ファイルの再生
- AVAudioSession: オーディオセッションの管理
- 対応フォーマット: WAV, MP3, M4A
```

#### 5トーンスケール音源
- **音階**: ド・レ・ミ・ファ・ソ（C4-G4）
- **テンポ**: 60-120 BPM（可変）
- **音源生成**: Core Audio / AudioKit（検討）

### 4.2 録音機能
#### 使用技術
- **AVAudioRecorder**: 音声録音
- **AVAudioSession**: マイク入力管理

#### 録音仕様
- **フォーマット**: M4A（AAC）
- **サンプルレート**: 44.1kHz
- **ビットレート**: 128kbps
- **チャンネル**: モノラル

#### 同時録音実装
```swift
class AudioManager {
    - 音源再生と録音の同期制御
    - バックグラウンド処理対応
    - 音声レベルモニタリング
}
```

### 4.3 データ保存
#### ストレージ
- **FileManager**: ローカルファイル管理
- **Core Data**: メタデータ管理（将来拡張）

#### 保存構造
```
Documents/
├── Recordings/
│   ├── recording_[timestamp].m4a
│   └── metadata.json
└── Settings/
    └── user_preferences.json
```

## 5. UI/UX仕様

### 画面構成
1. **メイン画面**
   - 録音開始/停止ボタン
   - 音源再生コントロール
   - 音量レベルメーター

2. **録音リスト画面**
   - 録音履歴一覧
   - 再生・削除機能

3. **設定画面**
   - テンポ調整
   - 音量調整
   - 録音品質設定

### UIフレームワーク
- **SwiftUI**: 宣言的UI構築
- **Combine**: リアクティブプログラミング

## 6. パーミッション管理

### 必要な権限
- **マイクアクセス**: NSMicrophoneUsageDescription
- **バックグラウンドオーディオ**: Background Modes

## 7. エラーハンドリング

### 想定エラー
- マイクアクセス拒否
- ストレージ容量不足
- オーディオセッション競合
- ファイル保存失敗

### エラー処理方針
```swift
enum AudioError: Error {
    case microphoneAccessDenied
    case insufficientStorage
    case audioSessionError
    case fileOperationFailed
}
```

## 8. パフォーマンス要件

### レスポンス時間
- 録音開始: < 0.5秒
- 音源再生開始: < 0.3秒
- UI操作レスポンス: < 0.1秒

### メモリ使用
- 最大使用量: 100MB以下
- バックグラウンド時: 50MB以下

## 9. テスト戦略

### TDD実践方針
- **テストファースト開発**
  - 新機能実装前にテストを作成
  - インターフェース設計をテストから導出
  - リファクタリング時の安全性確保

### テストレベル別戦略

#### ユニットテスト（70%）
- **Domain Layer**
  - Entity/Value Objectの振る舞い
  - Domain Serviceのビジネスロジック
  - Repository Interface のモック実装
- **Application Layer**
  - Use Casesの実行フロー
  - DTOの変換ロジック
- **Presentation Layer**
  - ViewModelのステート管理
  - ユーザーインタラクションロジック

```swift
// TDD例: RecordingEntityのテスト
func testRecordingDurationCalculation() {
    // Given
    let startTime = Date()
    let endTime = startTime.addingTimeInterval(30)
    
    // When
    let recording = Recording(startTime: startTime, endTime: endTime)
    
    // Then
    XCTAssertEqual(recording.duration, 30)
}
```

#### 統合テスト（20%）
- Use CaseとRepository の統合
- AudioManagerとAVFoundationの連携
- データ永続化フロー

#### UIテスト（10%）
- 主要な操作フロー（録音→保存→再生）
- エラーケースのUI表示
- アクセシビリティ確認

### テストダブル戦略
- **Mock**: 外部依存の振る舞いを制御
- **Stub**: 固定値を返す軽量実装
- **Spy**: メソッド呼び出しの検証

### 継続的テスト
- プルリクエスト時の自動テスト実行
- コードカバレッジレポート生成
- パフォーマンステストの定期実行

## 10. セキュリティ考慮事項

- 録音データの暗号化（将来検討）
- プライバシー保護
- App Transport Security準拠

## 11. 依存関係

### 標準フレームワーク
- Foundation
- AVFoundation
- SwiftUI
- Combine

### サードパーティ（検討中）
- AudioKit（高度な音声処理）
- SwiftLint（コード品質）

## 12. ビルド設定

### デプロイメントターゲット
- iOS 15.0+
- Swift Language Version: 5.9

### ビルド構成
- Debug: 開発用
- Release: App Store提出用

## 13. 将来の拡張性考慮

### モジュール化
- Feature Modules
- Dynamic Frameworks

### 拡張可能な機能
- ピッチ検出エンジン
- 楽譜表示モジュール
- クラウド同期
- ソーシャル機能