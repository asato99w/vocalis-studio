import XCTest
import Combine
@testable import VocalisStudio
@testable import VocalisDomain

@MainActor
final class RecordingStateViewModelTests: XCTestCase {
    var sut: RecordingStateViewModel!
    var mockStartRecordingUseCase: RecordingStateMockStartRecordingUseCase!
    var mockStartRecordingWithScaleUseCase: RecordingStateMockStartRecordingWithScaleUseCase!
    var mockStopRecordingUseCase: RecordingStateMockStopRecordingUseCase!
    var mockAudioPlayer: RecordingStateMockAudioPlayer!
    var mockScalePlayer: RecordingStateMockScalePlayer!
    var mockSubscriptionViewModel: SubscriptionViewModel!
    var mockUsageTracker: RecordingStateMockUsageTracker!
    var mockLimitConfig: RecordingStateMockLimitConfig!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        mockStartRecordingUseCase = RecordingStateMockStartRecordingUseCase()
        mockStartRecordingWithScaleUseCase = RecordingStateMockStartRecordingWithScaleUseCase()
        mockStopRecordingUseCase = RecordingStateMockStopRecordingUseCase()
        mockAudioPlayer = RecordingStateMockAudioPlayer()
        mockScalePlayer = RecordingStateMockScalePlayer()
        mockUsageTracker = RecordingStateMockUsageTracker()
        mockLimitConfig = RecordingStateMockLimitConfig()
        cancellables = Set<AnyCancellable>()

        // Create subscription view model with mock repository
        let mockSubscriptionRepository = MockSubscriptionRepository()
        mockSubscriptionViewModel = SubscriptionViewModel(
            getStatusUseCase: GetSubscriptionStatusUseCase(repository: mockSubscriptionRepository),
            purchaseUseCase: PurchaseSubscriptionUseCase(repository: mockSubscriptionRepository),
            restoreUseCase: RestorePurchasesUseCase(repository: mockSubscriptionRepository)
        )

