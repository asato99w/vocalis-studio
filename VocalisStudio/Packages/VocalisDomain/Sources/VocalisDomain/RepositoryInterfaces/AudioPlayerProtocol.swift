import Foundation

/// Protocol for audio playback
public protocol AudioPlayerProtocol {
    func play(url: URL) async throws
    func stop() async
    func pause()
    func resume()
    func seek(to time: TimeInterval)
    var isPlaying: Bool { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
}

public enum AudioPlayerError: LocalizedError, Equatable {
    case fileNotFound
    case playbackFailed(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Audio file not found"
        case .playbackFailed(let message):
            return "Playback failed: \(message)"
        }
    }
}
