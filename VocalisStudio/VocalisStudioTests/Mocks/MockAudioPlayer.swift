import Foundation
import VocalisDomain
@testable import VocalisStudio

final class MockAudioPlayer: AudioPlayerProtocol {
    var playCalled = false
    var stopCalled = false
    var pauseCalled = false
    var resumeCalled = false
    var seekCalled = false
    var seekToTime: TimeInterval = 0.0
    var playURL: URL?
    var playShouldFail = false
    var _isPlaying = false
    var _currentTime: TimeInterval = 0.0
    var _duration: TimeInterval = 10.0

    var isPlaying: Bool {
        _isPlaying
    }

    var currentTime: TimeInterval {
        return _currentTime
    }

    var duration: TimeInterval {
        return _duration
    }

    func play(url: URL) async throws {
        playCalled = true
        playURL = url

        if playShouldFail {
            throw AudioPlayerError.playbackFailed("Mock playback error")
        }

        _isPlaying = true

        // Simulate playback completion after a short delay
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        _isPlaying = false
    }

    func stop() async {
        stopCalled = true
        _isPlaying = false
    }

    func pause() {
        pauseCalled = true
        _isPlaying = false
    }

    func resume() {
        resumeCalled = true
        _isPlaying = true
    }

    func seek(to time: TimeInterval) {
        seekCalled = true
        seekToTime = time
        _currentTime = time
    }

    func reset() {
        playCalled = false
        stopCalled = false
        pauseCalled = false
        resumeCalled = false
        seekCalled = false
        seekToTime = 0.0
        playURL = nil
        playShouldFail = false
        _isPlaying = false
        _currentTime = 0.0
    }
}
