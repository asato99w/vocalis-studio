import Foundation

public protocol RecordingRepository {
    func save(_ recording: Recording) async throws
    func findById(_ id: RecordingId) async throws -> Recording?
    func findAll() async throws -> [Recording]
    func delete(_ id: RecordingId) async throws
}