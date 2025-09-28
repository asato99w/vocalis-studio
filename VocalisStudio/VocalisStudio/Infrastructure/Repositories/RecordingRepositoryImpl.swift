import Foundation

public class RecordingRepositoryImpl: RecordingRepository {
    private var recordings: [RecordingId: Recording] = [:]
    private let fileManager = FileManager.default
    private let recordingsDirectory: URL
    
    public init() throws {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.recordingsDirectory = documentsPath.appendingPathComponent("Recordings")
        
        // Create recordings directory if it doesn't exist
        if !fileManager.fileExists(atPath: recordingsDirectory.path) {
            try fileManager.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
        }
    }
    
    public func save(_ recording: Recording) async throws {
        recordings[recording.id] = recording
        
        // Save metadata to disk
        let metadataURL = recordingsDirectory.appendingPathComponent("\(recording.id.value.uuidString).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(RecordingMetadata(from: recording))
        try data.write(to: metadataURL)
    }
    
    public func findById(_ id: RecordingId) async throws -> Recording? {
        // First check in-memory cache
        if let recording = recordings[id] {
            return recording
        }
        
        // Try to load from disk
        let metadataURL = recordingsDirectory.appendingPathComponent("\(id.value.uuidString).json")
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: metadataURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let metadata = try decoder.decode(RecordingMetadata.self, from: data)
        let recording = metadata.toRecording()
        
        // Cache it
        recordings[id] = recording
        
        return recording
    }
    
    public func findAll() async throws -> [Recording] {
        var allRecordings: [Recording] = []
        
        let contents = try fileManager.contentsOfDirectory(at: recordingsDirectory, includingPropertiesForKeys: nil)
        let jsonFiles = contents.filter { $0.pathExtension == "json" }
        
        for file in jsonFiles {
            let data = try Data(contentsOf: file)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let metadata = try decoder.decode(RecordingMetadata.self, from: data)
            allRecordings.append(metadata.toRecording())
        }
        
        return allRecordings
    }
    
    public func delete(_ id: RecordingId) async throws {
        // Remove from cache
        if let recording = recordings.removeValue(forKey: id) {
            // Delete audio file
            try? fileManager.removeItem(at: recording.audioFileUrl)
        }
        
        // Delete metadata file
        let metadataURL = recordingsDirectory.appendingPathComponent("\(id.value.uuidString).json")
        try? fileManager.removeItem(at: metadataURL)
    }
}

// Helper struct for JSON encoding/decoding
private struct RecordingMetadata: Codable {
    let id: UUID
    let audioFileUrl: URL
    let startTime: Date
    let endTime: Date?
    
    init(from recording: Recording) {
        self.id = recording.id.value
        self.audioFileUrl = recording.audioFileUrl
        self.startTime = recording.startTime
        self.endTime = recording.endTime
    }
    
    func toRecording() -> Recording {
        Recording(
            id: RecordingId(value: id),
            audioFileUrl: audioFileUrl,
            startTime: startTime,
            endTime: endTime
        )
    }
}