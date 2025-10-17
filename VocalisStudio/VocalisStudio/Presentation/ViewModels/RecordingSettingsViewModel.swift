import Foundation
import VocalisDomain

/// Scale type selection for recording
public enum ScaleType {
    case fiveTone
    case off
}

/// ViewModel for recording settings configuration
public class RecordingSettingsViewModel: ObservableObject {
    @Published public var scaleType: ScaleType = .fiveTone
    @Published public var startPitchIndex: Int = 12 // C3 (MIDI 48)
    @Published public var tempo: Int = 120
    @Published public var ascendingCount: Int = 3

    public let availablePitches = [
        "C2", "C#2", "D2", "D#2", "E2", "F2", "F#2", "G2", "G#2", "A2", "A#2", "B2",
        "C3", "C#3", "D3", "D#3", "E3", "F3", "F#3", "G3", "G#3", "A3", "A#3", "B3",
        "C4", "C#4", "D4", "D#4", "E4", "F4", "F#4", "G4", "G#4", "A4", "A#4", "B4",
        "C5", "C#5", "D5", "D#5", "E5", "F5", "F#5", "G5", "G#5", "A5", "A#5", "B5",
        "C6"
    ]

    public var isSettingsEnabled: Bool {
        scaleType != .off
    }

    public init() {}

    /// Generate ScaleSettings from current UI settings
    public func generateScaleSettings() -> ScaleSettings? {
        guard scaleType == .fiveTone else {
            return nil // Scale off - no settings
        }

        // Calculate MIDI note number: C2 = 36
        let midiNoteNumber = 36 + startPitchIndex

        // Calculate end note (one octave up) - kept for compatibility but not used
        let endNoteNumber = midiNoteNumber + 12

        // Calculate tempo (convert BPM to seconds per note)
        // At 120 BPM, each quarter note is 0.5 seconds
        let secondsPerNote = 60.0 / Double(tempo)

        do {
            let settings = ScaleSettings(
                startNote: try MIDINote(UInt8(midiNoteNumber)),
                endNote: try MIDINote(UInt8(endNoteNumber)),
                notePattern: .fiveToneScale,
                tempo: try Tempo(secondsPerNote: secondsPerNote),
                ascendingCount: ascendingCount  // Use UI setting
            )
            return settings
        } catch {
            return nil
        }
    }
}
