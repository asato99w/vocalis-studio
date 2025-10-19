import XCTest
import VocalisDomain
@testable import VocalisStudio

final class AnalyzeRecordingUseCaseTests: XCTestCase {
    var sut: AnalyzeRecordingUseCase!
    fileprivate var mockAnalyzer: MockAudioFileAnalyzer!
    fileprivate var mockCache: MockAnalysisCache!
    var testRecording: Recording!

    @MainActor
    override func setUp() {
        super.setUp()
        mockAnalyzer = MockAudioFileAnalyzer()
        mockCache = MockAnalysisCache()
        sut = AnalyzeRecordingUseCase(
            audioFileAnalyzer: mockAnalyzer,
            analysisCache: mockCache
        )
        testRecording = createTestRecording()
    }

    override func tearDown() {
        sut = nil
        mockAnalyzer = nil
        mockCache = nil
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

    // MARK: - Cache Hit Tests

    @MainActor
    func testExecute_WithCachedResult_ReturnsCachedResult() async throws {
        // Given: Cached result exists
        let cachedResult = createTestAnalysisResult()
        mockCache.cachedResults[testRecording.id] = cachedResult

        // When: Executing analysis
        let result = try await sut.execute(recording: testRecording)

        // Then: Should return cached result without analyzing
        XCTAssertEqual(result, cachedResult)
        XCTAssertEqual(mockCache.getCallCount, 1)
        XCTAssertEqual(mockAnalyzer.analyzeCallCount, 0)
    }

    // MARK: - Cache Miss Tests

    @MainActor
    func testExecute_WithoutCachedResult_PerformsAnalysis() async throws {
        // Given: No cached result
        let expectedResult = createTestAnalysisResult()
        mockAnalyzer.resultToReturn = (
            pitchData: expectedResult.pitchData,
            spectrogramData: expectedResult.spectrogramData
        )

        // When: Executing analysis
        let result = try await sut.execute(recording: testRecording)

        // Then: Should analyze and cache result
        XCTAssertEqual(mockAnalyzer.analyzeCallCount, 1)
        XCTAssertEqual(mockAnalyzer.lastAnalyzedURL, testRecording.fileURL)
        XCTAssertEqual(mockCache.setCallCount, 1)
        XCTAssertEqual(result.pitchData, expectedResult.pitchData)
        XCTAssertEqual(result.spectrogramData, expectedResult.spectrogramData)
    }

    @MainActor
    func testExecute_CachesAnalysisResult() async throws {
        // Given: No cached result
        let expectedResult = createTestAnalysisResult()
        mockAnalyzer.resultToReturn = (
            pitchData: expectedResult.pitchData,
            spectrogramData: expectedResult.spectrogramData
        )

        // When: Executing analysis
        _ = try await sut.execute(recording: testRecording)

        // Then: Result should be cached
        XCTAssertEqual(mockCache.setCallCount, 1)
        XCTAssertNotNil(mockCache.cachedResults[testRecording.id])
    }

    // MARK: - Error Handling Tests

    @MainActor
    func testExecute_AnalyzerThrowsError_PropagatesError() async {
        // Given: Analyzer will throw error
        mockAnalyzer.shouldThrowError = true

        // When: Executing analysis
        do {
            _ = try await sut.execute(recording: testRecording)
            XCTFail("Should have thrown error")
        } catch {
            // Then: Error should be propagated
            XCTAssertTrue(error is MockError)
        }
    }

    @MainActor
    func testExecute_AnalyzerThrowsError_DoesNotCache() async {
        // Given: Analyzer will throw error
        mockAnalyzer.shouldThrowError = true

        // When: Executing analysis (catching error)
        do {
            _ = try await sut.execute(recording: testRecording)
        } catch {
            // Expected error
        }

        // Then: Should not cache result
        XCTAssertEqual(mockCache.setCallCount, 0)
    }

    // MARK: - Scale Settings Tests

    @MainActor
    func testExecute_PreservesScaleSettings() async throws {
        // Given: Recording with scale settings
        let scaleSettings = ScaleSettings(
            startNote: try! MIDINote(60),
            endNote: try! MIDINote(72),
            notePattern: .fiveToneScale,
            tempo: try! Tempo(secondsPerNote: 0.5)
        )
        let recordingWithScale = Recording(
            id: RecordingId(),
            fileURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            createdAt: Date(),
            duration: Duration(seconds: 10.0),
            scaleSettings: scaleSettings
        )

        let expectedResult = createTestAnalysisResult()
        mockAnalyzer.resultToReturn = (
            pitchData: expectedResult.pitchData,
            spectrogramData: expectedResult.spectrogramData
        )

        // When: Executing analysis
        let result = try await sut.execute(recording: recordingWithScale)

        // Then: Scale settings should be preserved
        XCTAssertEqual(result.scaleSettings, scaleSettings)
    }
}

// MARK: - Mock Objects

fileprivate enum MockError: Error {
    case testError
}

@MainActor
fileprivate class MockAudioFileAnalyzer: AudioFileAnalyzerProtocol {
    var analyzeCallCount = 0
    var lastAnalyzedURL: URL?
    var shouldThrowError = false
    var resultToReturn: (pitchData: PitchAnalysisData, spectrogramData: SpectrogramData)?

    func analyze(fileURL: URL) async throws -> (pitchData: PitchAnalysisData, spectrogramData: SpectrogramData) {
        analyzeCallCount += 1
        lastAnalyzedURL = fileURL

        if shouldThrowError {
            throw MockError.testError
        }

        guard let result = resultToReturn else {
            throw MockError.testError
        }

        return result
    }
}

fileprivate class MockAnalysisCache: AnalysisCacheProtocol {
    var cachedResults: [RecordingId: AnalysisResult] = [:]
    var getCallCount = 0
    var setCallCount = 0
    var clearCallCount = 0

    func get(_ id: RecordingId) -> AnalysisResult? {
        getCallCount += 1
        return cachedResults[id]
    }

    func set(_ id: RecordingId, result: AnalysisResult) {
        setCallCount += 1
        cachedResults[id] = result
    }

    func clear() {
        clearCallCount += 1
        cachedResults.removeAll()
    }
}
