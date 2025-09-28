import Foundation

/// Manager for handling localization throughout the app
final class LocalizationManager {
    static let shared = LocalizationManager()
    
    private let repository: LanguageSettingsRepositoryProtocol
    
    init(repository: LanguageSettingsRepositoryProtocol = UserDefaultsLanguageSettingsRepository()) {
        self.repository = repository
    }
    
    /// Gets localized string for the current language
    func localizedString(for key: String) -> String {
        let currentLanguage = repository.getCurrentLanguage()
        return localizedString(for: key, language: currentLanguage)
    }
    
    /// Gets localized string for a specific language
    func localizedString(for key: String, language: Language) -> String {
        guard let path = Bundle.main.path(forResource: language.code, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            // Fallback to English if language bundle not found
            return localizedString(for: key, language: .english)
        }
        
        let localizedString = NSLocalizedString(key, bundle: bundle, comment: "")
        
        // If localization key not found, return the key itself as fallback
        return localizedString != key ? localizedString : key
    }
}

// MARK: - String Extension for Easy Access
extension String {
    /// Returns the localized version of this string
    var localized: String {
        return LocalizationManager.shared.localizedString(for: self)
    }
    
    /// Returns the localized version of this string with format arguments
    func localized(with arguments: CVarArg...) -> String {
        let localizedString = LocalizationManager.shared.localizedString(for: self)
        return String(format: localizedString, arguments: arguments)
    }
}