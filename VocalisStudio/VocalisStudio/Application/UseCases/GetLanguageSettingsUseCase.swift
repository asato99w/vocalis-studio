import Foundation

/// Use case for retrieving current language settings
public final class GetLanguageSettingsUseCase {
    private let repository: LanguageSettingsRepositoryProtocol
    
    public init(repository: LanguageSettingsRepositoryProtocol) {
        self.repository = repository
    }
    
    public func execute() -> LanguageSettings {
        return repository.getLanguageSettings()
    }
}