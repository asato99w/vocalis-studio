import Foundation

/// Mock implementation of LanguageSettingsRepositoryProtocol for testing and previews
final class MockLanguageSettingsRepository: LanguageSettingsRepositoryProtocol {
    private var currentLanguage: Language = .defaultLanguage
    
    func getLanguageSettings() -> LanguageSettings {
        return LanguageSettings(
            id: .shared,
            currentLanguage: currentLanguage,
            availableLanguages: Language.availableLanguages
        )
    }
    
    func saveLanguageSettings(_ settings: LanguageSettings) {
        currentLanguage = settings.currentLanguage
    }
    
    func getCurrentLanguage() -> Language {
        return currentLanguage
    }
    
    func setCurrentLanguage(_ language: Language) {
        currentLanguage = language
    }
    
    func getAvailableLanguages() -> [Language] {
        return Language.availableLanguages
    }
}