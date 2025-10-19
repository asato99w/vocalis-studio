import XCTest
import VocalisDomain
@testable import VocalisStudio

final class AnalysisViewModelTests: XCTestCase {
    var sut: AnalysisViewModel!
    var mockAudioPlayer: MockAudioPlayer!
    fileprivate var mockUseCase: MockAnalyzeRecordingUseCase!
    var testRecording: Recording!

    @MainActor
    override func setUp() {
        super.setUp()
        mockAudioPlayer = MockAudioPlayer()
        mockUseCase = MockAnalyzeRecordingUseCase()
        testRecording = createTestRecording()
        sut = AnalysisViewModel(
            recording: testRecording,
            audioPlayer: mockAudioPlayer,
            analyzeRecordingUseCase: mockUseCase
        )
    }

    override func tearDown() {
        sut = nil
        mockAudioPlayer = nil
        mockUseCase = nil
        testRecording = nil
        super.tearDown()
    }

    // MARK: - Test Helpers

    private func createTestRecording() -> Recording {
        let scaleSettings = ScaleSettings(
            startNote: try! MIDINote(60),
            endNote: try! MIDINote(72),
            notePattern: .fiveToneScale,
            tempo: try! Tempo(secondsPerNote: 0.5)
        )
        return Recording(
            id: RecordingId(),
            fileURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            createdAt: Date(),
            duration: Duration(seconds: 10.0),
            scaleSettings: scaleSettings
        )
    }

    private func createTestAnalysisResult() -> AnalysisResult {
        let pitchData = PitchAnalysisData(
            timeStamps: [0.0, 0.05],
            frequencies: [261.6, 262.3],
            confidences: [0.85, 0.92],
            targetNotes: [nil, nil]
        )

        let spectrogramData = SpectrogramData(
            timeStamps: [0.0, 0.1],
            frequencyBins: [80, 180],
            magnitudes: [[0.1, 0.3], [0.2, 0.4]]
        )

        return AnalysisResult(
            pitchData: pitchData,
            spectrogramData: spectrogramData,
            scaleSettings: nil
        )
    }

    // MARK: - Initial State Tests

    @MainActor
    func testInitialState_IsLoading() {
        // Then: Initial state should be loading
        XCTAssertEqual(sut.state, .loading)
        XCTAssertFalse(sut.isPlaying)
        XCTAssertEqual(sut.currentTime, 0.0)
    }

    // MARK: - Analysis Tests

    @MainActor
    func testStartAnalysis_Success_UpdatesStateToReady() async {
        // Given: Successful analysis
        let expectedResult = createTestAnalysisResult()
        mockUseCase.resultToReturn = expectedResult

        // When: Starting analysis
        await sut.startAnalysis()

        // Then: State should be ready
        if case .ready(let result) = sut.state {
            XCTAssertEqual(result, expectedResult)
        } else {
            XCTFail("Expected ready state, got \(sut.state)")
        }
    }

    @MainActor
    func testStartAnalysis_Failure_UpdatesStateToError() async {
        // Given: Analysis will fail
        mockUseCase.shouldThrowError = true

        // When: Starting analysis
        await sut.startAnalysis()

        // Then: State should be error
        if case .error(let message) = sut.state {
            XCTAssertFalse(message.isEmpty)
        } else {
            XCTFail("Expected error state, got \(sut.state)")
        }
    }

    @MainActor
    func testStartAnalysis_CallsUseCase() async {
        // Given: Successful analysis
        mockUseCase.resultToReturn = createTestAnalysisResult()

        // When: Starting analysis
        await sut.startAnalysis()

        // Then: Use case should be called
        XCTAssertEqual(mockUseCase.executeCallCount, 1)
        XCTAssertEqual(mockUseCase.lastRecording?.id, testRecording.id)
    }

    // MARK: - Playback Control Tests

    @MainActor
    func testTogglePlayback_WhenNotPlaying_StartsPlayback() {
        // Given: Not playing and ready state
        sut = AnalysisViewModel(
            recording: testRecording,
            audioPlayer: mockAudioPlayer,
            analyzeRecordingUseCase: mockUseCase
        )
        // Manually set ready state for testing
        Task { @MainActor in
            mockUseCase.resultToReturn = createTestAnalysisResult()
            await sut.startAnalysis()

            // When: Toggling playback
            sut.togglePlayback()

            // Then: Should start playing
            XCTAssertTrue(sut.isPlaying)
        }
    }

