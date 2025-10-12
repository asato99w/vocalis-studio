import Foundation

/// Result of stopping a recording
public struct StopRecordingResult: Equatable {
    public let duration: TimeInterval

    public init(duration: TimeInterval) {
        self.duration = duration
    }
}
