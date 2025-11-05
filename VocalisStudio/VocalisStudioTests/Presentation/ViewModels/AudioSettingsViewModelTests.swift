import XCTest
import Combine
@testable import VocalisDomain
@testable import VocalisStudio

/// Tests for AudioSettingsViewModel
@MainActor
final class AudioSettingsViewModelTests: XCTestCase {

    var sut: AudioSettingsViewModel!
    var mockRepository: MockAudioSettingsRepository!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockRepository = MockAudioSettingsRepository()
        sut = AudioSettingsViewModel(repository: mockRepository)
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        sut = nil
        mockRepository = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInit_shouldLoadCurrentSettings() {
        // Given: Repository returns specific settings
        let expectedSettings = AudioDetectionSettings(
            outputVolume: 0.7,
            rmsSilenceThreshold: 0.015,  // 0.01 < 0.015 < 0.035 → .normal
            confidenceThreshold: 0.35
        )
        let customMockRepository = MockAudioSettingsRepository()
        customMockRepository.settingsToReturn = expectedSettings

        // When: ViewModel is initialized
        let viewModel = AudioSettingsViewModel(repository: customMockRepository)

        // Then: Settings should be loaded
        XCTAssertTrue(customMockRepository.getCalled)
        XCTAssertEqual(viewModel.outputVolume, 0.7)
        XCTAssertEqual(viewModel.detectionSensitivity, .normal)  // 0.015 maps to .normal
        XCTAssertEqual(viewModel.confidenceThreshold, 0.35)
    }

    // MARK: - Output Volume Tests

    func testSetOutputVolume_shouldUpdateValue() {
        // When
        sut.outputVolume = 0.9

        // Then
        XCTAssertEqual(sut.outputVolume, 0.9)
    }

    func testSetOutputVolume_shouldNotSaveImmediately() {
        // When
        sut.outputVolume = 0.9

        // Then: Save should not be called yet
        XCTAssertFalse(mockRepository.saveCalled)
    }

    // MARK: - Detection Sensitivity Tests

    func testSetDetectionSensitivity_shouldUpdateValue() {
        // When
        sut.detectionSensitivity = .low

        // Then
        XCTAssertEqual(sut.detectionSensitivity, .low)
    }

    func testDetectionSensitivity_shouldMapFromRMSThreshold() {
        // Given: Settings with RMS 0.005 (high sensitivity)
        let customMockRepository = MockAudioSettingsRepository()
        customMockRepository.settingsToReturn = AudioDetectionSettings(
            outputVolume: 0.8,
            rmsSilenceThreshold: 0.005,
            confidenceThreshold: 0.4
        )

        // When
        let viewModel = AudioSettingsViewModel(repository: customMockRepository)

        // Then
        XCTAssertEqual(viewModel.detectionSensitivity, .high)
    }

    // MARK: - Confidence Threshold Tests

    func testSetConfidenceThreshold_shouldUpdateValue() {
        // When
        sut.confidenceThreshold = 0.6

        // Then
        XCTAssertEqual(sut.confidenceThreshold, 0.6)
    }

    // MARK: - Save Tests

    func testSaveSettings_shouldCallRepositorySave() throws {
        // Given
        sut.outputVolume = 0.6
        sut.detectionSensitivity = .low
        sut.confidenceThreshold = 0.5

        // When
        try sut.saveSettings()

        // Then
        XCTAssertTrue(mockRepository.saveCalled)
        XCTAssertNotNil(mockRepository.savedSettings)
        XCTAssertEqual(mockRepository.savedSettings?.outputVolume, 0.6)
        XCTAssertEqual(mockRepository.savedSettings?.rmsSilenceThreshold, 0.05) // .low = 0.05
        XCTAssertEqual(mockRepository.savedSettings?.confidenceThreshold, 0.5)
    }

    func testSaveSettings_whenRepositoryThrows_shouldPropagateError() {
        // Given
        mockRepository.shouldThrowOnSave = true

        // When/Then
        XCTAssertThrowsError(try sut.saveSettings()) { error in
            XCTAssertEqual(error as? MockAudioSettingsRepository.TestError, .saveFailed)
        }
    }

    // MARK: - Reset Tests

    func testResetSettings_shouldCallRepositoryReset() throws {
        // When
        try sut.resetSettings()

        // Then
        XCTAssertTrue(mockRepository.resetCalled)
    }

    func testResetSettings_shouldReloadDefaultSettings() throws {
        // Given: Change settings
        sut.outputVolume = 0.5
        sut.confidenceThreshold = 0.2

        // When: Reset
        try sut.resetSettings()

        // Then: Should reload defaults from repository
        XCTAssertTrue(mockRepository.getCalled)
        #if targetEnvironment(simulator)
        XCTAssertEqual(sut.detectionSensitivity, .high) // simulator default
        #else
        XCTAssertEqual(sut.detectionSensitivity, .normal) // device default
        #endif
    }

    func testResetSettings_whenRepositoryThrows_shouldPropagateError() {
        // Given
        mockRepository.shouldThrowOnReset = true

        // When/Then
        XCTAssertThrowsError(try sut.resetSettings()) { error in
            XCTAssertEqual(error as? MockAudioSettingsRepository.TestError, .resetFailed)
        }
    }

    // MARK: - Has Changes Tests

    func testHasChanges_whenNoChanges_shouldReturnFalse() {
        // Given: Initial state
        // When/Then
        XCTAssertFalse(sut.hasChanges)
    }

    func testHasChanges_whenOutputVolumeChanged_shouldReturnTrue() {
        // Given
        let originalVolume = sut.outputVolume

        // When
        sut.outputVolume = originalVolume + 0.1

        // Then
        XCTAssertTrue(sut.hasChanges)
    }

    func testHasChanges_whenSensitivityChanged_shouldReturnTrue() {
        // Given
        let originalSensitivity = sut.detectionSensitivity

        // When
        sut.detectionSensitivity = (originalSensitivity == .low) ? .high : .low

        // Then
        XCTAssertTrue(sut.hasChanges)
    }

    func testHasChanges_whenConfidenceChanged_shouldReturnTrue() {
        // Given
        let originalConfidence = sut.confidenceThreshold

        // When
        sut.confidenceThreshold = originalConfidence + 0.1

        // Then
        XCTAssertTrue(sut.hasChanges)
    }

    func testHasChanges_afterSave_shouldReturnFalse() throws {
        // Given
        sut.outputVolume = 0.9

        // When
        try sut.saveSettings()

        // Then
        XCTAssertFalse(sut.hasChanges)
    }
}

// MARK: - Mock Repository

class MockAudioSettingsRepository: AudioSettingsRepositoryProtocol {

    enum TestError: Error {
        case saveFailed
        case resetFailed
    }

    var settingsToReturn = AudioDetectionSettings.default
    var getCalled = false
    var saveCalled = false
    var resetCalled = false
    var savedSettings: AudioDetectionSettings?
    var shouldThrowOnSave = false
    var shouldThrowOnReset = false

    func get() -> AudioDetectionSettings {
        getCalled = true
        return settingsToReturn
    }

    func save(_ settings: AudioDetectionSettings) throws {
        saveCalled = true
        savedSettings = settings
        if shouldThrowOnSave {
            throw TestError.saveFailed
        }
        // Update return value for next get()
        settingsToReturn = settings
    }

    func reset() throws {
        resetCalled = true
        if shouldThrowOnReset {
            throw TestError.resetFailed
        }
        // Reset to defaults
        #if targetEnvironment(simulator)
        settingsToReturn = AudioDetectionSettings.simulator
        #else
        settingsToReturn = AudioDetectionSettings.default
        #endif
    }
}
