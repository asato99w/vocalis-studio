import Foundation
import VocalisDomain

/// File-based recording repository using FileManager and UserDefaults
public class FileRecordingRepository: RecordingRepositoryProtocol {

    private let userDefaults: UserDefaults
    private let metadataKey = "recordings_metadata"

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func save(_ recording: Recording) async throws {
        // Load existing metadata
        var recordings = try await loadMetadata()

        // Add new recording
        recordings.append(recording)

        // Save metadata
        try saveMetadata(recordings)

        print("Saved recording: \(recording.fileURL.lastPathComponent)")
    }

    public func findAll() async throws -> [Recording] {
        var recordings = try await loadMetadata()

        // Filter out recordings whose files no longer exist
        let validRecordings = recordings.filter { recording in
            FileManager.default.fileExists(atPath: recording.fileURL.path)
        }

        // If some recordings were invalid, clean up metadata
        if validRecordings.count != recordings.count {
            print("Cleaning up \(recordings.count - validRecordings.count) invalid recordings from metadata")
            try saveMetadata(validRecordings)
            recordings = validRecordings
        }

        // Sort by creation date (newest first)
        return recordings.sorted { $0.createdAt > $1.createdAt }
    }

    public func findById(_ id: RecordingId) async throws -> Recording? {
        let recordings = try await loadMetadata()
        return recordings.first { $0.id == id }
    }

    public func delete(_ id: RecordingId) async throws {
        // Load metadata
        var recordings = try await loadMetadata()

        // Find recording to delete
        guard let index = recordings.firstIndex(where: { $0.id == id }) else {
            return // Already deleted
        }

        let recording = recordings[index]

        // Delete file if it exists
        if FileManager.default.fileExists(atPath: recording.fileURL.path) {
            try FileManager.default.removeItem(at: recording.fileURL)
            print("Deleted file: \(recording.fileURL.lastPathComponent)")
        } else {
            print("File already deleted: \(recording.fileURL.lastPathComponent)")
        }

        // Remove from metadata
        recordings.remove(at: index)

        // Save updated metadata
        try saveMetadata(recordings)

        print("Removed from metadata: \(recording.fileURL.lastPathComponent)")
    }

    // MARK: - Private Methods

    private func loadMetadata() async throws -> [Recording] {
        guard let data = userDefaults.data(forKey: metadataKey) else {
            return []
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode([Recording].self, from: data)
        } catch {
            print("Failed to decode recordings metadata: \(error)")
            return []
        }
    }

    private func saveMetadata(_ recordings: [Recording]) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(recordings)
        userDefaults.set(data, forKey: metadataKey)
    }
}