        sut = RecordingStateViewModel(
            startRecordingUseCase: mockStartRecordingUseCase,
            startRecordingWithScaleUseCase: mockStartRecordingWithScaleUseCase,
            stopRecordingUseCase: mockStopRecordingUseCase,
            audioPlayer: mockAudioPlayer,
            scalePlayer: mockScalePlayer,
            subscriptionViewModel: mockSubscriptionViewModel,
            usageTracker: mockUsageTracker,
            limitConfig: mockLimitConfig
        )
    }

    override func tearDown() {
        cancellables = nil
        sut = nil
        mockLimitConfig = nil
        mockUsageTracker = nil
        mockSubscriptionViewModel = nil
        mockScalePlayer = nil
        mockAudioPlayer = nil
        mockStopRecordingUseCase = nil
        mockStartRecordingWithScaleUseCase = nil
        mockStartRecordingUseCase = nil
    }

    // MARK: - Initialization Tests

    func testInit_shouldSetInitialState() {
        XCTAssertEqual(sut.recordingState, .idle)
        XCTAssertNil(sut.currentSession)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(sut.progress, 0.0)
        XCTAssertEqual(sut.countdownValue, 3)
        XCTAssertEqual(sut.currentTier, .free)
        XCTAssertEqual(sut.dailyRecordingCount, 0)
    }

    // MARK: - Start Recording Tests

    func testStartRecording_withoutScale_shouldStartCountdown() async {
        // When
        await sut.startRecording(settings: nil)

        // Then
        XCTAssertEqual(sut.recordingState, .countdown)
        XCTAssertEqual(sut.countdownValue, 3)
    }

    func testStartRecording_withScale_shouldStartCountdownAndExecute() async throws {
        // Given
        let settings = try ScaleSettings(scale: .cMajor, tempo: try Tempo(secondsPerNote: 0.5))
        let expectedSession = RecordingSession(
            id: RecordingSessionId(),
            recordingURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            settings: settings
        )
        mockStartRecordingWithScaleUseCase.sessionToReturn = expectedSession

        // When
        await sut.startRecording(settings: settings)

        // Wait for countdown and execution
        try await Task.sleep(nanoseconds: 3_500_000_000) // 3.5 seconds

        // Then
        XCTAssertTrue(mockStartRecordingWithScaleUseCase.executeCalled)
        XCTAssertEqual(sut.recordingState, .recording)
        XCTAssertNotNil(sut.currentSession)
    }

    func testStartRecording_whenAlreadyRecording_shouldIgnore() async {
        // Given: Simulate recording state
        await sut.startRecording(settings: nil)
        try? await Task.sleep(nanoseconds: 3_500_000_000)

        let initialState = sut.recordingState

        // When: Try to start again
        await sut.startRecording(settings: nil)

        // Then: Should not change state
        XCTAssertEqual(sut.recordingState, initialState)
    }

    func testStartRecording_whenLimitReached_shouldShowError() async {
        // Given: Set count at limit
        mockUsageTracker.todayCount = 10
        mockLimitConfig.limit = RecordingLimit(maxCount: 10, maxDurationSeconds: 60)

        // When
        await sut.startRecording(settings: nil)

        // Then
        XCTAssertEqual(sut.recordingState, .idle)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.errorMessage?.contains("上限に達しました") ?? false)
    }

    // MARK: - Cancel Countdown Tests

    func testCancelCountdown_duringCountdown_shouldReturnToIdle() async {
        // Given
        await sut.startRecording(settings: nil)
        XCTAssertEqual(sut.recordingState, .countdown)

        // When
        await sut.cancelCountdown()

        // Then
        XCTAssertEqual(sut.recordingState, .idle)
        XCTAssertEqual(sut.countdownValue, 3)
    }

    // MARK: - Stop Recording Tests

    func testStopRecording_shouldStopAndSaveURL() async throws {
        // Given: Start recording first
        let expectedURL = URL(fileURLWithPath: "/tmp/test.m4a")
        let settings = try ScaleSettings(scale: .cMajor, tempo: try Tempo(secondsPerNote: 0.5))
        let session = RecordingSession(
            id: RecordingSessionId(),
            recordingURL: expectedURL,
            settings: settings
        )
        mockStartRecordingWithScaleUseCase.sessionToReturn = session

        await sut.startRecording(settings: settings)
        try await Task.sleep(nanoseconds: 3_500_000_000) // Wait for countdown

        // When
        await sut.stopRecording()

        // Then
        XCTAssertTrue(mockStopRecordingUseCase.executeCalled)
        XCTAssertEqual(sut.recordingState, .idle)
        XCTAssertNil(sut.currentSession)
        XCTAssertEqual(sut.progress, 0.0)
        XCTAssertEqual(sut.lastRecordingURL, expectedURL)
        XCTAssertEqual(sut.dailyRecordingCount, 1) // Should be incremented
    }

    // MARK: - Playback Tests

    func testPlayLastRecording_withValidURL_shouldStartPlayback() async throws {
        // Given: Set up a last recording
        let url = URL(fileURLWithPath: "/tmp/test.m4a")
        let settings = try ScaleSettings(scale: .cMajor, tempo: try Tempo(secondsPerNote: 0.5))
        let session = RecordingSession(
            id: RecordingSessionId(),
            recordingURL: url,
            settings: settings
        )
        mockStartRecordingWithScaleUseCase.sessionToReturn = session

        // Record and stop to set lastRecordingURL
        await sut.startRecording(settings: settings)
        try await Task.sleep(nanoseconds: 3_500_000_000)
        await sut.stopRecording()

        // When
        await sut.playLastRecording()

        // Then
        XCTAssertTrue(mockAudioPlayer.playCalled)
        XCTAssertTrue(mockScalePlayer.loadScaleElementsCalled)
    }

    func testPlayLastRecording_withNoRecording_shouldShowError() async {
        // When
        await sut.playLastRecording()

        // Then
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(mockAudioPlayer.playCalled)
    }

    func testStopPlayback_shouldStopAudioPlayer() {
        // When
        sut.stopPlayback()

        // Then
        XCTAssertTrue(mockAudioPlayer.stopCalled)
        XCTAssertFalse(sut.isPlayingRecording)
    }

    // MARK: - Duration Monitoring Tests

    func testRecording_shouldUpdateProgress() async throws {
        // Given
        let settings = try ScaleSettings(scale: .cMajor, tempo: try Tempo(secondsPerNote: 0.5))
        let session = RecordingSession(
            id: RecordingSessionId(),
            recordingURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            settings: settings
        )
        mockStartRecordingWithScaleUseCase.sessionToReturn = session

        // When: Start recording and wait
        await sut.startRecording(settings: settings)
        try await Task.sleep(nanoseconds: 3_500_000_000) // Wait for countdown

        // Wait a bit for progress to update
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Then: Progress should have increased
        XCTAssertGreaterThan(sut.progress, 0.0)
    }
}

