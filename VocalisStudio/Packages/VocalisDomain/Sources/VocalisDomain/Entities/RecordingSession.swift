import Foundation

/// Represents an active recording session
/// Tracks the state of an ongoing recording with or without scale playback
public struct RecordingSession: Equatable {
    public let recordingURL: URL
    public let settings: ScaleSettings?  // Optional: nil when recording without scale
    public let startedAt: Date

    public init(
        recordingURL: URL,
        settings: ScaleSettings? = nil,
        startedAt: Date = Date()
    ) {
        self.recordingURL = recordingURL
        self.settings = settings
        self.startedAt = startedAt
    }

    /// Calculate elapsed time since recording started
    public func elapsedTime(at currentTime: Date = Date()) -> TimeInterval {
        return currentTime.timeIntervalSince(startedAt)
    }
}
