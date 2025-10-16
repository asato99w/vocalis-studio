import XCTest
import VocalisDomain
@testable import VocalisStudio

final class StopRecordingUseCaseTests: XCTestCase {

    var sut: StopRecordingUseCase!
    var mockAudioRecorder: MockAudioRecorder!
    var mockScalePlayer: MockScalePlayer!
    var mockRecordingRepository: MockRecordingRepository!

    override func setUp() {
        super.setUp()
        mockAudioRecorder = MockAudioRecorder()
        mockScalePlayer = MockScalePlayer()
        mockRecordingRepository = MockRecordingRepository()
        sut = StopRecordingUseCase(
            audioRecorder: mockAudioRecorder,
            scalePlayer: mockScalePlayer,
            recordingRepository: mockRecordingRepository
        )
    }

    override func tearDown() {
        sut = nil
        mockRecordingRepository = nil
        mockScalePlayer = nil
        mockAudioRecorder = nil
        super.tearDown()
    }

    // MARK: - Success Path Tests

    func testExecute_RecordingInProgress_StopsRecordingAndReturnsResult() async throws {
        // Given
        mockAudioRecorder._isRecording = true
        mockAudioRecorder.stopRecordingResult = 5.5

        // When
        let result = try await sut.execute()

        // Then
        XCTAssertTrue(mockAudioRecorder.stopRecordingCalled)
        XCTAssertEqual(result.duration, 5.5)
    }

    func testExecute_CallsStopRecordingOnAudioRecorder() async throws {
        // Given
        mockAudioRecorder._isRecording = true
        mockAudioRecorder.stopRecordingResult = 3.0

        // When
        _ = try await sut.execute()

        // Then
        XCTAssertTrue(mockAudioRecorder.stopRecordingCalled)
    }

    func testExecute_ReturnsDurationFromAudioRecorder() async throws {
        // Given
        mockAudioRecorder._isRecording = true
        let expectedDuration = 7.25
        mockAudioRecorder.stopRecordingResult = expectedDuration

        // When
        let result = try await sut.execute()

        // Then
        XCTAssertEqual(result.duration, expectedDuration)
    }

    // MARK: - Error Handling Tests

    func testExecute_NotRecording_ThrowsError() async {
        // Given
        mockAudioRecorder._isRecording = false
        mockAudioRecorder.stopRecordingShouldFail = true

        // When/Then
        do {
            _ = try await sut.execute()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is AudioRecorderError)
        }
    }

    func testExecute_StopRecordingFails_ThrowsError() async {
        // Given
        mockAudioRecorder._isRecording = true
        mockAudioRecorder.stopRecordingShouldFail = true

        // When/Then
        do {
            _ = try await sut.execute()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is AudioRecorderError)
        }
    }
}
