import Foundation

/// Protocol for scale playback functionality
/// Infrastructure layer must implement this protocol
public protocol ScalePlayerProtocol {
    /// Load a scale with specified notes and tempo (legacy format)
    /// - Parameters:
    ///   - notes: Array of MIDI notes to play
    ///   - tempo: Tempo for playback (seconds per note)
    func loadScale(_ notes: [MIDINote], tempo: Tempo) async throws

    /// Load scale elements with chord support (new format)
    /// - Parameters:
    ///   - elements: Array of scale elements (chords, notes, silences)
    ///   - tempo: Tempo for playback (seconds per note)
    func loadScaleElements(_ elements: [ScaleElement], tempo: Tempo) async throws

    /// Start playing the loaded scale
    func play() async throws

    /// Stop the current playback
    func stop() async

    /// Whether the player is currently playing
    var isPlaying: Bool { get }

    /// Current note index being played (0-based)
    var currentNoteIndex: Int { get }

    /// Playback progress (0.0 - 1.0)
    var progress: Double { get }
}

/// Errors that can occur during scale playback
public enum ScalePlayerError: LocalizedError, Equatable {
    case notLoaded
    case alreadyPlaying
    case playbackFailed(String)

    public static func == (lhs: ScalePlayerError, rhs: ScalePlayerError) -> Bool {
        switch (lhs, rhs) {
        case (.notLoaded, .notLoaded):
            return true
        case (.alreadyPlaying, .alreadyPlaying):
            return true
        case (.playbackFailed(let lhsMsg), .playbackFailed(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }

    public var errorDescription: String? {
        switch self {
        case .notLoaded:
            return "Scale not loaded. Call loadScale() first."
        case .alreadyPlaying:
            return "Already playing. Stop current playback first."
        case .playbackFailed(let message):
            return "Playback failed: \(message)"
        }
    }
}
