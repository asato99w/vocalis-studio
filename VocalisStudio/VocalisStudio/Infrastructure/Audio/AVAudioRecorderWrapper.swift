import Foundation
import VocalisDomain
import AVFoundation
import OSLog

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
        Logger.recording.info("Preparing recording")

        // Configure audio session for recording
        try await configureAudioSession()

        // Generate unique recording file URL
        let url = generateRecordingURL()
        recordingURL = url
        Logger.recording.debug("Recording URL: \(url.lastPathComponent)")

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
            Logger.recording.info("Recording prepared successfully")
            FileLogger.shared.log(level: "INFO", category: "recording", message: "Recording prepared successfully: \(url.lastPathComponent)")
            return url
        } catch {
            Logger.recording.logError(error)
            throw AudioRecorderError.recordingFailed("Failed to prepare recording: \(error.localizedDescription)")
        }
    }

    public func startRecording() async throws {
        guard let recorder = audioRecorder else {
            Logger.recording.error("Start recording failed: not prepared")
            throw AudioRecorderError.notPrepared
        }

        guard !recorder.isRecording else {
            Logger.recording.warning("Start recording ignored: already recording")
            throw AudioRecorderError.recordingFailed("Already recording")
        }

        // Start recording
        let success = recorder.record()
        if success {
            startTime = Date()
            Logger.recording.info("Recording started")
            FileLogger.shared.log(level: "INFO", category: "recording", message: "Recording started")
        } else {
            Logger.recording.error("Failed to start AVAudioRecorder")
            throw AudioRecorderError.recordingFailed("Failed to start recording")
        }
    }

    public func stopRecording() async throws -> TimeInterval {
        guard let recorder = audioRecorder else {
            Logger.recording.error("Stop recording failed: not initialized")
            throw AudioRecorderError.notRecording
        }

        guard recorder.isRecording else {
            Logger.recording.warning("Stop recording ignored: not recording")
            throw AudioRecorderError.notRecording
        }

        // Stop recording
        recorder.stop()
        Logger.recording.info("Recording stopped")

        // Calculate duration
        guard let startTime = startTime else {
            Logger.recording.warning("Recording duration unknown: startTime was nil")
            return 0
        }

        let duration = Date().timeIntervalSince(startTime)
        Logger.recording.info("Recording duration: \(String(format: "%.2f", duration))s")

        // Reset state
        self.startTime = nil

        return duration
    }

    // MARK: - Private Methods

    private func configureAudioSession() async throws {
        Logger.audio.info("Configuring audio session for recording")
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
            Logger.audio.info("Audio session configured: category=playAndRecord, sampleRate=44100Hz")
            FileLogger.shared.log(level: "INFO", category: "audio", message: "Audio session configured: category=playAndRecord, sampleRate=44100Hz")
        } catch {
            Logger.audio.logError(error)
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
        return url
    }
}

// MARK: - AVAudioRecorderDelegate

extension AVAudioRecorderWrapper: AVAudioRecorderDelegate {

    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            Logger.recording.info("Recording finished successfully")
        } else {
            Logger.recording.error("Recording finished with failure")
        }
    }

    public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            Logger.recording.error("Encoding error: \(error.localizedDescription)")
        }
    }
}
