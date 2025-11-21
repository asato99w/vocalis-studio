import XCTest
@testable import VocalisDomain

final class ScaleSettingsTests: XCTestCase {
    func testGenerateScale_SingleOctave() throws {
        // Given: C4 to C5, five-tone pattern
        let settings = ScaleSettings(
            startNote: try MIDINote(60),  // C4
            endNote: try MIDINote(72),    // C5
            notePattern: .fiveToneScale,
            tempo: .standard
        )
        
        // When
        let scale = settings.generateScale()
        
        // Then: 13 iterations × 9 notes = 117 notes
        XCTAssertEqual(scale.count, 117)
        
        // First scale should be C4-D4-E4-F4-G4-F4-E4-D4-C4
        XCTAssertEqual(scale[0].value, 60)  // C4
        XCTAssertEqual(scale[4].value, 67)  // G4
        XCTAssertEqual(scale[8].value, 60)  // C4
        
        // Last scale should be C5-D5-E5-F5-G5-F5-E5-D5-C5
        XCTAssertEqual(scale[108].value, 72) // C5
        XCTAssertEqual(scale[112].value, 79) // G5
        XCTAssertEqual(scale[116].value, 72) // C5
    }
    
    func testTotalDuration() throws {
        // Given
        let settings = ScaleSettings(
            startNote: .middleC,
            endNote: .hiC,
            notePattern: .fiveToneScale,
            tempo: .standard
        )
        
        // When
        let duration = settings.totalDuration
        
        // Then: 117 notes × 1 second = 117 seconds
        XCTAssertEqual(duration.seconds, 117)
    }
    
    func testMVPDefault() {
        // Given & When
        let mvp = ScaleSettings.mvpDefault
        
        // Then
        XCTAssertEqual(mvp.startNote, .middleC)
        XCTAssertEqual(mvp.endNote, .hiC)
        XCTAssertEqual(mvp.notePattern, .fiveToneScale)
        XCTAssertEqual(mvp.tempo, .standard)
    }
    
    func testCodable() throws {
        // Given
        let original = ScaleSettings.mvpDefault

        // When
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ScaleSettings.self, from: encoded)

        // Then
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Validation Tests

    func testValidate_ValidSettings_Succeeds() throws {
        // Given: Valid settings
        let settings = ScaleSettings.mvpDefault

        // When/Then: Should not throw
        XCTAssertNoThrow(try settings.validate())
    }

    func testValidate_InvalidStartNote_ThrowsError() throws {
        // Given: Invalid start note (out of MIDI range)
        let invalidNote = try MIDINote(0)  // Very low note, edge case
        let settings = ScaleSettings(
            startNote: invalidNote,
            endNote: .middleC,
            notePattern: .fiveToneScale,
            tempo: .standard
        )

        // When/Then: Should throw invalidNote error
        XCTAssertThrowsError(try settings.validate()) { error in
            guard let scaleError = error as? ScaleError else {
                XCTFail("Expected ScaleError, got \(type(of: error))")
                return
            }
            if case .invalidNote = scaleError {
                // Expected error
            } else {
                XCTFail("Expected .invalidNote, got \(scaleError)")
            }
        }
    }

    func testValidate_StartNoteHigherThanEndNote_ThrowsError() throws {
        // Given: Start note higher than end note
        let settings = ScaleSettings(
            startNote: .hiC,
            endNote: .middleC,
            notePattern: .fiveToneScale,
            tempo: .standard
        )

        // When/Then: Should throw invalidRange error
        XCTAssertThrowsError(try settings.validate()) { error in
            guard let scaleError = error as? ScaleError else {
                XCTFail("Expected ScaleError, got \(type(of: error))")
                return
            }
            if case .invalidRange = scaleError {
                // Expected error
            } else {
                XCTFail("Expected .invalidRange, got \(scaleError)")
            }
        }
    }

    func testValidate_AscendingCountTooSmall_ThrowsError() throws {
        // Given: ascendingCount less than 1
        let settings = ScaleSettings(
            startNote: .middleC,
            endNote: .hiC,
            notePattern: .fiveToneScale,
            tempo: .standard,
            ascendingCount: 0
        )

        // When/Then: Should throw invalidAscendingCount error
        XCTAssertThrowsError(try settings.validate()) { error in
            guard let scaleError = error as? ScaleError else {
                XCTFail("Expected ScaleError, got \(type(of: error))")
                return
            }
            if case .invalidAscendingCount = scaleError {
                // Expected error
            } else {
                XCTFail("Expected .invalidAscendingCount, got \(scaleError)")
            }
        }
    }

    func testValidate_AscendingCountTooLarge_ThrowsError() throws {
        // Given: ascendingCount over 24 (two octaves)
        let settings = ScaleSettings(
            startNote: .middleC,
            endNote: .hiC,
            notePattern: .fiveToneScale,
            tempo: .standard,
            ascendingCount: 25
        )

        // When/Then: Should throw invalidAscendingCount error
        XCTAssertThrowsError(try settings.validate()) { error in
            guard let scaleError = error as? ScaleError else {
                XCTFail("Expected ScaleError, got \(type(of: error))")
                return
            }
            if case .invalidAscendingCount = scaleError {
                // Expected error
            } else {
                XCTFail("Expected .invalidAscendingCount, got \(scaleError)")
            }
        }
    }

