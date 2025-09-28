import XCTest
@testable import VocalisStudio

final class LanguageUseCaseTests: XCTestCase {
    var mockRepository: MockLanguageSettingsRepository!
    var getLanguageSettingsUseCase: GetLanguageSettingsUseCase!
    var changeLanguageUseCase: ChangeLanguageUseCase!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockLanguageSettingsRepository()
        getLanguageSettingsUseCase = GetLanguageSettingsUseCase(repository: mockRepository)
        changeLanguageUseCase = ChangeLanguageUseCase(repository: mockRepository)
    }
    
    override func tearDown() {
        mockRepository = nil
        getLanguageSettingsUseCase = nil
        changeLanguageUseCase = nil
        super.tearDown()
    }
    
    func testGetLanguageSettings() {
        // When
        let settings = getLanguageSettingsUseCase.execute()
        
        // Then
        XCTAssertEqual(settings.currentLanguage, Language.defaultLanguage)
        XCTAssertEqual(settings.availableLanguages, Language.availableLanguages)
    }
    
    func testChangeLanguageToJapanese() {
        // When
        let updatedSettings = changeLanguageUseCase.execute(to: .japanese)
        
        // Then
        XCTAssertEqual(updatedSettings.currentLanguage, .japanese)
        XCTAssertEqual(mockRepository.getCurrentLanguage(), .japanese)
    }
    
    func testChangeLanguageToSameLanguage() {
        // Given - Default is English
        let initialSettings = getLanguageSettingsUseCase.execute()
        
        // When - Change to English again
        let updatedSettings = changeLanguageUseCase.execute(to: .english)
        
        // Then - Should remain the same
        XCTAssertEqual(updatedSettings.currentLanguage, .english)
        XCTAssertEqual(initialSettings.currentLanguage, updatedSettings.currentLanguage)
    }
    
    func testChangeLanguageToInvalidLanguage() {
        // Given
        let invalidLanguage = Language(code: "invalid", displayName: "Invalid")
        let initialSettings = getLanguageSettingsUseCase.execute()
        
        // When
        let updatedSettings = changeLanguageUseCase.execute(to: invalidLanguage)
        
        // Then - Should remain unchanged
        XCTAssertEqual(updatedSettings.currentLanguage, initialSettings.currentLanguage)
        XCTAssertEqual(mockRepository.getCurrentLanguage(), Language.defaultLanguage)
    }
}