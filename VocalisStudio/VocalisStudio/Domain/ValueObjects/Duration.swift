import Foundation

public struct Duration: Equatable {
    public let seconds: TimeInterval
    
    public init(seconds: TimeInterval) {
        self.seconds = seconds
    }
    
    public init(from startTime: Date, to endTime: Date) {
        self.seconds = endTime.timeIntervalSince(startTime)
    }
    
    public var formatted: String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}