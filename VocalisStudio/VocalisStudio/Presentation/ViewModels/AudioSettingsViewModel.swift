import Foundation
import Combine
import VocalisDomain

/// ViewModel for audio settings management
@MainActor
final class AudioSettingsViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var outputVolume: Float
    @Published var detectionSensitivity: AudioDetectionSettings.DetectionSensitivity
    @Published var confidenceThreshold: Float

    // MARK: - Private Properties

    private let repository: AudioSettingsRepositoryProtocol
    private var originalSettings: AudioDetectionSettings

    // MARK: - Computed Properties

    /// Whether the current settings differ from saved settings
    var hasChanges: Bool {
        let currentSettings = buildCurrentSettings()
        return currentSettings != originalSettings
    }

    // MARK: - Initialization

    init(repository: AudioSettingsRepositoryProtocol) {
        self.repository = repository

        // Load current settings from repository
        let settings = repository.get()
        self.originalSettings = settings

        // Initialize published properties
        self.outputVolume = settings.outputVolume
        self.detectionSensitivity = settings.sensitivity
        self.confidenceThreshold = settings.confidenceThreshold
    }

    // MARK: - Public Methods

    /// Save current settings to repository
    func saveSettings() throws {
        let settings = buildCurrentSettings()
        try repository.save(settings)

        // Update original settings after successful save
        originalSettings = settings
    }

    /// Reset settings to defaults
    func resetSettings() throws {
        try repository.reset()

        // Reload settings from repository
        let settings = repository.get()
        originalSettings = settings

        // Update UI
        outputVolume = settings.outputVolume
        detectionSensitivity = settings.sensitivity
        confidenceThreshold = settings.confidenceThreshold
    }

    // MARK: - Private Methods

    private func buildCurrentSettings() -> AudioDetectionSettings {
        AudioDetectionSettings(
            outputVolume: outputVolume,
            rmsSilenceThreshold: detectionSensitivity.rmsThreshold,
            confidenceThreshold: confidenceThreshold
        )
    }
}
