import Foundation
import VocalisDomain
@testable import VocalisStudio

final class MockAudioPlayer: AudioPlayerProtocol {
    var playCalled = false
    var stopCalled = false
    var pauseCalled = false
    var resumeCalled = false
    var seekCalled = false
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
        _currentTime = time
    }

    func reset() {
        playCalled = false
        stopCalled = false
        pauseCalled = false
        resumeCalled = false
        seekCalled = false
        playURL = nil
        playShouldFail = false
        _isPlaying = false
        _currentTime = 0.0
    }
}
