import Foundation

/// Entity representing the language settings for the application
public struct LanguageSettings: Equatable {
    public let id: LanguageSettingsId
    public let currentLanguage: Language
    public let availableLanguages: [Language]
    
    public init(id: LanguageSettingsId, currentLanguage: Language, availableLanguages: [Language]) {
        self.id = id
        self.currentLanguage = currentLanguage
        self.availableLanguages = availableLanguages
    }
    
    /// Creates default language settings with English as default
    public static func createDefault() -> LanguageSettings {
        return LanguageSettings(
            id: .shared,
            currentLanguage: .defaultLanguage,
            availableLanguages: Language.availableLanguages
        )
    }
    
    /// Changes the current language
    public func changeLanguage(to newLanguage: Language) -> LanguageSettings {
        guard availableLanguages.contains(newLanguage) else {
            return self
        }
        
        return LanguageSettings(
            id: self.id,
            currentLanguage: newLanguage,
            availableLanguages: self.availableLanguages
        )
    }
}