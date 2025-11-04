import SwiftUI

/// Design system color palette
/// Based on "Precision in Silence" concept defined in docs/DESIGN_SYSTEM.md
public enum ColorPalette {
    // MARK: - Core Colors

    /// Primary: 精度・信頼を象徴する淡いブルー (#3A6EA5)
    /// Usage: メインアクションボタン、選択状態の強調、重要なナビゲーション要素
    public static let primary = Color(red: 0x3A / 255.0, green: 0x6E / 255.0, blue: 0xA5 / 255.0)

    /// Secondary: 柔らかく主張しない淡グレー (#D8E1E8)
    /// Usage: カード背景、セクション区切り、非アクティブ状態の背景
    public static let secondary = Color(red: 0xD8 / 255.0, green: 0xE1 / 255.0, blue: 0xE8 / 255.0)

    /// Text: 読みやすく温度感を抑えた深灰 (#1E1E1E)
    /// Usage: 本文テキスト、ラベル、説明文
    public static let text = Color(red: 0x1E / 255.0, green: 0x1E / 255.0, blue: 0x1E / 255.0)

    /// Accent: ピッチラインなど分析用のサインブルー (#00A6D6)
    /// Usage: ピッチグラフのライン、リアルタイム分析表示、データ可視化要素
    public static let accent = Color(red: 0x00 / 255.0, green: 0xA6 / 255.0, blue: 0xD6 / 255.0)

    /// Alert/Active: アナログ計器的な警告色 (#F2B705)
    /// Usage: 録音中インジケーター、警告メッセージ、注意を引く必要がある状態表示
    public static let alertActive = Color(red: 0xF2 / 255.0, green: 0xB7 / 255.0, blue: 0x05 / 255.0)
}
