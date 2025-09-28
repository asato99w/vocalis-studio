import Foundation
import Combine

/// ViewModel for managing settings screen
public final class SettingsViewModel: ObservableObject {
    @Published public var languageSettings: LanguageSettings
    @Published public var selectedLanguage: Language
    @Published public var showLanguageChangeAlert = false
    
    private let getLanguageSettingsUseCase: GetLanguageSettingsUseCase
    private let changeLanguageUseCase: ChangeLanguageUseCase
    private var cancellables = Set<AnyCancellable>()
    
    public init(
        getLanguageSettingsUseCase: GetLanguageSettingsUseCase,
        changeLanguageUseCase: ChangeLanguageUseCase
    ) {
        self.getLanguageSettingsUseCase = getLanguageSettingsUseCase
        self.changeLanguageUseCase = changeLanguageUseCase
        
        // Initialize with current settings
        let currentSettings = getLanguageSettingsUseCase.execute()
        self.languageSettings = currentSettings
        self.selectedLanguage = currentSettings.currentLanguage
        
        // Watch for language selection changes
        setupLanguageSelectionWatcher()
    }
    
    private func setupLanguageSelectionWatcher() {
        $selectedLanguage
            .dropFirst() // Skip initial value
            .removeDuplicates()
            .sink { [weak self] newLanguage in
                self?.changeLanguage(to: newLanguage)
            }
            .store(in: &cancellables)
    }
    
    private func changeLanguage(to language: Language) {
        let updatedSettings = changeLanguageUseCase.execute(to: language)
        
        // Update the settings if language actually changed
        if updatedSettings.currentLanguage != languageSettings.currentLanguage {
            languageSettings = updatedSettings
            showLanguageChangeAlert = true
        }
    }
    
    public func dismissLanguageChangeAlert() {
        showLanguageChangeAlert = false
    }
}