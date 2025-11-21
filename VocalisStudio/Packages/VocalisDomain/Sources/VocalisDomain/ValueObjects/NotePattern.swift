import Foundation

/// Note pattern for scale generation
public enum NotePattern: Equatable, Codable, Hashable {
    case fiveToneScale  // ドレミファソ (Root, +2, +4, +5, +7)
    case octaveRepeat   // オクターブリピート (Root, +4, +8, +12 with top repeat)

    /// Intervals from the root note (in semitones)
    public var intervals: [Int] {
        switch self {
        case .fiveToneScale:
            return [0, 2, 4, 5, 7]  // C, D, E, F, G
        case .octaveRepeat:
            return [0, 4, 7, 12]  // C, E, G, C (major triad + octave)
        }
    }

    /// Generate ascending then descending pattern
    /// Example: [0, 2, 4, 5, 7, 5, 4, 2, 0] for C-D-E-F-G-F-E-D-C
    public func ascendingDescending() -> [Int] {
        let ascending = intervals
        let descending = intervals.dropLast().reversed()
        return ascending + descending
    }

    /// Playback pattern for actual note sequence
    /// Allows complex patterns like top note repeats
    public var playbackPattern: [Int] {
        switch self {
        case .fiveToneScale:
            return [0, 2, 4, 5, 7, 5, 4, 2, 0]
        case .octaveRepeat:
            return [0, 4, 7, 12, 12, 12, 12, 7, 4, 0]
        }
    }

    /// Display name for the pattern in Japanese
    public var displayName: String {
        switch self {
        case .fiveToneScale:
            return "五声音階"
        case .octaveRepeat:
            return "オクターブリピート"
        }
    }
}
