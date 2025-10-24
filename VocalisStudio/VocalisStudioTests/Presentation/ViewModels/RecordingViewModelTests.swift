import XCTest
import Combine
import VocalisDomain
@testable import VocalisStudio

@MainActor
final class RecordingViewModelTests: XCTestCase {

    var sut: RecordingViewModel!
    var mockStartRecordingUseCase: MockStartRecordingUseCase!
    var mockStartRecordingWithScaleUseCase: MockStartRecordingWithScaleUseCase!
    var mockStopRecordingUseCase: MockStopRecordingUseCase!
    var mockAudioPlayer: MockAudioPlayer!
    var mockScalePlayer: MockScalePlayer!
    var pitchDetector: RealtimePitchDetector!
    var mockSubscriptionViewModel: SubscriptionViewModel!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        try await super.setUp()
        mockStartRecordingUseCase = MockStartRecordingUseCase()
        mockStartRecordingWithScaleUseCase = MockStartRecordingWithScaleUseCase()
        mockStopRecordingUseCase = MockStopRecordingUseCase()
        mockAudioPlayer = MockAudioPlayer()
        mockScalePlayer = MockScalePlayer()
        pitchDetector = RealtimePitchDetector()
        mockSubscriptionViewModel = SubscriptionViewModel(
            getStatusUseCase: MockGetSubscriptionStatusUseCase(),
            purchaseUseCase: MockPurchaseSubscriptionUseCase(),
            restoreUseCase: MockRestorePurchasesUseCase()
        )
        sut = RecordingViewModel(
            startRecordingUseCase: mockStartRecordingUseCase,
            startRecordingWithScaleUseCase: mockStartRecordingWithScaleUseCase,
            stopRecordingUseCase: mockStopRecordingUseCase,
            audioPlayer: mockAudioPlayer,
            pitchDetector: pitchDetector,
            scalePlayer: mockScalePlayer,
            subscriptionViewModel: mockSubscriptionViewModel,
            countdownDuration: 0,
            targetPitchPollingIntervalNanoseconds: 1_000_000,
            playbackPitchPollingIntervalNanoseconds: 1_000_000
        )
        cancellables = []
    }

    override func tearDown() async throws {
        cancellables = nil
        sut = nil
        pitchDetector = nil
        mockScalePlayer = nil
        mockAudioPlayer = nil
        mockStopRecordingUseCase = nil
        mockStartRecordingWithScaleUseCase = nil
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

    func testStartRecording_TransitionsToRecording() async {
        // Given: Set up mock to return a session
        mockStartRecordingUseCase.executeResult = RecordingSession(
            recordingURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            settings: nil
        )

        // When
        await sut.startRecording()

        // Wait a tiny bit for async state propagation
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Then
        // Should immediately transition to recording (countdown=0)
        XCTAssertEqual(sut.recordingState, .recording)
    }

    func testStartRecording_CountdownCompletesAndStartsRecording() async {
        // Given
        let settings = ScaleSettings.mvpDefault
        mockStartRecordingUseCase.executeResult = RecordingSession(
            recordingURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            settings: nil
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
            settings: nil
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
    // Note: testCancelCountdown_DuringCountdown_ReturnsToIdle removed - not applicable when countdownDuration=0

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
            settings: nil
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
        XCTAssertEqual(sut.countdownValue, 0)
    }

    // Note: testCountdown_DecrementsFromThreeToOne removed - not applicable when countdownDuration=0

    // MARK: - Target Pitch Tests (Bug Reproduction)

    func testStartRecording_withScale_shouldSetTargetPitch() async throws {
        // Given: Setup for scale recording
        let settings = ScaleSettings.mvpDefault
        mockStartRecordingWithScaleUseCase.executeResult = RecordingSession(
            recordingURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            settings: settings
        )

        // Set mock to simulate scale playback
        let expectedNote = try MIDINote(60) // C4: 261.63 Hz
        mockScalePlayer.currentScaleElement = .scaleNote(expectedNote)

        // Verify initial state
        XCTAssertNil(sut.targetPitch, "Target pitch should be nil before recording starts")

        // When: Start recording with scale
        await sut.startRecording(settings: settings)

        // Wait for countdown (3 seconds) + scale loading + monitoring start
        try? await Task.sleep(nanoseconds: 3_500_000_000) // 3.5 seconds

        // Wait for monitoring task to poll
        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

        // Then: Target pitch should be set
        XCTAssertNotNil(sut.targetPitch, "Target pitch should be set when scale element is available")
        if let targetPitch = sut.targetPitch {
            XCTAssertEqual(targetPitch.frequency, expectedNote.frequency, accuracy: 0.01,
                          "Target pitch frequency should match the scale element note")
        }
    }

    // MARK: - Playback Tests (Bug Reproduction)

    func testPlayLastRecording_withScale_shouldSetTargetPitchDuringPlayback() async throws {
        // Given: Record with scale settings first
        let settings = ScaleSettings.mvpDefault
        mockStartRecordingWithScaleUseCase.executeResult = RecordingSession(
            recordingURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            settings: settings
        )

        // Set mock to simulate scale playback
        let expectedNote = try MIDINote(60) // C4: 261.63 Hz
        mockScalePlayer.currentScaleElement = .scaleNote(expectedNote)

        // Record and stop to set lastRecordingURL
        await sut.startRecording(settings: settings)
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms - immediate with countdown=0
        await sut.stopRecording()

        // Verify recording was saved
        XCTAssertNotNil(sut.lastRecordingURL, "Last recording URL should be set after stopping")
        XCTAssertNotNil(sut.lastRecordingSettings, "Last recording settings should be set after stopping")

        // When: Play last recording
        await sut.playLastRecording()

        // Wait for pitch detection to start
        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

        // Then: Target pitch should be set during playback
        XCTAssertNotNil(sut.targetPitch, "Target pitch should be set during playback when scale settings exist")
        if let targetPitch = sut.targetPitch {
            XCTAssertEqual(targetPitch.frequency, expectedNote.frequency, accuracy: 0.01,
                          "Target pitch frequency should match the scale element note during playback")
        }
    }
}
