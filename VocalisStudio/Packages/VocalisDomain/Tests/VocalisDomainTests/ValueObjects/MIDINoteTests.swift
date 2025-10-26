import XCTest
@testable import VocalisDomain

final class MIDINoteTests: XCTestCase {
    func testInit_ValidValue_Success() throws {
        // Given & When
        let note = try MIDINote(60)
        
        // Then
        XCTAssertEqual(note.value, 60)
    }
    
    func testInit_MaxValue_Success() throws {
        // Given & When
        let note = try MIDINote(127)
        
        // Then
        XCTAssertEqual(note.value, 127)
    }
    
    func testInit_MinValue_Success() throws {
        // Given & When
        let note = try MIDINote(0)
        
        // Then
        XCTAssertEqual(note.value, 0)
    }
    
    func testInit_OutOfRange_ThrowsError() {
        // Given & When & Then
        XCTAssertThrowsError(try MIDINote(128)) { error in
            XCTAssertTrue(error is MIDINoteError)
        }
    }
    
    func testMiddleC_CorrectValue() {
        // Given & When
        let middleC = MIDINote.middleC
        
        // Then
        XCTAssertEqual(middleC.value, 60)
    }
    
    func testHiC_CorrectValue() {
        // Given & When
        let hiC = MIDINote.hiC
        
        // Then
        XCTAssertEqual(hiC.value, 72)
    }
    
    func testComparable_LessThan() throws {
        // Given
        let c4 = try MIDINote(60)
        let c5 = try MIDINote(72)
        
        // When & Then
        XCTAssertTrue(c4 < c5)
        XCTAssertFalse(c5 < c4)
    }
    
    func testEquatable() throws {
        // Given
        let note1 = try MIDINote(60)
        let note2 = try MIDINote(60)
        let note3 = try MIDINote(61)

        // When & Then
        XCTAssertEqual(note1, note2)
        XCTAssertNotEqual(note1, note3)
    }

    // MARK: - Frequency Calculation Tests

    func testFrequency_A4_Returns440Hz() throws {
        // Given: A4 (MIDI 69) is the standard tuning reference
        let a4 = try MIDINote(69)

        // When
        let frequency = a4.frequency

        // Then: A4 = 440 Hz (standard tuning)
        XCTAssertEqual(frequency, 440.0, accuracy: 0.01)
    }

    func testFrequency_MiddleC_ReturnsCorrectFrequency() {
        // Given: C4 (MIDI 60)
        let c4 = MIDINote.middleC

        // When
        let frequency = c4.frequency

        // Then: C4 ≈ 261.63 Hz
        XCTAssertEqual(frequency, 261.63, accuracy: 0.01)
    }

    func testFrequency_A3_ReturnsCorrectFrequency() throws {
        // Given: A3 (MIDI 57) - one octave below A4
        let a3 = try MIDINote(57)

        // When
        let frequency = a3.frequency

        // Then: A3 = 220 Hz (half of A4)
        XCTAssertEqual(frequency, 220.0, accuracy: 0.01)
    }

    func testFrequency_A5_ReturnsCorrectFrequency() throws {
        // Given: A5 (MIDI 81) - one octave above A4
        let a5 = try MIDINote(81)

        // When
        let frequency = a5.frequency

        // Then: A5 = 880 Hz (double of A4)
        XCTAssertEqual(frequency, 880.0, accuracy: 0.01)
    }

    func testFrequency_OctaveRelationship() throws {
        // Given: Two notes one octave apart
        let c4 = try MIDINote(60)
        let c5 = try MIDINote(72)

        // When
        let freqC4 = c4.frequency
        let freqC5 = c5.frequency

        // Then: C5 frequency should be exactly double C4
        XCTAssertEqual(freqC5 / freqC4, 2.0, accuracy: 0.0001)
    }

    // MARK: - Note Name Tests

    func testNoteName_MiddleC_ReturnsC4() {
        // Given
        let c4 = MIDINote.middleC

        // When
        let name = c4.noteName

        // Then
        XCTAssertEqual(name, "C4")
    }

    func testNoteName_A4_ReturnsA4() throws {
        // Given
        let a4 = try MIDINote(69)

        // When
        let name = a4.noteName

        // Then
        XCTAssertEqual(name, "A4")
    }

    func testNoteName_CSharp5_ReturnsCSharp5() throws {
        // Given: C#5 (MIDI 73)
        let cSharp5 = try MIDINote(73)

        // When
        let name = cSharp5.noteName

        // Then
        XCTAssertEqual(name, "C#5")
    }

    func testNoteName_LowNote_ReturnsCorrectOctave() throws {
        // Given: C0 (MIDI 12)
        let c0 = try MIDINote(12)

        // When
        let name = c0.noteName

        // Then
        XCTAssertEqual(name, "C0")
    }

    func testNoteName_HighNote_ReturnsCorrectOctave() throws {
        // Given: G9 (MIDI 127)
        let g9 = try MIDINote(127)

        // When
        let name = g9.noteName

        // Then
        XCTAssertEqual(name, "G9")
    }

    func testNoteName_StaticMethod() {
        // Given & When
        let name = MIDINote.noteName(for: 60)

        // Then
        XCTAssertEqual(name, "C4")
    }
}
