import XCTest
@testable import VocalisDomain

final class RecordingTests: XCTestCase {
    func testInit_DefaultValues() {
        // Given
        let url = URL(fileURLWithPath: "/test/recording.m4a")
        let duration = Duration(seconds: 117)
        let settings = ScaleSettings.mvpDefault
        
        // When
        let recording = Recording(
            fileURL: url,
            duration: duration,
            scaleSettings: settings
        )
        
        // Then
        XCTAssertNotNil(recording.id)
        XCTAssertEqual(recording.fileURL, url)
        XCTAssertEqual(recording.duration, duration)
        XCTAssertEqual(recording.scaleSettings, settings)
    }
    
    func testIdentifiable() {
        // Given
        let recording1 = Recording(
            fileURL: URL(fileURLWithPath: "/test1.m4a"),
            duration: Duration(seconds: 100),
            scaleSettings: .mvpDefault
        )
        let recording2 = Recording(
            fileURL: URL(fileURLWithPath: "/test2.m4a"),
            duration: Duration(seconds: 100),
            scaleSettings: .mvpDefault
        )
        
        // When & Then
        XCTAssertNotEqual(recording1.id, recording2.id)
    }
    
    func testFormattedDate() {
        // Given
        let date = Date()
        let recording = Recording(
            fileURL: URL(fileURLWithPath: "/test.m4a"),
            createdAt: date,
            duration: Duration(seconds: 100),
            scaleSettings: .mvpDefault
        )
        
        // When
        let formatted = recording.formattedDate
        
        // Then
        XCTAssertFalse(formatted.isEmpty)
    }
    
    func testCodable() throws {
        // Given
        let original = Recording(
            id: RecordingId(),
            fileURL: URL(fileURLWithPath: "/test.m4a"),
            createdAt: Date(),
            duration: Duration(seconds: 117),
            scaleSettings: .mvpDefault
        )

        // When
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Recording.self, from: encoded)

        // Then
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.fileURL, original.fileURL)
        XCTAssertEqual(decoded.duration.seconds, original.duration.seconds, accuracy: 0.001)
        XCTAssertEqual(decoded.scaleSettings, original.scaleSettings)
    }

    func testScaleDisplayName_WithScaleSettings() throws {
        // Given
        let settings = ScaleSettings(
            startNote: try MIDINote(60),  // C4
            endNote: try MIDINote(72),
            notePattern: .fiveToneScale,
            tempo: .standard,
            ascendingCount: 12
        )
        let recording = Recording(
            fileURL: URL(fileURLWithPath: "/test.m4a"),
            duration: Duration(seconds: 100),
            scaleSettings: settings
        )

        // When
        let displayName = recording.scaleDisplayName

        // Then
        XCTAssertEqual(displayName, "C4 五声音階")
    }

    func testScaleDisplayName_WithoutScaleSettings() {
        // Given
        let recording = Recording(
            fileURL: URL(fileURLWithPath: "/test.m4a"),
            duration: Duration(seconds: 100),
            scaleSettings: nil
        )

        // When
        let displayName = recording.scaleDisplayName

        // Then
        XCTAssertNil(displayName)
    }
}
