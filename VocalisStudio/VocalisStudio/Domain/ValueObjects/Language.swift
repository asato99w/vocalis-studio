import Foundation

/// Represents a language with its code and display name
public struct Language: Equatable, Hashable {
    public let code: String
    public let displayName: String
    
    public init(code: String, displayName: String) {
        self.code = code
        self.displayName = displayName
    }
    
    // MARK: - Predefined Languages
    public static let english = Language(code: "en", displayName: "English")
    public static let japanese = Language(code: "ja", displayName: "日本語")
    
    public static let availableLanguages: [Language] = [.english, .japanese]
    public static let defaultLanguage: Language = .english
}

// MARK: - Identifiable
extension Language: Identifiable {
    public var id: String { code }
}