    @MainActor
    func testSeek_UpdatesCurrentTime() {
        // When: Seeking to specific time
        sut.seek(to: 5.0)

        // Then: Current time should be updated
        XCTAssertEqual(sut.currentTime, 5.0)
    }

    @MainActor
    func testSeek_ClampsToDuration() {
        // When: Seeking beyond duration
        sut.seek(to: 100.0)

        // Then: Should clamp to duration
        XCTAssertEqual(sut.currentTime, testRecording.duration.seconds)
    }

    @MainActor
    func testSeek_ClampsToZero() {
        // When: Seeking to negative time
        sut.seek(to: -5.0)

        // Then: Should clamp to zero
        XCTAssertEqual(sut.currentTime, 0.0)
    }

    @MainActor
    func testSkipBackward_SeeksBackwardFiveSeconds() {
        // Given: Current time is 7 seconds
        sut.seek(to: 7.0)

        // When: Skipping backward
        sut.skipBackward()

        // Then: Should be at 2 seconds
        XCTAssertEqual(sut.currentTime, 2.0)
    }

    @MainActor
    func testSkipForward_SeeksForwardFiveSeconds() {
        // Given: Current time is 3 seconds
        sut.seek(to: 3.0)

        // When: Skipping forward
        sut.skipForward()

        // Then: Should be at 8 seconds
        XCTAssertEqual(sut.currentTime, 8.0)
    }

    // MARK: - Computed Properties Tests

    @MainActor
    func testDuration_ReturnsRecordingDuration() {
        // Then: Duration should match recording
        XCTAssertEqual(sut.duration, testRecording.duration.seconds)
    }

    @MainActor
    func testAnalysisResult_WhenReady_ReturnsResult() async {
        // Given: Ready state
        let expectedResult = createTestAnalysisResult()
        mockUseCase.resultToReturn = expectedResult
        await sut.startAnalysis()

        // Then: Should return result
        XCTAssertEqual(sut.analysisResult, expectedResult)
    }

    @MainActor
    func testAnalysisResult_WhenLoading_ReturnsNil() {
        // Then: Should return nil
        XCTAssertNil(sut.analysisResult)
    }

    @MainActor
    func testAnalysisResult_WhenError_ReturnsNil() async {
        // Given: Error state
        mockUseCase.shouldThrowError = true
        await sut.startAnalysis()

        // Then: Should return nil
        XCTAssertNil(sut.analysisResult)
    }
}

// MARK: - Mock Objects

@MainActor
fileprivate class MockAnalyzeRecordingUseCase: AnalyzeRecordingUseCase {
    var executeCallCount = 0
    var lastRecording: Recording?
    var shouldThrowError = false
    var resultToReturn: AnalysisResult?

    init() {
        // Initialize with dummy dependencies (won't be used)
        let dummyAnalyzer = DummyAnalyzer()
        let dummyCache = DummyCache()
        super.init(audioFileAnalyzer: dummyAnalyzer, analysisCache: dummyCache)
    }

    override func execute(recording: Recording) async throws -> AnalysisResult {
        executeCallCount += 1
        lastRecording = recording

        if shouldThrowError {
            throw NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        }

        guard let result = resultToReturn else {
            throw NSError(domain: "TestError", code: -2, userInfo: [NSLocalizedDescriptionKey: "No result configured"])
        }

        return result
    }
}

@MainActor
fileprivate class DummyAnalyzer: AudioFileAnalyzerProtocol {
    func analyze(fileURL: URL) async throws -> (pitchData: PitchAnalysisData, spectrogramData: SpectrogramData) {
        fatalError("Should not be called")
    }
}

fileprivate class DummyCache: AnalysisCacheProtocol {
    func get(_ id: RecordingId) -> AnalysisResult? {
        fatalError("Should not be called")
    }

    func set(_ id: RecordingId, result: AnalysisResult) {
        fatalError("Should not be called")
    }

    func clear() {
        fatalError("Should not be called")
    }
}
