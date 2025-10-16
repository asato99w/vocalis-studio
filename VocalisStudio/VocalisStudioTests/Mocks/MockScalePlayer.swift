import Foundation
import VocalisDomain
@testable import VocalisStudio

final class MockScalePlayer: ScalePlayerProtocol {
    var loadScaleCalled = false
    var playCalled = false
    var stopCalled = false

    var loadedNotes: [MIDINote]?
    var loadedTempo: Tempo?

    var loadScaleShouldFail = false
    var playShouldFail = false

    var loadScaleCallTime: Date?
    var playCallTime: Date?
    var stopCallTime: Date?

    var _isPlaying = false
    var _currentNoteIndex = 0

    var isPlaying: Bool {
        _isPlaying
    }

    var currentNoteIndex: Int {
        _currentNoteIndex
    }

    var progress: Double {
        0.0
    }

    var currentScaleElement: ScaleElement? {
        nil
    }

    func loadScale(_ notes: [MIDINote], tempo: Tempo) async throws {
        loadScaleCalled = true
        loadScaleCallTime = Date()
        loadedNotes = notes
        loadedTempo = tempo

        if loadScaleShouldFail {
            throw ScalePlayerError.notLoaded
        }
    }

    func loadScaleElements(_ elements: [ScaleElement], tempo: Tempo) async throws {
        loadScaleCalled = true
        loadScaleCallTime = Date()
        loadedTempo = tempo

        if loadScaleShouldFail {
            throw ScalePlayerError.notLoaded
        }
    }

    func play(muted: Bool) async throws {
        playCalled = true
        playCallTime = Date()
        _isPlaying = true

        if playShouldFail {
            _isPlaying = false
            throw ScalePlayerError.playbackFailed("Mock play error")
        }
    }

    func stop() async {
        stopCalled = true
        stopCallTime = Date()
        _isPlaying = false
    }

    func reset() {
        loadScaleCalled = false
        playCalled = false
        stopCalled = false
        loadedNotes = nil
        loadedTempo = nil
        loadScaleShouldFail = false
        playShouldFail = false
        loadScaleCallTime = nil
        playCallTime = nil
        stopCallTime = nil
        _isPlaying = false
        _currentNoteIndex = 0
    }
}
