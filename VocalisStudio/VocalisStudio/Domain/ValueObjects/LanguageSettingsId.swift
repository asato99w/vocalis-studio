import Foundation

/// Unique identifier for language settings
public struct LanguageSettingsId: Equatable, Hashable {
    public let value: UUID
    
    public init() {
        self.value = UUID()
    }
    
    public init(value: UUID) {
        self.value = value
    }
    
    // Single instance ID for language settings
    public static let shared = LanguageSettingsId(value: UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")!)
}