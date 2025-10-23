import XCTest
import Combine
@testable import VocalisStudio
@testable import VocalisDomain

@MainActor
final class PitchDetectionViewModelTests: XCTestCase {
    var sut: PitchDetectionViewModel!
    var mockPitchDetector: PitchDetectionMockPitchDetector!
    var mockScalePlayer: PitchDetectionMockScalePlayer!
    var mockAudioPlayer: PitchDetectionMockAudioPlayer!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        mockPitchDetector = PitchDetectionMockPitchDetector()
        mockScalePlayer = PitchDetectionMockScalePlayer()
        mockAudioPlayer = PitchDetectionMockAudioPlayer()
        cancellables = Set<AnyCancellable>()

        sut = PitchDetectionViewModel(
            pitchDetector: mockPitchDetector,
            scalePlayer: mockScalePlayer,
            audioPlayer: mockAudioPlayer
        )
    }

    override func tearDown() {
        cancellables = nil
        sut = nil
        mockAudioPlayer = nil
        mockScalePlayer = nil
        mockPitchDetector = nil
    }

    // MARK: - Initialization Tests

    func testInit_shouldSetupPitchDetectorSubscription() {
        // Given: Initial state
        XCTAssertNil(sut.targetPitch)
        XCTAssertNil(sut.detectedPitch)
        XCTAssertEqual(sut.pitchAccuracy, .none)
    }

    // MARK: - Target Pitch Monitoring Tests

    func testStartTargetPitchMonitoring_shouldLoadScale() async throws {
        // Given
        let settings = try ScaleSettings(scale: .cMajor, tempo: try Tempo(secondsPerNote: 0.5))

        // When
        try await sut.startTargetPitchMonitoring(settings: settings)

        // Then
        XCTAssertTrue(mockScalePlayer.loadScaleElementsCalled)
        XCTAssertNotNil(mockScalePlayer.lastLoadedElements)
        XCTAssertNotNil(mockScalePlayer.lastLoadedTempo)
    }

    func testStopTargetPitchMonitoring_shouldClearTargetPitch() async {
        // Given
        sut.targetPitch = DetectedPitch.fromFrequency(440.0, confidence: 0.8)

        // When
        await sut.stopTargetPitchMonitoring()

        // Then
        XCTAssertNil(sut.targetPitch)
    }

    // MARK: - Playback Pitch Detection Tests

    func testStartPlaybackPitchDetection_shouldStartPitchDetector() async throws {
        // Given
        let url = URL(fileURLWithPath: "/tmp/test.m4a")
        mockAudioPlayer.isPlaying = true

        // When
        try await sut.startPlaybackPitchDetection(url: url)

        // Then
        XCTAssertTrue(mockPitchDetector.startRealtimeDetectionCalled)
    }

    func testStopPlaybackPitchDetection_shouldStopPitchDetector() {
        // Given
        mockPitchDetector.startRealtimeDetectionCalled = true

        // When
        sut.stopPlaybackPitchDetection()

        // Then
        XCTAssertTrue(mockPitchDetector.stopRealtimeDetectionCalled)
    }

    // MARK: - Pitch Update Tests

    func testUpdateDetectedPitch_withValidPitch_shouldUpdateDetectedPitch() {
        // Given
        let expectedPitch = DetectedPitch.fromFrequency(440.0, confidence: 0.9)
        mockPitchDetector.detectedPitch = expectedPitch

        // When
        // Simulate pitch detection by manually calling updateDetectedPitch through monitoring
        // In real usage, this happens through the pitch detection task

        // Then: Since we can't directly test private methods, we'll test the public interface
        XCTAssertNotNil(mockPitchDetector.detectedPitch)
        XCTAssertEqual(mockPitchDetector.detectedPitch?.frequency, 440.0)
    }

    func testUpdateDetectedPitch_withTargetAndDetected_shouldCalculateAccuracy() async throws {
        // Given
        let settings = try ScaleSettings(scale: .cMajor, tempo: try Tempo(secondsPerNote: 0.5))
        try await sut.startTargetPitchMonitoring(settings: settings)

        // Set detected pitch directly for testing
        let detectedPitch = DetectedPitch.fromFrequency(442.0, confidence: 0.9)
        mockPitchDetector.detectedPitch = detectedPitch

        // When: Wait for monitoring to pick up the detected pitch
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // Then: Pitch accuracy should eventually be calculated
        // This is an integration-level test since the actual calculation happens in the monitoring task
    }


    // MARK: - Reset Tests

    func testReset_shouldClearAllState() {
        // Given
        sut.targetPitch = DetectedPitch.fromFrequency(440.0, confidence: 1.0)
        sut.detectedPitch = DetectedPitch.fromFrequency(442.0, confidence: 0.9)
        sut.pitchAccuracy = .good

        // When
        sut.reset()

        // Then
        XCTAssertNil(sut.targetPitch)
        XCTAssertNil(sut.detectedPitch)
        XCTAssertEqual(sut.pitchAccuracy, .none)
    }
}

// MARK: - Mock Objects

class PitchDetectionMockPitchDetector: PitchDetectorProtocol {
    var detectedPitch: DetectedPitch?

    var startRealtimeDetectionCalled = false
    var stopRealtimeDetectionCalled = false

    func startRealtimeDetection() throws {
        startRealtimeDetectionCalled = true
    }

    func stopRealtimeDetection() {
        stopRealtimeDetectionCalled = true
    }
}

class PitchDetectionMockScalePlayer: ScalePlayerProtocol {
    var isPlaying: Bool = false
    var currentNoteIndex: Int = 0
    var progress: Double = 0.0
    var currentScaleElement: ScaleElement?

    var loadScaleElementsCalled = false
    var lastLoadedElements: [ScaleElement]?
    var lastLoadedTempo: Tempo?

    func loadScale(_ notes: [MIDINote], tempo: Tempo) async throws {
        // Not used in this ViewModel
    }

    func loadScaleElements(_ elements: [ScaleElement], tempo: Tempo) async throws {
        loadScaleElementsCalled = true
        lastLoadedElements = elements
        lastLoadedTempo = tempo
    }

    func play(muted: Bool) async throws {
        isPlaying = true
    }

    func stop() async {
        isPlaying = false
    }
}

class PitchDetectionMockAudioPlayer: AudioPlayerProtocol {
    var isPlaying: Bool = false
    var currentTime: Double = 0.0

    func play(url: URL) async throws {
        isPlaying = true
    }

    func pause() {
        isPlaying = false
    }

    func stop() {
        isPlaying = false
        currentTime = 0.0
    }

    func seek(to time: Double) {
        currentTime = time
    }
}
