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

    func testFiveToneScale_DisplayName() {
        // Given
        let pattern = NotePattern.fiveToneScale

        // When
        let displayName = pattern.displayName

        // Then
        XCTAssertEqual(displayName, "五声音階")
    }
}
