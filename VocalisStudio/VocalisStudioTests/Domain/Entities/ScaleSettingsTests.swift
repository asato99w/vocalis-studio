import XCTest
@testable import VocalisStudio

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
}
