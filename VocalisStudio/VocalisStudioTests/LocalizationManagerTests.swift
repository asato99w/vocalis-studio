import XCTest
@testable import VocalisStudio

final class LocalizationManagerTests: XCTestCase {
    var mockRepository: MockLanguageSettingsRepository!
    var localizationManager: LocalizationManager!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockLanguageSettingsRepository()
        localizationManager = LocalizationManager(repository: mockRepository)
    }
    
    override func tearDown() {
        mockRepository = nil
        localizationManager = nil
        super.tearDown()
    }
    
    func testLocalizedStringForCurrentLanguage() {
        // Given - Default language is English
        let key = "recording.title"
        
        // When
        let localizedString = localizationManager.localizedString(for: key)
        
        // Then - Should return the key if not found in bundle (test environment)
        XCTAssertEqual(localizedString, key)
    }
    
    func testLocalizedStringForSpecificLanguage() {
        // Given
        let key = "recording.title"
        
        // When
        let englishString = localizationManager.localizedString(for: key, language: .english)
        let japaneseString = localizationManager.localizedString(for: key, language: .japanese)
        
        // Then
        XCTAssertEqual(englishString, key) // Fallback to key in test environment
        XCTAssertEqual(japaneseString, key) // Fallback to key in test environment
    }
    
    func testStringLocalizationExtension() {
        // Given
        let key = "settings.title"
        
        // When
        let localizedString = key.localized
        
        // Then
        XCTAssertEqual(localizedString, key) // Fallback to key in test environment
    }
    
    func testStringLocalizationWithArguments() {
        // Given
        let key = "recording.duration.label"
        let duration = "02:30"
        
        // When
        let localizedString = key.localized(with: duration)
        
        // Then - Should format even with fallback key
        XCTAssertTrue(localizedString.contains(duration))
    }
}