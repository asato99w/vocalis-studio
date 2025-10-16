import Foundation
import VocalisDomain
import AVFoundation

/// Wrapper for AVAudioPlayer
public class AVAudioPlayerWrapper: NSObject, AudioPlayerProtocol {

    private var audioPlayer: AVAudioPlayer?
    private var playbackContinuation: CheckedContinuation<Void, Error>?

    public var isPlaying: Bool {
        return audioPlayer?.isPlaying ?? false
    }

    public var currentTime: TimeInterval {
        return audioPlayer?.currentTime ?? 0
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
            // Use playAndRecord to be compatible with pitch detection
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true)

            // Play
            let success = audioPlayer?.play() ?? false
            if !success {
                throw AudioPlayerError.playbackFailed("Failed to start playback")
            }

            print("Playing audio from: \(url.lastPathComponent)")
            print("AVAudioPlayer isPlaying after play(): \(audioPlayer?.isPlaying ?? false)")
            print("AVAudioPlayer duration: \(audioPlayer?.duration ?? 0) seconds")

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

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

// MARK: - AVAudioPlayerDelegate

extension AVAudioPlayerWrapper: AVAudioPlayerDelegate {

    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("Audio playback finished: \(flag ? "successfully" : "with error")")

        if flag {
            playbackContinuation?.resume()
        } else {
            playbackContinuation?.resume(throwing: AudioPlayerError.playbackFailed("Playback did not complete successfully"))
        }
        playbackContinuation = nil
    }

    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            print("Audio decode error: \(error.localizedDescription)")
            playbackContinuation?.resume(throwing: AudioPlayerError.playbackFailed(error.localizedDescription))
            playbackContinuation = nil
        }
    }
}
