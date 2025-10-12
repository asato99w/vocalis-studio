import Foundation
import AVFoundation

/// Wrapper for AVAudioPlayer
public class AVAudioPlayerWrapper: NSObject, AudioPlayerProtocol {

    private var audioPlayer: AVAudioPlayer?

    public var isPlaying: Bool {
        return audioPlayer?.isPlaying ?? false
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

            // Configure audio session for playback
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)

            // Play
            let success = audioPlayer?.play() ?? false
            if !success {
                throw AudioPlayerError.playbackFailed("Failed to start playback")
            }

            print("Playing audio from: \(url.lastPathComponent)")

        } catch let error as AudioPlayerError {
            throw error
        } catch {
            throw AudioPlayerError.playbackFailed(error.localizedDescription)
        }
    }

    public func stop() async {
        audioPlayer?.stop()
        audioPlayer = nil

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

// MARK: - AVAudioPlayerDelegate

extension AVAudioPlayerWrapper: AVAudioPlayerDelegate {

    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("Audio playback finished: \(flag ? "successfully" : "with error")")
    }

    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            print("Audio decode error: \(error.localizedDescription)")
        }
    }
}
