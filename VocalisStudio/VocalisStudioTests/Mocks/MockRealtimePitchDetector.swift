import Foundation
import VocalisDomain
@testable import VocalisStudio

@MainActor
final class MockRealtimePitchDetector: PitchDetectorProtocol {
    var startRealtimeDetectionCalled = false
    var stopRealtimeDetectionCalled = false
    var mockDetectedPitch: DetectedPitch?
    var mockDetectedPitchSequence: [DetectedPitch] = []
    private var sequenceIndex = 0

    var detectedPitch: DetectedPitch? {
        if !mockDetectedPitchSequence.isEmpty && sequenceIndex < mockDetectedPitchSequence.count {
            let pitch = mockDetectedPitchSequence[sequenceIndex]
            sequenceIndex += 1
            return pitch
        }
        return mockDetectedPitch
    }

    func startRealtimeDetection() throws {
        startRealtimeDetectionCalled = true
    }

    func stopRealtimeDetection() {
        stopRealtimeDetectionCalled = true
        sequenceIndex = 0
    }

    func reset() {
        startRealtimeDetectionCalled = false
        stopRealtimeDetectionCalled = false
        mockDetectedPitch = nil
        mockDetectedPitchSequence = []
        sequenceIndex = 0
    }
}
