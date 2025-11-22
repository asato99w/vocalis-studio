import Foundation

/// Protocol for scale preset persistence operations
public protocol ScalePresetRepositoryProtocol {
    /// Load all saved presets
    func loadAll() -> [ScalePreset]

    /// Save a new preset or update an existing one
    func save(_ preset: ScalePreset) throws

    /// Delete a preset by ID
    func delete(id: UUID) throws

    /// Find a preset by ID
    func find(id: UUID) -> ScalePreset?
}

/// Errors that can occur during preset repository operations
public enum ScalePresetRepositoryError: Error, Equatable {
    case saveFailed(String)
    case deleteFailed(String)
    case notFound
}
