import Foundation

/// Scale playback sound type
public enum ScaleSoundType: String, Codable, CaseIterable, Hashable {
    case acousticGrandPiano     // Acoustic Grand Piano (GM Program 0)
    case electricPiano          // Electric Piano 1 (GM Program 4)
    case acousticGuitar         // Acoustic Guitar (nylon) (GM Program 24)
    case vibraphone             // Vibraphone (GM Program 11)
    case marimba                // Marimba (GM Program 12)
    case flute                  // Flute (GM Program 73)
    case clarinet               // Clarinet (GM Program 71)
    case sineWave               // Pure sine wave (programmatic)

    /// Default sound type
    public static let `default` = ScaleSoundType.acousticGrandPiano

    /// General MIDI Program Number (nil for sine wave)
    public var midiProgram: UInt8? {
        switch self {
        case .acousticGrandPiano:
            return 0
        case .electricPiano:
            return 4
        case .acousticGuitar:
            return 24
        case .vibraphone:
            return 11
        case .marimba:
            return 12
        case .flute:
            return 73
        case .clarinet:
            return 71
        case .sineWave:
            return nil  // Programmatically generated
        }
    }

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .acousticGrandPiano:
            return "アコースティック・グランド・ピアノ"
        case .electricPiano:
            return "エレクトリック・ピアノ"
        case .acousticGuitar:
            return "アコースティック・ギター"
        case .vibraphone:
            return "ヴィブラフォン"
        case .marimba:
            return "マリンバ"
        case .flute:
            return "フルート"
        case .clarinet:
            return "クラリネット"
        case .sineWave:
            return "サイン波"
        }
    }

    /// Icon for UI display
    public var icon: String {
        switch self {
        case .acousticGrandPiano:
            return "🎹"
        case .electricPiano:
            return "🎹✨"
        case .acousticGuitar:
            return "🎸"
        case .vibraphone:
            return "🎵"
        case .marimba:
            return "🥁"
        case .flute:
            return "🎺"
        case .clarinet:
            return "🎷"
        case .sineWave:
            return "〜"
        }
    }

    /// Description for UI footer
    public var description: String {
        switch self {
        case .acousticGrandPiano:
            return "最も一般的な音色、親しみやすく全音域で明瞭なピッチ"
        case .electricPiano:
            return "明るく華やかな音色、ポップス・ジャズに適している"
        case .acousticGuitar:
            return "柔らかく温かみのある音色、中低音域が豊か"
        case .vibraphone:
            return "倍音が少なく聞き取りやすい、ピッチの確認に適している"
        case .marimba:
            return "温かみのある柔らかい音色、中低音域の練習に適している"
        case .flute:
            return "明瞭で澄んだ音色、高音域の練習に最適"
        case .clarinet:
            return "中音域が豊かで柔らかい、声楽の音域に近い"
        case .sineWave:
            return "純音でピッチを正確に確認、音楽理論の学習に適している"
        }
    }
}
