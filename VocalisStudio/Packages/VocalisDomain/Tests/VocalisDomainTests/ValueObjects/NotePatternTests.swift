import XCTest
@testable import VocalisDomain

final class NotePatternTests: XCTestCase {
    func testFiveToneScale_Intervals() {
        // Given
        let pattern = NotePattern.fiveToneScale
        
        // When
        let intervals = pattern.intervals
        
        // Then
        XCTAssertEqual(intervals, [0, 2, 4, 5, 7])
    }
    
    func testFiveToneScale_AscendingDescending() {
        // Given
        let pattern = NotePattern.fiveToneScale

        // When
        let ascDesc = pattern.ascendingDescending()

        // Then
        // Expected: [0, 2, 4, 5, 7, 5, 4, 2, 0] (C-D-E-F-G-F-E-D-C)
        XCTAssertEqual(ascDesc.count, 9)
        XCTAssertEqual(ascDesc, [0, 2, 4, 5, 7, 5, 4, 2, 0])
    }

    func testFiveToneScale_PlaybackPattern() {
        // Given
        let pattern = NotePattern.fiveToneScale

        // When
        let playback = pattern.playbackPattern

        // Then
        // playbackPattern should return the same as ascendingDescending for fiveToneScale
        XCTAssertEqual(playback, [0, 2, 4, 5, 7, 5, 4, 2, 0])
    }

    func testFiveToneScale_DisplayName() {
        // Given
        let pattern = NotePattern.fiveToneScale

        // When
        let displayName = pattern.displayName

        // Then
        XCTAssertEqual(displayName, "五声音階")
    }

    // MARK: - OctaveRepeat Tests

    func testOctaveRepeat_Intervals() {
        // Given
        let pattern = NotePattern.octaveRepeat

        // When
        let intervals = pattern.intervals

        // Then
        // Major triad + octave: C, E, G, C
        XCTAssertEqual(intervals, [0, 4, 7, 12])
    }

    func testOctaveRepeat_PlaybackPattern() {
        // Given
        let pattern = NotePattern.octaveRepeat

        // When
        let playback = pattern.playbackPattern

        // Then
        // Ascending + top 4 times + descending
        XCTAssertEqual(playback, [0, 4, 7, 12, 12, 12, 12, 7, 4, 0])
    }

    func testOctaveRepeat_DisplayName() {
        // Given
        let pattern = NotePattern.octaveRepeat

        // When
        let displayName = pattern.displayName

        // Then
        XCTAssertEqual(displayName, "オクターブリピート")
    }
}
