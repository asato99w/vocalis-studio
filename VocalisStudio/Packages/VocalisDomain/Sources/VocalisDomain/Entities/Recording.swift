import Foundation

/// Recording entity
public struct Recording: Equatable, Identifiable, Codable {
    public let id: RecordingId
    public let fileURL: URL
    public let createdAt: Date
    public let duration: Duration
    public let scaleSettings: ScaleSettings?  // Optional: nil when recording without scale

    public init(
        id: RecordingId = RecordingId(),
        fileURL: URL,
        createdAt: Date = Date(),
        duration: Duration,
        scaleSettings: ScaleSettings?  // Optional: nil when recording without scale
    ) {
        self.id = id
        self.fileURL = fileURL
        self.createdAt = createdAt
        self.duration = duration
        self.scaleSettings = scaleSettings
    }

    /// Formatted creation date for display
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    /// Display name for the scale used in this recording
    /// Returns nil when recording was made without scale settings
    /// Example: "C4 五声音階"
    public var scaleDisplayName: String? {
        guard let settings = scaleSettings else { return nil }
        return "\(settings.startNote.noteName) \(settings.notePattern.displayName)"
    }
}

// MARK: - Codable conformance for Duration
extension Duration: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let seconds = try container.decode(TimeInterval.self)
        self.init(seconds: seconds)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(seconds)
    }
}
