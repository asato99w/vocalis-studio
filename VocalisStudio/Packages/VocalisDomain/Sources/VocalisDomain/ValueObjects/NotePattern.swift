import Foundation

/// Note pattern for scale generation
public enum NotePattern: Equatable, Codable, Hashable {
    case fiveToneScale  // ドレミファソ (Root, +2, +4, +5, +7)

    /// Intervals from the root note (in semitones)
    public var intervals: [Int] {
        switch self {
        case .fiveToneScale:
            return [0, 2, 4, 5, 7]  // C, D, E, F, G
        }
    }

    /// Generate ascending then descending pattern
    /// Example: [0, 2, 4, 5, 7, 5, 4, 2, 0] for C-D-E-F-G-F-E-D-C
    public func ascendingDescending() -> [Int] {
        let ascending = intervals
        let descending = intervals.dropLast().reversed()
        return ascending + descending
    }

    /// Display name for the pattern in Japanese
    public var displayName: String {
        switch self {
        case .fiveToneScale:
            return "五声音階"
        }
    }
}
