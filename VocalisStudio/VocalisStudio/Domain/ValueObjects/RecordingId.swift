import Foundation

public struct RecordingId: Equatable, Hashable {
    public let value: UUID
    
    public init() {
        self.value = UUID()
    }
    
    public init(value: UUID) {
        self.value = value
    }
}