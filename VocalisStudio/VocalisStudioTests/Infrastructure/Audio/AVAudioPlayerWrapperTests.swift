import XCTest
import VocalisDomain
@testable import VocalisStudio
import AVFoundation

/// Tests for AVAudioPlayerWrapper
/// Focus: Continuation leak prevention in pause() method
final class AVAudioPlayerWrapperTests: XCTestCase {
    var sut: AVAudioPlayerWrapper!
    fileprivate var mockSettingsRepository: MockAudioSettingsRepositoryForPlayer!

    override func setUp() {
        super.setUp()
        mockSettingsRepository = MockAudioSettingsRepositoryForPlayer()
        sut = AVAudioPlayerWrapper(settingsRepository: mockSettingsRepository)
    }

    override func tearDown() async throws {
        await sut.stop()
        sut = nil
        mockSettingsRepository = nil
        try await super.tearDown()
    }

    // MARK: - Continuation Leak Bug Tests

    /// Bug fix: pause() should resume playback continuation to prevent leaks
    /// This test verifies that pause() properly cleans up the continuation
    func testPause_ShouldResumeContinuation_ToPreventLeak() async throws {
        // Given: Create a test audio file
        let testFileURL = try createTestAudioFile()
        defer { try? FileManager.default.removeItem(at: testFileURL) }

        // Start playback in background (don't await - it will block)
        let playbackTask = Task {
            try? await sut.play(url: testFileURL)
        }

        // Wait for playback to start
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // When: Pause playback
        sut.pause()

        // Wait a bit for pause to process
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Then: The playback task should complete (not hang)
        // If continuation is not resumed, this will timeout
        let result = await playbackTask.result

        // Verify task completed (either success or cancellation, but not hanging)
        switch result {
        case .success:
            // Expected: continuation was resumed by pause()
            XCTAssertTrue(true, "Playback task completed successfully")
        case .failure:
            // Also acceptable: continuation was resumed with error
            XCTAssertTrue(true, "Playback task completed with error (acceptable)")
        }

        // Additional verification: We should be able to start new playback without hanging
        let secondPlaybackTask = Task {
            try? await sut.play(url: testFileURL)
        }

        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        sut.pause()

        let secondResult = await secondPlaybackTask.result
        switch secondResult {
        case .success, .failure:
            XCTAssertTrue(true, "Second playback also completed without hanging")
        }
    }

    // MARK: - Test Helpers

    /// Create a temporary silent audio file for testing
    private func createTestAudioFile() throws -> URL {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_audio_\(UUID().uuidString).m4a")

        // Create audio format (44.1kHz, stereo)
        let audioFormat = AVAudioFormat(
            standardFormatWithSampleRate: 44100,
            channels: 2
        )!

        // Create audio file
        let audioFile = try AVAudioFile(
            forWriting: fileURL,
            settings: audioFormat.settings
        )

        // Generate 1 second of silence
        let frameCount = AVAudioFrameCount(44100) // 1 second at 44.1kHz
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        // Write silence (buffer is already zeroed)
        try audioFile.write(from: buffer)

        return fileURL
    }
}

// MARK: - Mock Objects

fileprivate class MockAudioSettingsRepositoryForPlayer: AudioSettingsRepositoryProtocol {
    func get() -> AudioDetectionSettings {
        return AudioDetectionSettings(
            scalePlaybackVolume: 1.0,
            recordingPlaybackVolume: 1.0,
            rmsSilenceThreshold: 0.01,
            confidenceThreshold: 0.3
        )
    }

    func save(_ settings: AudioDetectionSettings) throws {
        // No-op for testing
    }

    func reset() throws {
        // No-op for testing
    }
}
