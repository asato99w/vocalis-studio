import Foundation

/// Recording entity
public struct Recording: Equatable, Identifiable, Codable {
    public let id: RecordingId
    public let fileURL: URL
    public let createdAt: Date
    public let duration: Duration
    public let scaleSettings: ScaleSettings

    public init(
        id: RecordingId = RecordingId(),
        fileURL: URL,
        createdAt: Date = Date(),
        duration: Duration,
        scaleSettings: ScaleSettings
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
