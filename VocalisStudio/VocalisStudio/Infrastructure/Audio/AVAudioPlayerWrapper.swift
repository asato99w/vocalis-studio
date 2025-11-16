import Foundation
import VocalisDomain
import AVFoundation

/// Wrapper for AVAudioPlayer
public class AVAudioPlayerWrapper: NSObject, AudioPlayerProtocol {

    private let settingsRepository: AudioSettingsRepositoryProtocol
    private var audioPlayer: AVAudioPlayer?
    private var playbackContinuation: CheckedContinuation<Void, Error>?

    public init(settingsRepository: AudioSettingsRepositoryProtocol) {
        self.settingsRepository = settingsRepository
        super.init()
    }

    public var isPlaying: Bool {
        return audioPlayer?.isPlaying ?? false
    }

    public var currentTime: TimeInterval {
        return audioPlayer?.currentTime ?? 0
    }

    public var duration: TimeInterval {
        return audioPlayer?.duration ?? 0
    }

    public func pause() {
        audioPlayer?.pause()

        // Resume continuation to prevent leak
        // Bug: Without resuming, continuation remains waiting indefinitely
        // Symptom: Repeated play-pause cycles cause playback to stop working
        // Fix: Resume continuation on pause since AnalysisViewModel uses timer-based
        //      tracking and doesn't depend on continuation completion
        playbackContinuation?.resume()
        playbackContinuation = nil
    }

    public func resume() {
        audioPlayer?.play()
    }

    public func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
    }

    public func play(url: URL) async throws {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioPlayerError.fileNotFound
        }

        do {
            // Create audio player
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self

            // Apply recording playback volume from settings
            let settings = settingsRepository.get()
            audioPlayer?.volume = settings.recordingPlaybackVolume

            // Configure audio session for playback with recording support
            // Use playAndRecord to be compatible with pitch detection
            try AudioSessionManager.shared.configureForRecordingAndPlayback()
            try AudioSessionManager.shared.activate()

            // Play
            let success = audioPlayer?.play() ?? false
            if !success {
                throw AudioPlayerError.playbackFailed("Failed to start playback")
            }

            // Wait for playback to complete
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.playbackContinuation = continuation
            }

        } catch let error as AudioPlayerError {
            throw error
        } catch {
            throw AudioPlayerError.playbackFailed(error.localizedDescription)
        }
    }

    public func stop() async {
        audioPlayer?.stop()
        audioPlayer = nil

        // Resume continuation if waiting
        playbackContinuation?.resume()
        playbackContinuation = nil

        // Deactivate audio session using centralized manager
        try? AudioSessionManager.shared.deactivate()
    }
}

// MARK: - AVAudioPlayerDelegate

extension AVAudioPlayerWrapper: AVAudioPlayerDelegate {

    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            playbackContinuation?.resume()
        } else {
            playbackContinuation?.resume(throwing: AudioPlayerError.playbackFailed("Playback did not complete successfully"))
        }
        playbackContinuation = nil
    }

    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            playbackContinuation?.resume(throwing: AudioPlayerError.playbackFailed(error.localizedDescription))
            playbackContinuation = nil
        }
    }
}
