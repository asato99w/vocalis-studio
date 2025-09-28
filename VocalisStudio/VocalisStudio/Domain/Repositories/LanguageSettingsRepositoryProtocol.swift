import Foundation

/// Repository protocol for managing language settings persistence
public protocol LanguageSettingsRepositoryProtocol {
    /// Gets the current language settings
    func getLanguageSettings() -> LanguageSettings
    
    /// Saves the language settings
    func saveLanguageSettings(_ settings: LanguageSettings)
    
    /// Gets the current language
    func getCurrentLanguage() -> Language
    
    /// Sets the current language
    func setCurrentLanguage(_ language: Language)
    
    /// Gets all available languages
    func getAvailableLanguages() -> [Language]
}