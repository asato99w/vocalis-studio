import Foundation
import AVFoundation
import VocalisDomain
import Combine
import Accelerate

/// Real-time pitch detector using FFT-based analysis
@MainActor
public class RealtimePitchDetector: ObservableObject {
    @Published public private(set) var detectedPitch: DetectedPitch?
    @Published public private(set) var isDetecting: Bool = false
    @Published public private(set) var spectrum: [Float]?

    private let audioEngine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private let bufferSize = 4096
    private let hopSize = 2048

    // FFT setup
    private var fftSetup: vDSP_DFT_Setup?
    private let log2n: vDSP_Length

    public init() {
        log2n = vDSP_Length(log2(Double(bufferSize)))
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(bufferSize), vDSP_DFT_Direction.FORWARD)
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

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
    }

    /// Stop real-time pitch detection
    public func stopRealtimeDetection() {
        guard isDetecting else { return }

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isDetecting = false
        detectedPitch = nil
        spectrum = nil
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

    /// Detect pitch from audio samples using FFT-based analysis
    private func detectPitchFromSamples(_ samples: [Float]) {
        // Calculate RMS amplitude
        let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))

        // Silence threshold
        guard rms > 0.02 else {
            detectedPitch = nil
            spectrum = nil
            return
        }

        guard let setup = fftSetup else {
            detectedPitch = nil
            spectrum = nil
            return
        }

        let sampleRate = 44100.0
        let minFreq = 100.0  // G2 - avoid low frequency noise
        let maxFreq = 800.0  // G5 - typical singing range for realtime

        // Prepare buffers for FFT
        var realPartIn = [Float](repeating: 0, count: bufferSize)
        var imagPartIn = [Float](repeating: 0, count: bufferSize)
        var realPartOut = [Float](repeating: 0, count: bufferSize)
        var imagPartOut = [Float](repeating: 0, count: bufferSize)

        // Apply Hanning window to reduce spectral leakage
        var window = [Float](repeating: 0, count: bufferSize)
        vDSP_hann_window(&window, vDSP_Length(bufferSize), Int32(vDSP_HANN_NORM))

        var windowedSamples = [Float](repeating: 0, count: bufferSize)
        vDSP_vmul(samples, 1, window, 1, &windowedSamples, 1, vDSP_Length(bufferSize))

        // Copy windowed samples to real part
        realPartIn = windowedSamples

        // Perform FFT
        vDSP_DFT_Execute(setup, &realPartIn, &imagPartIn, &realPartOut, &imagPartOut)

        // Calculate magnitude spectrum
        var magnitudes = [Float](repeating: 0, count: bufferSize / 2)
        realPartOut.withUnsafeMutableBufferPointer { realPtr in
            imagPartOut.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                vDSP_zvabs(&splitComplex, 1, &magnitudes, 1, vDSP_Length(bufferSize / 2))
            }
        }

        // Apply Harmonic Product Spectrum (HPS) to find fundamental frequency
        let minBin = Int(minFreq * Double(bufferSize) / sampleRate)
        let maxBin = Int(maxFreq * Double(bufferSize) / sampleRate)

        guard minBin < maxBin && maxBin < magnitudes.count else {
            detectedPitch = nil
            spectrum = nil
            return
        }

        // Publish spectrum data for visualization (100-800 Hz range)
        spectrum = Array(magnitudes[minBin..<maxBin])

        // Create HPS by multiplying harmonics (start from fundamental, then multiply by harmonics)
        let numHarmonics = 5 // Use harmonics 1, 2, 3, 4, 5
        var hps = [Float](repeating: 0.0, count: maxBin)

        // Initialize with fundamental (1st harmonic)
        for bin in minBin..<maxBin {
            hps[bin] = magnitudes[bin]
        }

        // Multiply by higher harmonics (2nd through 5th)
        for harmonic in 2...numHarmonics {
            for bin in minBin..<maxBin {
                let downsampledBin = bin * harmonic
                if downsampledBin < magnitudes.count {
                    hps[bin] *= magnitudes[downsampledBin]
                }
            }
        }

        // Find peak in HPS (this will be the fundamental frequency)
        var maxMagnitude: Float = 0
        var peakBin = 0

        for bin in minBin..<maxBin {
            if hps[bin] > maxMagnitude {
                maxMagnitude = hps[bin]
                peakBin = bin
            }
        }

        guard maxMagnitude > 0.01 else {
            detectedPitch = nil
            return
        }

        // Parabolic interpolation using HPS values for sub-bin accuracy
        var interpolatedBin = Double(peakBin)
        if peakBin > 0 && peakBin < hps.count - 1 {
            let alpha = Double(hps[peakBin - 1])
            let beta = Double(hps[peakBin])
            let gamma = Double(hps[peakBin + 1])

            let denominator = alpha - 2.0 * beta + gamma
            if abs(denominator) > 0.0001 {  // Avoid division by near-zero
                let offset = 0.5 * (alpha - gamma) / denominator
                // Clamp offset to reasonable range
                let clampedOffset = max(-0.5, min(0.5, offset))
                interpolatedBin = Double(peakBin) + clampedOffset
            }
        }

        // Convert bin to frequency
        let frequency = interpolatedBin * sampleRate / Double(bufferSize)

        // Calculate confidence based on peak prominence
        let avgMagnitude = magnitudes[minBin..<maxBin].reduce(0, +) / Float(maxBin - minBin)
        let confidence = min(Double(maxMagnitude / (avgMagnitude + 0.001)), 1.0)

        // Only report if confidence is high enough
        guard confidence > 0.4 else {
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

    /// Synchronous pitch detection for file analysis using FFT
    private func detectPitchFromSamplesSync(_ samples: [Float], sampleRate: Double) async -> DetectedPitch? {
        // Calculate RMS amplitude
        let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))

        // Lower threshold for recorded playback (recorded files tend to have lower amplitude)
        if rms <= 0.001 {
            await MainActor.run { self.spectrum = nil }
            return nil
        }

        guard let setup = fftSetup else {
            await MainActor.run { self.spectrum = nil }
            return nil
        }

        // Focus on fundamental frequency range for singing voice
        let minFreq = 100.0  // G2 - avoid low frequency noise
        let maxFreq = 500.0  // B4 - typical singing range
        let size = min(samples.count, bufferSize)

        // Prepare buffers
        var realPartIn = [Float](repeating: 0, count: bufferSize)
        var imagPartIn = [Float](repeating: 0, count: bufferSize)
        var realPartOut = [Float](repeating: 0, count: bufferSize)
        var imagPartOut = [Float](repeating: 0, count: bufferSize)

        // Apply window
        var window = [Float](repeating: 0, count: size)
        vDSP_hann_window(&window, vDSP_Length(size), Int32(vDSP_HANN_NORM))

        var windowedSamples = [Float](repeating: 0, count: size)
        vDSP_vmul(Array(samples.prefix(size)), 1, window, 1, &windowedSamples, 1, vDSP_Length(size))

        realPartIn[0..<size] = windowedSamples[0..<size]

        // Perform FFT
        vDSP_DFT_Execute(setup, &realPartIn, &imagPartIn, &realPartOut, &imagPartOut)

        // Calculate magnitudes
        var magnitudes = [Float](repeating: 0, count: bufferSize / 2)
        realPartOut.withUnsafeMutableBufferPointer { realPtr in
            imagPartOut.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                vDSP_zvabs(&splitComplex, 1, &magnitudes, 1, vDSP_Length(bufferSize / 2))
            }
        }

        // Apply Harmonic Product Spectrum (HPS) to find fundamental frequency
        let minBin = Int(minFreq * Double(bufferSize) / sampleRate)
        let maxBin = Int(maxFreq * Double(bufferSize) / sampleRate)

        guard minBin < maxBin && maxBin < magnitudes.count else {
            await MainActor.run { self.spectrum = nil }
            return nil
        }

        // Publish spectrum data for visualization (100-500 Hz range for playback)
        await MainActor.run {
            self.spectrum = Array(magnitudes[minBin..<maxBin])
        }

        // Create HPS by multiplying harmonics (start from fundamental, then multiply by harmonics)
        let numHarmonics = 5 // Use harmonics 1, 2, 3, 4, 5
        var hps = [Float](repeating: 0.0, count: maxBin)

        // Initialize with fundamental (1st harmonic)
        for bin in minBin..<maxBin {
            hps[bin] = magnitudes[bin]
        }

        // Multiply by higher harmonics (2nd through 5th)
        for harmonic in 2...numHarmonics {
            for bin in minBin..<maxBin {
                let downsampledBin = bin * harmonic
                if downsampledBin < magnitudes.count {
                    hps[bin] *= magnitudes[downsampledBin]
                }
            }
        }

        // Find peak in HPS (this will be the fundamental frequency)
        var maxMagnitude: Float = 0
        var peakBin = 0

        for bin in minBin..<maxBin {
            if hps[bin] > maxMagnitude {
                maxMagnitude = hps[bin]
                peakBin = bin
            }
        }

        if maxMagnitude <= 0.001 {  // Lowered from 0.01
            return nil
        }

        // Parabolic interpolation using HPS values
        var interpolatedBin = Double(peakBin)
        if peakBin > 0 && peakBin < hps.count - 1 {
            let alpha = Double(hps[peakBin - 1])
            let beta = Double(hps[peakBin])
            let gamma = Double(hps[peakBin + 1])

            let denominator = alpha - 2.0 * beta + gamma
            if abs(denominator) > 0.0001 {  // Avoid division by near-zero
                let offset = 0.5 * (alpha - gamma) / denominator
                // Clamp offset to reasonable range
                let clampedOffset = max(-0.5, min(0.5, offset))
                interpolatedBin = Double(peakBin) + clampedOffset
            }
        }

        let frequency = interpolatedBin * sampleRate / Double(bufferSize)

        // Validate frequency is in expected range
        guard frequency >= minFreq && frequency <= maxFreq else {
            return nil
        }

        // Calculate confidence
        let avgMagnitude = magnitudes[minBin..<maxBin].reduce(0, +) / Float(maxBin - minBin)
        let confidence = min(Double(maxMagnitude / (avgMagnitude + 0.001)), 1.0)

        // Lower confidence threshold for playback analysis
        if confidence <= 0.3 {  // Lowered from 0.4
            return nil
        }

        let pitch = DetectedPitch.fromFrequency(frequency, confidence: confidence)
        return pitch
    }
}