    // MARK: - Key Progression Pattern Tests

    func testKeyProgressionPattern_AscendingOnly() throws {
        // Given: Ascending only pattern with 3 steps
        let settings = ScaleSettings(
            startNote: try MIDINote(60),  // C4
            endNote: try MIDINote(72),
            notePattern: .fiveToneScale,
            tempo: .standard,
            keyProgressionPattern: .ascendingOnly,
            ascendingKeyCount: 3,
            descendingKeyCount: 0
        )

        // When
        let elements = settings.generateScaleWithKeyChange()

        // Then: Should have 3 scales (C4, C#4, D4)
        // Each scale: chord + silence + 9 notes = 11 elements
        // First scale: chordLong + silence + 9 notes = 11
        // Following: chordShort + chordLong + silence + 9 notes = 12
        // Total: 11 + 12 + 12 = 35 elements
        let scaleNoteCount = elements.filter { if case .scaleNote = $0 { return true } else { return false } }.count
        XCTAssertEqual(scaleNoteCount, 27)  // 3 scales × 9 notes
    }

    func testKeyProgressionPattern_DescendingOnly() throws {
        // Given: Descending only pattern with 3 steps
        let settings = ScaleSettings(
            startNote: try MIDINote(60),  // C4
            endNote: try MIDINote(72),
            notePattern: .fiveToneScale,
            tempo: .standard,
            keyProgressionPattern: .descendingOnly,
            ascendingKeyCount: 0,
            descendingKeyCount: 3
        )

        // When
        let elements = settings.generateScaleWithKeyChange()

        // Then: Should have 3 scales going down (C4, B3, Bb3)
        let scaleNoteCount = elements.filter { if case .scaleNote = $0 { return true } else { return false } }.count
        XCTAssertEqual(scaleNoteCount, 27)  // 3 scales × 9 notes

        // Verify descending pattern by checking root notes
        var roots: [UInt8] = []
        for element in elements {
            if case .chordLong(let notes) = element {
                roots.append(notes[0].value)
            }
        }
        XCTAssertEqual(roots, [60, 59, 58])  // C4, B3, Bb3
    }

    func testKeyProgressionPattern_AscendingThenDescending() throws {
        // Given: Ascending then descending pattern
        let settings = ScaleSettings(
            startNote: try MIDINote(60),  // C4
            endNote: try MIDINote(72),
            notePattern: .fiveToneScale,
            tempo: .standard,
            keyProgressionPattern: .ascendingThenDescending,
            ascendingKeyCount: 3,
            descendingKeyCount: 2
        )

        // When
        let elements = settings.generateScaleWithKeyChange()

        // Then: Should have 5 scales (up: C4→C#4→D4, down: C#4→C4)
        // Note: Peak (D4) is included once, not duplicated
        let scaleNoteCount = elements.filter { if case .scaleNote = $0 { return true } else { return false } }.count
        XCTAssertEqual(scaleNoteCount, 45)  // 5 scales × 9 notes

        // Verify key progression order
        var roots: [UInt8] = []
        for element in elements {
            if case .chordLong(let notes) = element {
                roots.append(notes[0].value)
            }
        }
        XCTAssertEqual(roots, [60, 61, 62, 61, 60])  // C4, C#4, D4, C#4, C4
    }

    func testKeyProgressionPattern_DescendingThenAscending() throws {
        // Given: Descending then ascending pattern
        let settings = ScaleSettings(
            startNote: try MIDINote(60),  // C4
            endNote: try MIDINote(72),
            notePattern: .fiveToneScale,
            tempo: .standard,
            keyProgressionPattern: .descendingThenAscending,
            ascendingKeyCount: 2,
            descendingKeyCount: 3
        )

        // When
        let elements = settings.generateScaleWithKeyChange()

        // Then: Should have 5 scales (down: C4→B3→Bb3, up: B3→C4)
        let scaleNoteCount = elements.filter { if case .scaleNote = $0 { return true } else { return false } }.count
        XCTAssertEqual(scaleNoteCount, 45)  // 5 scales × 9 notes

        // Verify key progression order
        var roots: [UInt8] = []
        for element in elements {
            if case .chordLong(let notes) = element {
                roots.append(notes[0].value)
            }
        }
        XCTAssertEqual(roots, [60, 59, 58, 59, 60])  // C4, B3, Bb3, B3, C4
    }

    func testBackwardsCompatibility_OldInitializer() throws {
        // Given: Using old initializer (should default to ascendingThenDescending)
        let settings = ScaleSettings(
            startNote: .middleC,
            endNote: .hiC,
            notePattern: .fiveToneScale,
            tempo: .standard,
            ascendingCount: 3
        )

        // Then: Should have default pattern
        XCTAssertEqual(settings.keyProgressionPattern, .ascendingThenDescending)
        XCTAssertEqual(settings.ascendingKeyCount, 3)
        XCTAssertEqual(settings.descendingKeyCount, 3)  // Mirrors ascending for backwards compatibility
    }
}
