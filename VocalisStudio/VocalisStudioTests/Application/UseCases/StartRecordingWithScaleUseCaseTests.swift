import XCTest
import VocalisDomain
@testable import VocalisStudio

final class StartRecordingWithScaleUseCaseTests: XCTestCase {

    var sut: StartRecordingWithScaleUseCase!
    var mockScalePlayer: MockScalePlayer!
    var mockAudioRecorder: MockAudioRecorder!

    override func setUp() {
        super.setUp()
        mockScalePlayer = MockScalePlayer()
        mockAudioRecorder = MockAudioRecorder()
        sut = StartRecordingWithScaleUseCase(
            scalePlayer: mockScalePlayer,
            audioRecorder: mockAudioRecorder
        )
    }

    override func tearDown() {
        sut = nil
        mockAudioRecorder = nil
        mockScalePlayer = nil
        super.tearDown()
    }

    // MARK: - Success Path Tests

    func testExecute_ValidSettings_ReturnsRecordingSession() async throws {
        // Given
        let settings = ScaleSettings.mvpDefault
        let expectedURL = URL(fileURLWithPath: "/tmp/test.m4a")
        mockAudioRecorder.prepareRecordingResult = expectedURL

        // When
        let session = try await sut.execute(settings: settings)

        // Then
        XCTAssertEqual(session.recordingURL, expectedURL)
        XCTAssertEqual(session.settings, settings)
        XCTAssertTrue(mockAudioRecorder.prepareRecordingCalled)
        XCTAssertTrue(mockScalePlayer.loadScaleCalled)
        XCTAssertTrue(mockAudioRecorder.startRecordingCalled)
        XCTAssertTrue(mockScalePlayer.playCalled)
    }

    func testExecute_LoadsCorrectScale() async throws {
        // Given
        let settings = ScaleSettings.mvpDefault
        mockAudioRecorder.prepareRecordingResult = URL(fileURLWithPath: "/tmp/test.m4a")

        // When
        _ = try await sut.execute(settings: settings)

        // Then
        // Extract expected notes from scale elements (including chords)
        let scaleElements = settings.generateScaleWithKeyChange()
        var expectedNotes: [MIDINote] = []
        for element in scaleElements {
            switch element {
            case .scaleNote(let note):
                expectedNotes.append(note)
            case .chordShort(let notes), .chordLong(let notes):
                expectedNotes.append(contentsOf: notes)
            case .silence:
                break
            }
        }

        XCTAssertEqual(mockScalePlayer.loadedNotes, expectedNotes)
        XCTAssertEqual(mockScalePlayer.loadedTempo, settings.tempo)
    }

    func testExecute_CallsInCorrectOrder() async throws {
        // Given
        let settings = ScaleSettings.mvpDefault
        mockAudioRecorder.prepareRecordingResult = URL(fileURLWithPath: "/tmp/test.m4a")

        // When
        _ = try await sut.execute(settings: settings)

        // Wait a moment for async play to be called
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Then
        // Verify all methods were called
        XCTAssertTrue(mockAudioRecorder.prepareRecordingCalled)
        XCTAssertTrue(mockScalePlayer.loadScaleCalled)
        XCTAssertTrue(mockAudioRecorder.startRecordingCalled)
        XCTAssertTrue(mockScalePlayer.playCalled)

        // Verify synchronous call order (before execute returns)
        // prepare -> load -> start recording must happen before execute returns
        XCTAssertLessThan(
            mockAudioRecorder.prepareRecordingCallTime!,
            mockScalePlayer.loadScaleCallTime!
        )
        XCTAssertLessThan(
            mockScalePlayer.loadScaleCallTime!,
            mockAudioRecorder.startRecordingCallTime!
        )
        // play is async, so we don't assert its timing relative to others
    }

    // MARK: - Error Handling Tests

    func testExecute_PrepareRecordingFails_ThrowsError() async {
        // Given
        let settings = ScaleSettings.mvpDefault
        mockAudioRecorder.prepareRecordingShouldFail = true

        // When/Then
        do {
            _ = try await sut.execute(settings: settings)
            XCTFail("Expected error to be thrown")
        } catch {
            // Error thrown as expected
            XCTAssertTrue(mockAudioRecorder.prepareRecordingCalled)
            XCTAssertFalse(mockScalePlayer.loadScaleCalled)
        }
    }

    func testExecute_LoadScaleFails_ThrowsError() async {
        // Given
        let settings = ScaleSettings.mvpDefault
        mockAudioRecorder.prepareRecordingResult = URL(fileURLWithPath: "/tmp/test.m4a")
        mockScalePlayer.loadScaleShouldFail = true

        // When/Then
        do {
            _ = try await sut.execute(settings: settings)
            XCTFail("Expected error to be thrown")
        } catch {
            // Error thrown as expected
            XCTAssertTrue(mockScalePlayer.loadScaleCalled)
            XCTAssertFalse(mockAudioRecorder.startRecordingCalled)
        }
    }

    func testExecute_StartRecordingFails_ThrowsError() async {
        // Given
        let settings = ScaleSettings.mvpDefault
        mockAudioRecorder.prepareRecordingResult = URL(fileURLWithPath: "/tmp/test.m4a")
        mockAudioRecorder.startRecordingShouldFail = true

        // When/Then
        do {
            _ = try await sut.execute(settings: settings)
            XCTFail("Expected error to be thrown")
        } catch {
            // Error thrown as expected
            XCTAssertTrue(mockAudioRecorder.startRecordingCalled)
            XCTAssertFalse(mockScalePlayer.playCalled)
        }
    }

    func testExecute_PlayStartsAsynchronously() async throws {
        // Given
        let settings = ScaleSettings.mvpDefault
        mockAudioRecorder.prepareRecordingResult = URL(fileURLWithPath: "/tmp/test.m4a")

        // When
        let session = try await sut.execute(settings: settings)

        // Then
        // execute() returns immediately without waiting for playback to complete
        XCTAssertNotNil(session)
        XCTAssertTrue(mockAudioRecorder.startRecordingCalled)

        // Wait a bit for async play to be called
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        XCTAssertTrue(mockScalePlayer.playCalled)
    }
}
