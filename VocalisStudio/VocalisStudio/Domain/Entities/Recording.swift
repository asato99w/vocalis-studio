import Foundation

public struct Recording: Equatable {
    public let id: RecordingId
    public let audioFileUrl: URL
    public let startTime: Date
    public private(set) var endTime: Date?
    
    public init(
        id: RecordingId,
        audioFileUrl: URL,
        startTime: Date,
        endTime: Date? = nil
    ) {
        self.id = id
        self.audioFileUrl = audioFileUrl
        self.startTime = startTime
        self.endTime = endTime
    }
    
    public var duration: Duration? {
        guard let endTime = endTime else { return nil }
        return Duration(from: startTime, to: endTime)
    }
    
    public var isInProgress: Bool {
        return endTime == nil
    }
    
    public mutating func complete(at endTime: Date) {
        self.endTime = endTime
    }
}