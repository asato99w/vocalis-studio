import Foundation
import VocalisDomain
import AVFoundation

/// Wrapper for AVAudioRecorder that implements AudioRecorderProtocol
public class AVAudioRecorderWrapper: NSObject, AudioRecorderProtocol {

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var startTime: Date?

    public var isRecording: Bool {
        return audioRecorder?.isRecording ?? false
    }

    public override init() {
        super.init()
    }

    // MARK: - AudioRecorderProtocol

    public func prepareRecording() async throws -> URL {
        // Configure audio session for recording
        try await configureAudioSession()

        // Generate unique recording file URL
        let url = generateRecordingURL()
        recordingURL = url

        // Configure audio settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        // Create AVAudioRecorder
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.prepareToRecord()
            return url
        } catch {
            throw AudioRecorderError.recordingFailed("Failed to prepare recording: \(error.localizedDescription)")
        }
    }

    public func startRecording() async throws {
        guard let recorder = audioRecorder else {
            throw AudioRecorderError.notPrepared
        }

        guard !recorder.isRecording else {
            throw AudioRecorderError.recordingFailed("Already recording")
        }

        // Start recording
        let success = recorder.record()
        if success {
            startTime = Date()
        } else {
            throw AudioRecorderError.recordingFailed("Failed to start recording")
        }
    }

    public func stopRecording() async throws -> TimeInterval {
        guard let recorder = audioRecorder else {
            throw AudioRecorderError.notRecording
        }

        guard recorder.isRecording else {
            throw AudioRecorderError.notRecording
        }

        // Stop recording
        recorder.stop()

        // Calculate duration
        guard let startTime = startTime else {
            return 0
        }

        let duration = Date().timeIntervalSince(startTime)

        // Reset state
        self.startTime = nil

        return duration
    }

    // MARK: - Private Methods

    private func configureAudioSession() async throws {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            // Set category to allow recording and playback simultaneously
            // .defaultToSpeaker ensures audio plays through speaker even when recording
            // .allowBluetooth allows bluetooth audio devices
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth]
            )

            // Set preferred sample rate to match our recording settings
            try audioSession.setPreferredSampleRate(44100.0)

            // Activate the audio session
            try audioSession.setActive(true)

            print("Audio session configured: category=\(audioSession.category), mode=\(audioSession.mode)")
        } catch {
            throw AudioRecorderError.recordingFailed("Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    private func generateRecordingURL() -> URL {
        // Use Documents directory for persistent storage
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        // Generate filename with timestamp: recording_yyyyMMdd_HHmmss.m4a
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let fileName = "recording_\(timestamp).m4a"

        let url = documentsDir.appendingPathComponent(fileName)
        print("Recording will be saved to: \(url.path)")

        return url
    }
}

// MARK: - AVAudioRecorderDelegate

extension AVAudioRecorderWrapper: AVAudioRecorderDelegate {

    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording finished unsuccessfully")
        }
    }

    public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("Recording encode error: \(error.localizedDescription)")
        }
    }
}