// MARK: - Mock Objects

class RecordingStateMockStartRecordingUseCase: StartRecordingUseCaseProtocol {
    var executeCalled = false
    var sessionToReturn: RecordingSession?

    func execute() async throws -> RecordingSession {
        executeCalled = true
        if let session = sessionToReturn {
            return session
        }
        return RecordingSession(
            id: RecordingSessionId(),
            recordingURL: URL(fileURLWithPath: "/tmp/default.m4a"),
            settings: nil
        )
    }
}

class RecordingStateMockStartRecordingWithScaleUseCase: StartRecordingWithScaleUseCaseProtocol {
    var executeCalled = false
    var sessionToReturn: RecordingSession?

    func execute(settings: ScaleSettings) async throws -> RecordingSession {
        executeCalled = true
        if let session = sessionToReturn {
            return session
        }
        return RecordingSession(
            id: RecordingSessionId(),
            recordingURL: URL(fileURLWithPath: "/tmp/default.m4a"),
            settings: settings
        )
    }
}

class RecordingStateMockStopRecordingUseCase: StopRecordingUseCaseProtocol {
    var executeCalled = false

    func execute() async throws -> Recording {
        executeCalled = true
        return Recording(
            id: RecordingId(),
            createdAt: Date(),
            duration: Duration(seconds: 5.0),
            fileURL: URL(fileURLWithPath: "/tmp/test.m4a")
        )
    }
}

class RecordingStateMockAudioPlayer: AudioPlayerProtocol {
    var isPlaying: Bool = false
    var currentTime: Double = 0.0
    var playCalled = false
    var stopCalled = false

    func play(url: URL) async throws {
        playCalled = true
        isPlaying = true
    }

    func pause() {
        isPlaying = false
    }

    func stop() {
        stopCalled = true
        isPlaying = false
        currentTime = 0.0
    }

    func seek(to time: Double) {
        currentTime = time
    }
}

class RecordingStateMockScalePlayer: ScalePlayerProtocol {
    var isPlaying: Bool = false
    var currentNoteIndex: Int = 0
    var progress: Double = 0.0
    var currentScaleElement: ScaleElement?
    var loadScaleElementsCalled = false

    func loadScale(_ notes: [MIDINote], tempo: Tempo) async throws {
        // Not used
    }

    func loadScaleElements(_ elements: [ScaleElement], tempo: Tempo) async throws {
        loadScaleElementsCalled = true
    }

    func play(muted: Bool) async throws {
        isPlaying = true
    }

    func stop() async {
        isPlaying = false
    }
}

class RecordingStateMockUsageTracker: RecordingUsageTracker {
    var todayCount: Int = 0
    var incrementCalled = false

    override func getTodayCount() -> Int {
        return todayCount
    }

    override func incrementCount() {
        incrementCalled = true
        todayCount += 1
    }
}

class RecordingStateMockLimitConfig: RecordingLimitConfigProtocol {
    var limit: RecordingLimit = RecordingLimit(maxCount: 100, maxDurationSeconds: 60)

    func limitForTier(_ tier: SubscriptionTier) -> RecordingLimit {
        return limit
    }
}
