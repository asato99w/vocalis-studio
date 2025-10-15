import Foundation

/// Represents an active recording session
/// Tracks the state of an ongoing recording with scale playback
public struct RecordingSession: Equatable {
    public let recordingURL: URL
    public let settings: ScaleSettings
    public let startedAt: Date

    public init(
        recordingURL: URL,
        settings: ScaleSettings,
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
