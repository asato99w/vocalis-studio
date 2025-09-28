import Foundation

/// Use case for changing the application language
public final class ChangeLanguageUseCase {
    private let repository: LanguageSettingsRepositoryProtocol
    
    public init(repository: LanguageSettingsRepositoryProtocol) {
        self.repository = repository
    }
    
    /// Changes the current language and returns the updated settings
    /// - Parameter language: The new language to set
    /// - Returns: Updated language settings
    public func execute(to language: Language) -> LanguageSettings {
        let currentSettings = repository.getLanguageSettings()
        let updatedSettings = currentSettings.changeLanguage(to: language)
        
        // Only save if the language actually changed
        if updatedSettings.currentLanguage != currentSettings.currentLanguage {
            repository.saveLanguageSettings(updatedSettings)
        }
        
        return updatedSettings
    }
}