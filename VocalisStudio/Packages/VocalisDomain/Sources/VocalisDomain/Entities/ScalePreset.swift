import Foundation

/// Scale preset settings that can be saved and reused
public struct ScalePresetSettings: Codable, Equatable, Hashable {
    public let scaleType: String  // "fiveTone", "octaveRepeat", "off"
    public let startPitchIndex: Int
    public let tempo: Int
    public let keyProgressionPattern: KeyProgressionPattern
    public let ascendingKeyCount: Int
    public let descendingKeyCount: Int
    public let ascendingKeyStepInterval: Int
    public let descendingKeyStepInterval: Int

    public init(
        scaleType: String,
        startPitchIndex: Int,
        tempo: Int,
        keyProgressionPattern: KeyProgressionPattern,
        ascendingKeyCount: Int,
        descendingKeyCount: Int,
        ascendingKeyStepInterval: Int,
        descendingKeyStepInterval: Int
    ) {
        self.scaleType = scaleType
        self.startPitchIndex = startPitchIndex
        self.tempo = tempo
        self.keyProgressionPattern = keyProgressionPattern
        self.ascendingKeyCount = ascendingKeyCount
        self.descendingKeyCount = descendingKeyCount
        self.ascendingKeyStepInterval = ascendingKeyStepInterval
        self.descendingKeyStepInterval = descendingKeyStepInterval
    }
}

/// A saved scale preset with metadata
public struct ScalePreset: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public var name: String
    public let settings: ScalePresetSettings
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        settings: ScalePresetSettings,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.settings = settings
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Update the preset name
    public func withUpdatedName(_ newName: String) -> ScalePreset {
        ScalePreset(
            id: id,
            name: newName,
            settings: settings,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
}
