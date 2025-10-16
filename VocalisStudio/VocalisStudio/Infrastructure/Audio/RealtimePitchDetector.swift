import Foundation
import AVFoundation
import VocalisDomain
import Combine

/// Real-time pitch detector using AudioKit FFT algorithm
@MainActor
public class RealtimePitchDetector: ObservableObject {
    @Published public private(set) var detectedPitch: DetectedPitch?
    @Published public private(set) var isDetecting: Bool = false

    private let audioEngine = AVAudioEngine()
    private var detectionTimer: Timer?
    private var audioBuffer: [Float] = []
    private let bufferSize = 4096
    private let hopSize = 2048

    public init() {}

    /// Start real-time pitch detection from microphone
    public func startRealtimeDetection() throws {
        guard !isDetecting else { return }

        // Configure audio session for simultaneous playback and recording
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true)

        // Configure audio engine
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: UInt32(hopSize), format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.processAudioBuffer(buffer)
        }

        // Start engine
        try audioEngine.start()
        isDetecting = true

        print("✅ Started real-time pitch detection")
    }

    /// Stop real-time pitch detection
    public func stopRealtimeDetection() {
        guard isDetecting else { return }

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isDetecting = false
        detectedPitch = nil

        print("⏸ Stopped real-time pitch detection")
    }

    /// Process audio buffer and detect pitch
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))

        // Append to buffer
        audioBuffer.append(contentsOf: samples)

        // Keep buffer size manageable
        if audioBuffer.count > bufferSize {
            audioBuffer.removeFirst(audioBuffer.count - bufferSize)
        }

        // Detect pitch if we have enough samples
        if audioBuffer.count >= bufferSize {
            Task { @MainActor in
                self.detectPitchFromSamples(Array(audioBuffer.suffix(bufferSize)))
            }
        }
    }

    /// Detect pitch from audio samples using autocorrelation
    private func detectPitchFromSamples(_ samples: [Float]) {
        // Calculate RMS amplitude
        let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))

        // Silence threshold
        guard rms > 0.01 else {
            detectedPitch = nil
            return
        }

        // Autocorrelation-based pitch detection
        let sampleRate = 44100.0
        let minLag = Int(sampleRate / 1000.0)  // Max 1000 Hz
        let maxLag = Int(sampleRate / 80.0)    // Min 80 Hz

        var bestLag = 0
        var bestCorrelation: Float = 0

        for lag in minLag..<min(maxLag, samples.count / 2) {
            var correlation: Float = 0
            for i in 0..<(samples.count - lag) {
                correlation += samples[i] * samples[i + lag]
            }

            if correlation > bestCorrelation {
                bestCorrelation = correlation
                bestLag = lag
            }
        }

        guard bestLag > 0 else {
            detectedPitch = nil
            return
        }

        let frequency = sampleRate / Double(bestLag)

        // Confidence based on correlation strength and RMS
        let normalizedCorrelation = bestCorrelation / Float(samples.count - bestLag)
        let confidence = min(Double(rms * normalizedCorrelation * 10.0), 1.0)

        // Only report if confidence is high enough
        guard confidence > 0.3 else {
            detectedPitch = nil
            return
        }

        // Create detected pitch
        detectedPitch = DetectedPitch.fromFrequency(
            frequency,
            confidence: confidence
        )
    }

    /// Analyze pitch from audio file (for playback analysis)
    public func analyzePitchFromFile(
        _ url: URL,
        atTime time: TimeInterval,
        completion: @escaping (DetectedPitch?) -> Void
    ) {
        Task {
            do {
                let audioFile = try AVAudioFile(forReading: url)
                let format = audioFile.processingFormat
                let sampleRate = format.sampleRate

                // Calculate frame position
                let framePosition = AVAudioFramePosition(time * sampleRate)

                guard framePosition < audioFile.length else {
                    await MainActor.run { completion(nil) }
                    return
                }

                // Read samples around the target time
                audioFile.framePosition = max(0, framePosition - AVAudioFramePosition(bufferSize / 2))

                guard let buffer = AVAudioPCMBuffer(
                    pcmFormat: format,
                    frameCapacity: AVAudioFrameCount(bufferSize)
                ) else {
                    await MainActor.run { completion(nil) }
                    return
                }

                try audioFile.read(into: buffer)

                guard let floatChannelData = buffer.floatChannelData else {
                    await MainActor.run { completion(nil) }
                    return
                }

                let samples = Array(UnsafeBufferPointer(
                    start: floatChannelData[0],
                    count: Int(buffer.frameLength)
                ))

                // Detect pitch from samples
                let pitch = await detectPitchFromSamplesSync(samples, sampleRate: sampleRate)
                await MainActor.run { completion(pitch) }

            } catch {
                print("❌ Failed to analyze file: \(error)")
                await MainActor.run { completion(nil) }
            }
        }
    }

    /// Synchronous pitch detection for file analysis
    private func detectPitchFromSamplesSync(_ samples: [Float], sampleRate: Double) async -> DetectedPitch? {
        // Calculate RMS amplitude
        let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))

        guard rms > 0.01 else { return nil }

        // Autocorrelation
        let minLag = Int(sampleRate / 1000.0)
        let maxLag = Int(sampleRate / 80.0)

        var bestLag = 0
        var bestCorrelation: Float = 0

        for lag in minLag..<min(maxLag, samples.count / 2) {
            var correlation: Float = 0
            for i in 0..<(samples.count - lag) {
                correlation += samples[i] * samples[i + lag]
            }

            if correlation > bestCorrelation {
                bestCorrelation = correlation
                bestLag = lag
            }
        }

        guard bestLag > 0 else { return nil }

        let frequency = sampleRate / Double(bestLag)
        let normalizedCorrelation = bestCorrelation / Float(samples.count - bestLag)
        let confidence = min(Double(rms * normalizedCorrelation * 10.0), 1.0)

        guard confidence > 0.3 else { return nil }

        return DetectedPitch.fromFrequency(frequency, confidence: confidence)
    }
}
