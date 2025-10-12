import XCTest
import Combine
@testable import VocalisStudio

@MainActor
final class RecordingViewModelTests: XCTestCase {

    var sut: RecordingViewModel!
    var mockStartRecordingUseCase: MockStartRecordingWithScaleUseCase!
    var mockStopRecordingUseCase: MockStopRecordingUseCase!
    var mockAudioPlayer: MockAudioPlayer!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        try await super.setUp()
        mockStartRecordingUseCase = MockStartRecordingWithScaleUseCase()
        mockStopRecordingUseCase = MockStopRecordingUseCase()
        mockAudioPlayer = MockAudioPlayer()
        sut = RecordingViewModel(
            startRecordingUseCase: mockStartRecordingUseCase,
            stopRecordingUseCase: mockStopRecordingUseCase,
            audioPlayer: mockAudioPlayer
        )
        cancellables = []
    }

    override func tearDown() async throws {
        cancellables = nil
        sut = nil
        mockAudioPlayer = nil
        mockStopRecordingUseCase = nil
        mockStartRecordingUseCase = nil
        try await super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState_IsIdle() {
        XCTAssertEqual(sut.recordingState, .idle)
        XCTAssertNil(sut.currentSession)
        XCTAssertNil(sut.errorMessage)
    }

    // MARK: - Start Recording Tests

    func testStartRecording_TransitionsToCountdown() async {
        // When
        await sut.startRecording()

        // Then
        // Should immediately transition to countdown
        XCTAssertEqual(sut.recordingState, .countdown)
    }

    func testStartRecording_CountdownCompletesAndStartsRecording() async {
        // Given
        let settings = ScaleSettings.mvpDefault
        mockStartRecordingUseCase.executeResult = RecordingSession(
            recordingURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            settings: settings
        )

        // When
        await sut.startRecording()

        // Wait for countdown (3 seconds) + execution
        try? await Task.sleep(nanoseconds: 3_500_000_000) // 3.5 seconds

        // Then
        XCTAssertEqual(sut.recordingState, .recording)
        XCTAssertNotNil(sut.currentSession)
        XCTAssertTrue(mockStartRecordingUseCase.executeCalled)
    }

    func testStartRecording_UseCaseFailure_ShowsError() async {
        // Given
        mockStartRecordingUseCase.executeShouldFail = true

        // When
        await sut.startRecording()

        // Wait for countdown + execution
        try? await Task.sleep(nanoseconds: 3_500_000_000)

        // Then
        XCTAssertEqual(sut.recordingState, .idle)
        XCTAssertNotNil(sut.errorMessage)
    }

    func testStartRecording_WhileRecording_DoesNothing() async {
        // Given
        mockStartRecordingUseCase.executeResult = RecordingSession(
            recordingURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            settings: .mvpDefault
        )
        await sut.startRecording()
        try? await Task.sleep(nanoseconds: 3_500_000_000)

        let initialSession = sut.currentSession

        // When
        await sut.startRecording()

        // Then
        XCTAssertEqual(sut.recordingState, .recording)
        XCTAssertEqual(sut.currentSession?.recordingURL, initialSession?.recordingURL)
    }

    // MARK: - Cancel Countdown Tests

    func testCancelCountdown_DuringCountdown_ReturnsToIdle() async {
        // Given
        await sut.startRecording()
        XCTAssertEqual(sut.recordingState, .countdown)

        // When
        await sut.cancelCountdown()

        // Then
        XCTAssertEqual(sut.recordingState, .idle)
        XCTAssertFalse(mockStartRecordingUseCase.executeCalled)
    }

    func testCancelCountdown_NotDuringCountdown_DoesNothing() async {
        // Given
        XCTAssertEqual(sut.recordingState, .idle)

        // When
        await sut.cancelCountdown()

        // Then
        XCTAssertEqual(sut.recordingState, .idle)
    }

    // MARK: - Stop Recording Tests

    func testStopRecording_WhileRecording_TransitionsToIdle() async {
        // Given
        mockStartRecordingUseCase.executeResult = RecordingSession(
            recordingURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            settings: .mvpDefault
        )
        await sut.startRecording()
        try? await Task.sleep(nanoseconds: 3_500_000_000)
        XCTAssertEqual(sut.recordingState, .recording)

        // When
        await sut.stopRecording()

        // Then
        XCTAssertEqual(sut.recordingState, .idle)
        XCTAssertNil(sut.currentSession)
    }

    func testStopRecording_NotRecording_DoesNothing() async {
        // Given
        XCTAssertEqual(sut.recordingState, .idle)

        // When
        await sut.stopRecording()

        // Then
        XCTAssertEqual(sut.recordingState, .idle)
    }

    // MARK: - Progress Tests

    func testProgress_InitiallyZero() {
        XCTAssertEqual(sut.progress, 0.0)
    }

    // MARK: - Countdown Tests

    func testCountdownValue_InitiallyThree() {
        XCTAssertEqual(sut.countdownValue, 3)
    }

    func testCountdown_DecrementsFromThreeToOne() async {
        // When
        await sut.startRecording()

        // Check initial countdown
        XCTAssertEqual(sut.countdownValue, 3)

        // Wait 1 second
        try? await Task.sleep(nanoseconds: 1_100_000_000)
        XCTAssertEqual(sut.countdownValue, 2)

        // Wait another second
        try? await Task.sleep(nanoseconds: 1_100_000_000)
        XCTAssertEqual(sut.countdownValue, 1)
    }
}
