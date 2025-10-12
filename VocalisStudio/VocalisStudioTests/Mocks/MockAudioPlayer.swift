import Foundation
@testable import VocalisStudio

final class MockAudioPlayer: AudioPlayerProtocol {
    var playCalled = false
    var stopCalled = false
    var playURL: URL?
    var playShouldFail = false
    var _isPlaying = false

    var isPlaying: Bool {
        _isPlaying
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

    func reset() {
        playCalled = false
        stopCalled = false
        playURL = nil
        playShouldFail = false
        _isPlaying = false
    }
}
