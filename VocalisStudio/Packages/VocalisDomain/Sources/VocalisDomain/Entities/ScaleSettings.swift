import Foundation

/// Scale element for playback with key change chords
public enum ScaleElement: Equatable {
    case chordShort([MIDINote])   // "Dan" - short chord (0.3s) for previous key
    case chordLong([MIDINote])    // "Daan" - long chord (1.0s) for current key
    case scaleNote(MIDINote)      // Single scale note
    case silence(TimeInterval)    // Silent gap

    public var duration: TimeInterval {
        switch self {
        case .chordShort: return 0.3
        case .chordLong: return 1.0
        case .scaleNote(let note): return 0.5  // Will be overridden by tempo
        case .silence(let duration): return duration
        }
    }

    public var notes: [MIDINote] {
        switch self {
        case .chordShort(let notes): return notes
        case .chordLong(let notes): return notes
        case .scaleNote(let note): return [note]
        case .silence: return []
        }
    }
}

/// Scale settings entity
public struct ScaleSettings: Equatable, Codable, Hashable {
    public let startNote: MIDINote
    public let endNote: MIDINote
    public let notePattern: NotePattern
    public let tempo: Tempo
    public let keyProgressionPattern: KeyProgressionPattern
    public let ascendingKeyCount: Int   // Number of steps to ascend
    public let descendingKeyCount: Int  // Number of steps to descend
    public let ascendingKeyStepInterval: Int   // Interval for ascending (1=semitone, 2=whole tone, etc.)
    public let descendingKeyStepInterval: Int  // Interval for descending

    /// Backwards compatibility: ascendingCount maps to ascendingKeyCount
    public var ascendingCount: Int { ascendingKeyCount }

    /// Backwards compatibility: keyStepInterval maps to ascendingKeyStepInterval
    public var keyStepInterval: Int { ascendingKeyStepInterval }

    /// New initializer with separate ascending/descending intervals
    public init(
        startNote: MIDINote,
        endNote: MIDINote,
        notePattern: NotePattern,
        tempo: Tempo,
        keyProgressionPattern: KeyProgressionPattern,
        ascendingKeyCount: Int,
        descendingKeyCount: Int,
        ascendingKeyStepInterval: Int = 1,  // Default: semitone
        descendingKeyStepInterval: Int = 1  // Default: semitone
    ) {
        self.startNote = startNote
        self.endNote = endNote
        self.notePattern = notePattern
        self.tempo = tempo
        self.keyProgressionPattern = keyProgressionPattern
        self.ascendingKeyCount = ascendingKeyCount
        self.descendingKeyCount = descendingKeyCount
        self.ascendingKeyStepInterval = ascendingKeyStepInterval
        self.descendingKeyStepInterval = descendingKeyStepInterval
    }

    /// Convenience initializer with single interval for both directions
    public init(
        startNote: MIDINote,
        endNote: MIDINote,
        notePattern: NotePattern,
        tempo: Tempo,
        keyProgressionPattern: KeyProgressionPattern,
        ascendingKeyCount: Int,
        descendingKeyCount: Int,
        keyStepInterval: Int  // Single interval for both
    ) {
        self.init(
            startNote: startNote,
            endNote: endNote,
            notePattern: notePattern,
            tempo: tempo,
            keyProgressionPattern: keyProgressionPattern,
            ascendingKeyCount: ascendingKeyCount,
            descendingKeyCount: descendingKeyCount,
            ascendingKeyStepInterval: keyStepInterval,
            descendingKeyStepInterval: keyStepInterval
        )
    }

    /// Backwards compatible initializer
    public init(
        startNote: MIDINote,
        endNote: MIDINote,
        notePattern: NotePattern,
        tempo: Tempo,
        ascendingCount: Int = 12  // Default: one octave
    ) {
        self.startNote = startNote
        self.endNote = endNote
        self.notePattern = notePattern
        self.tempo = tempo
        self.keyProgressionPattern = .ascendingThenDescending
        self.ascendingKeyCount = ascendingCount
        self.descendingKeyCount = ascendingCount  // Mirror ascending for backwards compatibility
        self.ascendingKeyStepInterval = 1  // Default: semitone
        self.descendingKeyStepInterval = 1  // Default: semitone
    }

