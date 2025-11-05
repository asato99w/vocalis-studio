import SwiftUI

/// Design system color palette
/// Based on "Precision in Silence" concept defined in docs/DESIGN_SYSTEM.md
/// Supports both light and dark mode with adaptive colors
public enum ColorPalette {
    // MARK: - Core Colors

    /// Primary: 精度・信頼を象徴する淡いブルー
    /// Light mode: #3A6EA5, Dark mode: #5A8EC5 (明度を上げて視認性向上)
    /// Usage: メインアクションボタン、選択状態の強調、重要なナビゲーション要素
    public static let primary = Color(
        light: Color(red: 0x3A / 255.0, green: 0x6E / 255.0, blue: 0xA5 / 255.0),
        dark: Color(red: 0x5A / 255.0, green: 0x8E / 255.0, blue: 0xC5 / 255.0)
    )

    /// Secondary: 柔らかく主張しない背景色
    /// Light mode: #D8E1E8 (淡グレー), Dark mode: #2C2C2E (ダークグレー)
    /// Usage: カード背景、セクション区切り、非アクティブ状態の背景
    public static let secondary = Color(
        light: Color(red: 0xD8 / 255.0, green: 0xE1 / 255.0, blue: 0xE8 / 255.0),
        dark: Color(red: 0x2C / 255.0, green: 0x2C / 255.0, blue: 0x2E / 255.0)
    )

    /// Background: 画面全体の背景色
    /// Light mode: #FFFFFF (白), Dark mode: #000000 (黒)
    /// Usage: 画面の基本背景
    public static let background = Color(
        light: Color.white,
        dark: Color.black
    )

    /// Text: 読みやすく温度感を抑えたテキスト色
    /// Light mode: #1E1E1E (深灰), Dark mode: #E5E5E7 (明灰)
    /// Usage: 本文テキスト、ラベル、説明文
    public static let text = Color(
        light: Color(red: 0x1E / 255.0, green: 0x1E / 255.0, blue: 0x1E / 255.0),
        dark: Color(red: 0xE5 / 255.0, green: 0xE5 / 255.0, blue: 0xE7 / 255.0)
    )

    /// Accent: ピッチラインなど分析用のサインブルー
    /// Light mode: #00A6D6, Dark mode: #40C6F6 (明度を上げて視認性向上)
    /// Usage: ピッチグラフのライン、リアルタイム分析表示、データ可視化要素
    public static let accent = Color(
        light: Color(red: 0x00 / 255.0, green: 0xA6 / 255.0, blue: 0xD6 / 255.0),
        dark: Color(red: 0x40 / 255.0, green: 0xC6 / 255.0, blue: 0xF6 / 255.0)
    )

    /// Alert/Active: アナログ計器的な警告色
    /// Light mode: #F2B705, Dark mode: #FFD60A (明度を上げて視認性向上)
    /// Usage: 録音中インジケーター、警告メッセージ、注意を引く必要がある状態表示
    public static let alertActive = Color(
        light: Color(red: 0xF2 / 255.0, green: 0xB7 / 255.0, blue: 0x05 / 255.0),
        dark: Color(red: 0xFF / 255.0, green: 0xD6 / 255.0, blue: 0x0A / 255.0)
    )
}

// MARK: - Color Extension for Adaptive Colors

extension Color {
    /// Create an adaptive color that changes based on the color scheme
    init(light: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
}
