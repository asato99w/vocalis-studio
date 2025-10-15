import Foundation

/// Scale settings entity
public struct ScaleSettings: Equatable, Codable {
    public let startNote: MIDINote
    public let endNote: MIDINote
    public let notePattern: NotePattern
    public let tempo: Tempo

    public init(
        startNote: MIDINote,
        endNote: MIDINote,
        notePattern: NotePattern,
        tempo: Tempo
    ) {
        self.startNote = startNote
        self.endNote = endNote
        self.notePattern = notePattern
        self.tempo = tempo
    }

    /// Generate full scale with chromatic progression
    /// Returns all notes across the pitch range
    public func generateScale() -> [MIDINote] {
        let pattern = notePattern.ascendingDescending()
        var allNotes: [MIDINote] = []

        var currentRoot = startNote.value
        while currentRoot <= endNote.value {
            let scaleNotes = pattern.compactMap { interval in
                try? MIDINote(currentRoot + UInt8(interval))
            }
            allNotes.append(contentsOf: scaleNotes)
            currentRoot += 1  // Chromatic progression (half-step up)
        }

        return allNotes
    }

    /// Calculate total duration for the entire scale
    public var totalDuration: Duration {
        let notes = generateScale()
        let totalSeconds = Double(notes.count) * tempo.secondsPerNote
        return Duration(seconds: totalSeconds)
    }

    /// MVP default settings: C4 to C5, five-tone scale, 1 second per note
    public static let mvpDefault = ScaleSettings(
        startNote: .middleC,
        endNote: .hiC,
        notePattern: .fiveToneScale,
        tempo: .standard
    )
}

// MARK: - Codable conformance for value objects
extension MIDINote: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(UInt8.self)
        try self.init(value)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

extension Tempo: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let secondsPerNote = try container.decode(Double.self)
        try self.init(secondsPerNote: secondsPerNote)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(secondsPerNote)
    }
}
