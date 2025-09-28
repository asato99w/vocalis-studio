import Foundation

/// UserDefaults-based implementation of LanguageSettingsRepositoryProtocol
final class UserDefaultsLanguageSettingsRepository: LanguageSettingsRepositoryProtocol {
    private let userDefaults: UserDefaults
    private let languageKey = "app_language_code"
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    func getLanguageSettings() -> LanguageSettings {
        let currentLanguage = getCurrentLanguage()
        let availableLanguages = getAvailableLanguages()
        
        return LanguageSettings(
            id: .shared,
            currentLanguage: currentLanguage,
            availableLanguages: availableLanguages
        )
    }
    
    func saveLanguageSettings(_ settings: LanguageSettings) {
        setCurrentLanguage(settings.currentLanguage)
    }
    
    func getCurrentLanguage() -> Language {
        let savedLanguageCode = userDefaults.string(forKey: languageKey)
        
        // Return saved language if valid, otherwise return default
        if let code = savedLanguageCode,
           let language = Language.availableLanguages.first(where: { $0.code == code }) {
            return language
        }
        
        return Language.defaultLanguage
    }
    
    func setCurrentLanguage(_ language: Language) {
        userDefaults.set(language.code, forKey: languageKey)
    }
    
    func getAvailableLanguages() -> [Language] {
        return Language.availableLanguages
    }
}