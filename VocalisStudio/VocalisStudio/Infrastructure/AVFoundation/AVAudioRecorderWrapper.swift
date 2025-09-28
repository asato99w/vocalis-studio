import Foundation
import AVFoundation

#if os(iOS)
public class AVAudioRecorderWrapper: NSObject, AudioRecording {
    private var audioRecorder: AVAudioRecorder?
    private var recordingSession: AVAudioSession
    private var currentRecordingURL: URL?
    private var levelTimer: Timer?
    
    public private(set) var isRecording: Bool = false
    public var currentTime: TimeInterval {
        return audioRecorder?.currentTime ?? 0
    }
    
    public override init() {
        self.recordingSession = AVAudioSession.sharedInstance()
        super.init()
    }
    
    public func startRecording() async throws -> URL {
        // Request microphone permission
        let hasPermission = await requestMicrophonePermission()
        guard hasPermission else {
            throw AudioRecorderError.microphoneAccessDenied
        }
        
        // Configure audio session for optimal recording
        try recordingSession.setCategory(.playAndRecord, 
                                         mode: .default,
                                         options: [.defaultToSpeaker, .allowBluetooth])
        
        // Set gain for better volume (0.8 to avoid distortion)
        if recordingSession.isInputGainSettable {
            try recordingSession.setInputGain(0.8)
        }
        try recordingSession.setActive(true)
        
        // Create recording URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        let audioURL = documentsPath.appendingPathComponent(fileName)
        
        // Configure recording settings - simplified for better compatibility
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,  // Standard sample rate
            AVNumberOfChannelsKey: 1,  // Mono for better compatibility and smaller file size
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,  // High quality
            AVEncoderBitRateKey: 128000  // Standard bit rate (128 kbps)
        ]
        
        // Start recording
        audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true  // Enable metering for level monitoring
        audioRecorder?.prepareToRecord()
        audioRecorder?.record()
        
        // Start monitoring audio levels
        startLevelMonitoring()
        
        isRecording = true
        currentRecordingURL = audioURL
        
        return audioURL
    }
    
    public func stopRecording() async throws {
        // Stop level monitoring
        stopLevelMonitoring()
        
        audioRecorder?.stop()
        isRecording = false
        try recordingSession.setActive(false)
    }
    
    public func pauseRecording() {
        if isRecording {
            audioRecorder?.pause()
        }
    }
    
    public func resumeRecording() {
        if isRecording {
            audioRecorder?.record()
        }
    }
    
    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            recordingSession.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    private func startLevelMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder else { return }
            
            recorder.updateMeters()
            let averagePower = recorder.averagePower(forChannel: 0)
            let peakPower = recorder.peakPower(forChannel: 0)
            
            // Log levels for debugging (remove in production)
            #if DEBUG
            if averagePower < -40 {
                print("⚠️ Low recording level: avg=\(averagePower)dB, peak=\(peakPower)dB")
            }
            #endif
            
            // Auto-adjust gain if level is too low
            if averagePower < -35 && self.recordingSession.isInputGainSettable {
                do {
                    let currentGain = self.recordingSession.inputGain
                    let newGain = min(currentGain + 0.05, 0.9)  // More gradual adjustment, max 0.9 to avoid distortion
                    try self.recordingSession.setInputGain(newGain)
                } catch {
                    print("Failed to adjust input gain: \(error)")
                }
            }
        }
    }
    
    private func stopLevelMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
    }
}

extension AVAudioRecorderWrapper: AVAudioRecorderDelegate {
    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        isRecording = false
    }
    
    public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        isRecording = false
    }
}

#else
// macOS用のダミー実装（テスト用）
public class AVAudioRecorderWrapper: NSObject, AudioRecording {
    public private(set) var isRecording: Bool = false
    public var currentTime: TimeInterval = 0
    
    public override init() {
        super.init()
    }
    
    public func startRecording() async throws -> URL {
        isRecording = true
        return URL(fileURLWithPath: "/tmp/test.m4a")
    }
    
    public func stopRecording() async throws {
        isRecording = false
    }
    
    public func pauseRecording() {}
    public func resumeRecording() {}
}
#endif