    /// Validate scale settings
    /// Throws ScaleError if settings are invalid
    public func validate() throws {
        // Validate note range: start note must be <= end note
        guard startNote <= endNote else {
            throw ScaleError.invalidRange(
                "Start note (\(startNote)) must be lower than or equal to end note (\(endNote))"
            )
        }

        // Validate start note is within practical range for vocal training
        // C3 (MIDI 48) to C6 (MIDI 84) is reasonable for most singers
        guard startNote.value >= 48 && startNote.value <= 84 else {
            throw ScaleError.invalidNote(
                "Start note (\(startNote.value)) should be between C3 (48) and C6 (84) for vocal training"
            )
        }

        // Validate ascending count: 1 (half step) to 24 (two octaves) is practical
        guard ascendingCount >= 1 && ascendingCount <= 24 else {
            throw ScaleError.invalidAscendingCount(
                "Ascending count (\(ascendingCount)) must be between 1 and 24"
            )
        }

        // Validate tempo: 1 to 3 seconds per note is practical
        guard tempo.secondsPerNote >= 1.0 && tempo.secondsPerNote <= 3.0 else {
            throw ScaleError.invalidTempo(
                "Tempo (\(tempo.secondsPerNote)s per note) must be between 1.0 and 3.0 seconds"
            )
        }
    }

    /// Generate full scale with chromatic progression
    /// Returns all notes across the pitch range
    public func generateScale() -> [MIDINote] {
        let pattern = notePattern.playbackPattern
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

    /// Generate scale elements with key change chords ("dan-daan" style)
    /// Follows keyProgressionPattern with specified ascending/descending counts
    /// First scale: [chord] daan → scale
    /// Subsequent: [prev chord] dan → [next chord] daan → scale
    public func generateScaleWithKeyChange() -> [ScaleElement] {
        var elements: [ScaleElement] = []

        // Generate root note sequence based on pattern
        let allRoots = generateKeyRoots()

        // Generate elements for each root
        var previousRoot: UInt8? = nil
        for root in allRoots {
            // Key change chords
            if let prev = previousRoot {
                // "Dan" - previous key (short, 0.3s)
                elements.append(.chordShort(majorTriad(prev)))
            }

            // "Daan" - current key (long, 1.0s)
            elements.append(.chordLong(majorTriad(root)))

            // Silence gap between chord and scale
            elements.append(.silence(0.2))

            // Scale notes
            let pattern = notePattern.playbackPattern
            for interval in pattern {
                if let note = try? MIDINote(root + UInt8(interval)) {
                    elements.append(.scaleNote(note))
                }
            }

            previousRoot = root
        }

        return elements
    }

    /// Generate the sequence of root notes based on key progression pattern
    private func generateKeyRoots() -> [UInt8] {
        let start = startNote.value
        let ascInterval = UInt8(ascendingKeyStepInterval)
        let descInterval = UInt8(descendingKeyStepInterval)

        switch keyProgressionPattern {
        case .ascendingOnly:
            // Just ascending: C → D → E → ... (using ascending interval)
            var roots: [UInt8] = []
            for i in 0..<ascendingKeyCount {
                roots.append(start + UInt8(i) * ascInterval)
            }
            return roots

        case .descendingOnly:
            // Just descending: C → Bb → Ab → ... (using descending interval)
            var roots: [UInt8] = []
            for i in 0..<descendingKeyCount {
                roots.append(start - UInt8(i) * descInterval)
            }
            return roots

        case .ascendingThenDescending:
            // Ascending with ascending interval
            var ascendingRoots: [UInt8] = []
            for i in 0..<ascendingKeyCount {
                ascendingRoots.append(start + UInt8(i) * ascInterval)
            }

            // Descending with descending interval (skip peak to avoid duplicate)
            var descendingRoots: [UInt8] = []
            if let peak = ascendingRoots.last {
                for i in 1...descendingKeyCount {
                    descendingRoots.append(peak - UInt8(i) * descInterval)
                }
            }

            return ascendingRoots + descendingRoots

        case .descendingThenAscending:
            // Descending with descending interval
            var descendingRoots: [UInt8] = []
            for i in 0..<descendingKeyCount {
                descendingRoots.append(start - UInt8(i) * descInterval)
            }

            // Ascending with ascending interval (skip valley to avoid duplicate)
            var ascendingRoots: [UInt8] = []
            if let valley = descendingRoots.last {
                for i in 1...ascendingKeyCount {
                    ascendingRoots.append(valley + UInt8(i) * ascInterval)
                }
            }

            return descendingRoots + ascendingRoots
        }
    }

    /// Create major triad chord from root note
    /// Formula: root + major 3rd (4 semitones) + perfect 5th (7 semitones)
    private func majorTriad(_ root: UInt8) -> [MIDINote] {
        return [
            try! MIDINote(root),      // Root
            try! MIDINote(root + 4),  // Major 3rd
            try! MIDINote(root + 7)   // Perfect 5th
        ]
    }

    /// MVP default settings: C4 start, 3 chromatic steps up, five-tone scale, 1 second per note
    public static let mvpDefault = ScaleSettings(
        startNote: .middleC,
        endNote: .hiC,  // Not used with ascendingCount, kept for compatibility
        notePattern: .fiveToneScale,
        tempo: .standard,
        ascendingCount: 3
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
