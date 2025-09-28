import XCTest
@testable import VocalisStudio

final class LanguageSettingsTests: XCTestCase {
    
    func testLanguageValueObject() {
        // Given
        let english = Language.english
        let japanese = Language.japanese
        
        // Then
        XCTAssertEqual(english.code, "en")
        XCTAssertEqual(english.displayName, "English")
        XCTAssertEqual(japanese.code, "ja")
        XCTAssertEqual(japanese.displayName, "日本語")
        XCTAssertEqual(Language.defaultLanguage, english)
    }
    
    func testLanguageSettingsCreation() {
        // Given
        let settings = LanguageSettings.createDefault()
        
        // Then
        XCTAssertEqual(settings.currentLanguage, Language.defaultLanguage)
        XCTAssertEqual(settings.availableLanguages, Language.availableLanguages)
        XCTAssertEqual(settings.id, LanguageSettingsId.shared)
    }
    
    func testLanguageSettingsChangeLanguage() {
        // Given
        let settings = LanguageSettings.createDefault()
        
        // When
        let updatedSettings = settings.changeLanguage(to: .japanese)
        
        // Then
        XCTAssertEqual(updatedSettings.currentLanguage, .japanese)
        XCTAssertEqual(updatedSettings.id, settings.id)
        XCTAssertEqual(updatedSettings.availableLanguages, settings.availableLanguages)
    }
    
    func testLanguageSettingsChangeToInvalidLanguage() {
        // Given
        let settings = LanguageSettings.createDefault()
        let invalidLanguage = Language(code: "invalid", displayName: "Invalid")
        
        // When
        let updatedSettings = settings.changeLanguage(to: invalidLanguage)
        
        // Then - Should remain unchanged
        XCTAssertEqual(updatedSettings.currentLanguage, settings.currentLanguage)
        XCTAssertEqual(updatedSettings, settings)
    }
}