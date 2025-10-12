import Foundation

/// MIDI note number value object (0-127)
public struct MIDINote: Equatable, Comparable, Hashable {
    public let value: UInt8

    public init(_ value: UInt8) throws {
        guard value <= 127 else {
            throw MIDINoteError.outOfRange(value)
        }
        self.value = value
    }

    // Convenience initializers for common notes
    public static let middleC = try! MIDINote(60)  // C4
    public static let hiC = try! MIDINote(72)      // C5

    // Comparable
    public static func < (lhs: MIDINote, rhs: MIDINote) -> Bool {
        lhs.value < rhs.value
    }
}

public enum MIDINoteError: LocalizedError {
    case outOfRange(UInt8)

    public var errorDescription: String? {
        switch self {
        case .outOfRange(let value):
            return "MIDI note value \(value) is out of range (0-127)"
        }
    }
}
