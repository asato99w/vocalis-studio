import Foundation
import VocalisDomain

/// ViewModel for managing scale presets
public class ScalePresetViewModel: ObservableObject {
    @Published public private(set) var presets: [ScalePreset] = []
    @Published public var isShowingSaveDialog = false
    @Published public var isShowingPresetList = false
    @Published public var newPresetName = ""
    @Published public var errorMessage: String?

    private let saveUseCase: SaveScalePresetUseCase
    private let loadUseCase: LoadScalePresetsUseCase
    private let deleteUseCase: DeleteScalePresetUseCase

    public init(
        saveUseCase: SaveScalePresetUseCase,
        loadUseCase: LoadScalePresetsUseCase,
        deleteUseCase: DeleteScalePresetUseCase
    ) {
        self.saveUseCase = saveUseCase
        self.loadUseCase = loadUseCase
        self.deleteUseCase = deleteUseCase
        loadPresets()
    }

    /// Load all presets from storage
    public func loadPresets() {
        presets = loadUseCase.execute()
    }

    /// Save current settings as a new preset
    public func savePreset(name: String, from settingsViewModel: RecordingSettingsViewModel) {
        let settings = createPresetSettings(from: settingsViewModel)

        do {
            let preset = try saveUseCase.execute(name: name, settings: settings)
            presets.insert(preset, at: 0) // Add to beginning (most recent)
            newPresetName = ""
            isShowingSaveDialog = false
            errorMessage = nil
        } catch {
            errorMessage = "preset.save_error".localized
        }
    }

    /// Delete a preset by ID
    public func deletePreset(id: UUID) {
        do {
            try deleteUseCase.execute(id: id)
            presets.removeAll { $0.id == id }
            errorMessage = nil
        } catch {
            errorMessage = "preset.delete_error".localized
        }
    }

    /// Apply a preset to the settings view model
    public func applyPreset(_ preset: ScalePreset, to settingsViewModel: RecordingSettingsViewModel) {
        let settings = preset.settings

        // Map scale type
        switch settings.scaleType {
        case "fiveTone":
            settingsViewModel.scaleType = .fiveTone
        case "octaveRepeat":
            settingsViewModel.scaleType = .octaveRepeat
        case "off":
            settingsViewModel.scaleType = .off
        default:
            settingsViewModel.scaleType = .fiveTone
        }

        settingsViewModel.startPitchIndex = settings.startPitchIndex
        settingsViewModel.tempo = settings.tempo
        settingsViewModel.keyProgressionPattern = settings.keyProgressionPattern
        settingsViewModel.ascendingKeyCount = settings.ascendingKeyCount
        settingsViewModel.descendingKeyCount = settings.descendingKeyCount
        settingsViewModel.ascendingKeyStepInterval = settings.ascendingKeyStepInterval
        settingsViewModel.descendingKeyStepInterval = settings.descendingKeyStepInterval

        isShowingPresetList = false
    }

    /// Check if a preset name is valid (not empty and not duplicate)
    public func isValidPresetName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return !presets.contains { $0.name == trimmed }
    }

    // MARK: - Private

    private func createPresetSettings(from viewModel: RecordingSettingsViewModel) -> ScalePresetSettings {
        let scaleTypeString: String
        switch viewModel.scaleType {
        case .fiveTone:
            scaleTypeString = "fiveTone"
        case .octaveRepeat:
            scaleTypeString = "octaveRepeat"
        case .off:
            scaleTypeString = "off"
        }

        return ScalePresetSettings(
            scaleType: scaleTypeString,
            startPitchIndex: viewModel.startPitchIndex,
            tempo: viewModel.tempo,
            keyProgressionPattern: viewModel.keyProgressionPattern,
            ascendingKeyCount: viewModel.ascendingKeyCount,
            descendingKeyCount: viewModel.descendingKeyCount,
            ascendingKeyStepInterval: viewModel.ascendingKeyStepInterval,
            descendingKeyStepInterval: viewModel.descendingKeyStepInterval
        )
    }
}
