import XCTest
@testable import VocalisStudio

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
}
