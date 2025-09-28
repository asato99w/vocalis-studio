import XCTest
@testable import VocalisStudio

final class RecordingTests: XCTestCase {
    
    func testRecordingInitialization() {
        // Given
        let id = RecordingId()
        let url = URL(fileURLWithPath: "/test/audio.m4a")
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(10)
        
        // When
        let recording = Recording(
            id: id,
            audioFileUrl: url,
            startTime: startTime,
            endTime: endTime
        )
        
        // Then
        XCTAssertEqual(recording.id, id)
        XCTAssertEqual(recording.audioFileUrl, url)
        XCTAssertEqual(recording.startTime, startTime)
        XCTAssertEqual(recording.endTime, endTime)
    }
    
    func testRecordingDurationCalculation() {
        // Given
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(30)
        
        // When
        let recording = Recording(
            id: RecordingId(),
            audioFileUrl: URL(fileURLWithPath: "/test.m4a"),
            startTime: startTime,
            endTime: endTime
        )
        
        // Then
        XCTAssertEqual(recording.duration?.seconds ?? 0, 30, accuracy: 0.01)
    }
    
    func testRecordingInProgress() {
        // Given & When
        let recording = Recording(
            id: RecordingId(),
            audioFileUrl: URL(fileURLWithPath: "/test.m4a"),
            startTime: Date(),
            endTime: nil
        )
        
        // Then
        XCTAssertTrue(recording.isInProgress)
        XCTAssertNil(recording.duration)
    }
    
    func testRecordingCompletion() {
        // Given
        var recording = Recording(
            id: RecordingId(),
            audioFileUrl: URL(fileURLWithPath: "/test.m4a"),
            startTime: Date(),
            endTime: nil
        )
        
        // When
        let endTime = Date().addingTimeInterval(10)
        recording.complete(at: endTime)
        
        // Then
        XCTAssertFalse(recording.isInProgress)
        XCTAssertNotNil(recording.duration)
        XCTAssertEqual(recording.endTime, endTime)
    }
}