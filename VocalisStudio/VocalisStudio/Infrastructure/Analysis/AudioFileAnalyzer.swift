import Foundation
import AVFoundation
import VocalisDomain
import Accelerate
import OSLog

/// Analyzes audio files for pitch and spectrogram data
/// Uses YIN algorithm for pitch detection and FFT for spectrogram
public class AudioFileAnalyzer: AudioFileAnalyzerProtocol {
    private let logger = Logger(subsystem: "com.kazuasato.VocalisStudio", category: "AudioFileAnalyzer")

    // YIN parameters for pitch detection
    private let yinBufferSize = 2048  // Smaller buffer for better time resolution
    private let sampleRate = 44100.0

    // Analysis parameters
    private let pitchSamplingInterval = 0.05  // 50ms for pitch analysis
    private let spectrogramSamplingInterval = 0.05  // 50ms for spectrogram (Phase 2: 100ms→50ms for 2x time resolution)

    // Frequency ranges
    private let minFreq = 80.0   // Lower bound for pitch detection (expanded)
    private let maxFreq = 1000.0  // Upper bound for pitch detection (expanded)
    private let spectrogramFreqBins = 1200  // Number of frequency bins for spectrogram (Phase 4: 400→1200 for 6kHz range)
    private let spectrogramMaxFreq = 6000.0  // Max frequency for spectrogram (Phase 4: 2kHz→6kHz, maintains 5Hz/bin resolution)

    // YIN threshold
    private let yinThreshold: Float = 0.25  // Relaxed for better detection (was 0.15)

    // Spectrogram FFT buffer size
    private let spectrogramBufferSize = 8192  // Phase 3: 4096→8192 for 2x better frequency resolution (5.38Hz/bin)

    public init() {}

    public func analyze(fileURL: URL, progress: @escaping @MainActor (Double) async -> Void) async throws -> (pitchData: PitchAnalysisData, spectrogramData: SpectrogramData) {
        logger.info("Starting analysis for file: \(fileURL.path)")

        // Report initial progress
        await progress(0.0)

        // Load audio file
        let audioFile = try AVAudioFile(forReading: fileURL)
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AnalysisError.bufferAllocationFailed
        }

        try audioFile.read(into: buffer)

        guard let channelData = buffer.floatChannelData else {
            throw AnalysisError.noChannelData
        }

        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: Int(buffer.frameLength)))
        let duration = Double(samples.count) / sampleRate

        logger.info("File loaded: \(samples.count) samples, duration: \(String(format: "%.2f", duration))s")

        // Analyze pitch (0% → 50%)
        let pitchData = try await analyzePitch(samples: samples, duration: duration) { pitchProgress in
            await progress(pitchProgress * 0.5)  // Scale to 0.0 → 0.5
        }

        // Analyze spectrogram (50% → 100%)
        let spectrogramData = try await analyzeSpectrogram(samples: samples, duration: duration) { spectrogramProgress in
            await progress(0.5 + spectrogramProgress * 0.5)  // Scale to 0.5 → 1.0
        }

        // Report final progress
        await progress(1.0)

        logger.info("Analysis completed")

        return (pitchData, spectrogramData)
    }

    // MARK: - Pitch Analysis

    private func analyzePitch(samples: [Float], duration: Double, progress: @escaping @MainActor (Double) async -> Void) async throws -> PitchAnalysisData {
        var timeStamps: [Double] = []
        var frequencies: [Float] = []
        var confidences: [Float] = []
        var targetNotes: [MIDINote?] = []

        let hopSamples = Int(sampleRate * pitchSamplingInterval)
        var position = 0
        let totalSamples = samples.count
        var lastReportedProgress: Double = 0.0

        while position + yinBufferSize <= samples.count {
            let timestamp = Double(position) / sampleRate
            let chunk = Array(samples[position..<(position + yinBufferSize)])

            if let (frequency, confidence) = detectPitchUsingYIN(chunk) {
                timeStamps.append(timestamp)
                frequencies.append(frequency)
                confidences.append(confidence)
                targetNotes.append(nil)  // Target notes will be set by ViewModel based on scaleSettings
            }

            position += hopSamples

            // Report progress every 10% to avoid UI update overhead
            let currentProgress = Double(position) / Double(totalSamples)
            if currentProgress - lastReportedProgress >= 0.1 {
                await progress(currentProgress)
                lastReportedProgress = currentProgress
            }
        }

        // Report final progress
        await progress(1.0)

        let totalWindows = samples.count / hopSamples
        let detectionRate = timeStamps.isEmpty ? 0.0 : Double(timeStamps.count) / Double(totalWindows) * 100.0

        logger.info("Pitch analysis: \(timeStamps.count)/\(totalWindows) windows detected (\(String(format: "%.1f", detectionRate))%)")
        if timeStamps.isEmpty {
            logger.warning("No pitch data detected - audio might be too quiet or contains no vocal content")
        } else {
            let minFreq = frequencies.min() ?? 0
            let maxFreq = frequencies.max() ?? 0
            let avgConfidence = confidences.reduce(0, +) / Float(confidences.count)
            logger.info("Frequency range: \(String(format: "%.1f", minFreq))Hz - \(String(format: "%.1f", maxFreq))Hz, avg confidence: \(String(format: "%.2f", avgConfidence))")
        }

        return PitchAnalysisData(
            timeStamps: timeStamps,
            frequencies: frequencies,
            confidences: confidences,
            targetNotes: targetNotes
        )
    }

    /// YIN algorithm for pitch detection
    /// Based on: "YIN, a fundamental frequency estimator for speech and music" (de Cheveigné & Kawahara, 2002)
    private func detectPitchUsingYIN(_ samples: [Float]) -> (frequency: Float, confidence: Float)? {
        let bufferSize = samples.count

        // Calculate RMS amplitude
        let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))

        // Silence threshold - very low to catch quiet vocals
        guard rms > 0.0001 else {
            return nil
        }

        // Step 1: Calculate difference function
        var difference = [Float](repeating: 0, count: bufferSize / 2)
        for tau in 0..<(bufferSize / 2) {
            var sum: Float = 0
            for i in 0..<(bufferSize / 2) {
                let delta = samples[i] - samples[i + tau]
                sum += delta * delta
            }
            difference[tau] = sum
        }

        // Step 2: Calculate cumulative mean normalized difference function
        var cmndf = [Float](repeating: 0, count: bufferSize / 2)
        cmndf[0] = 1.0

        var runningSum: Float = 0
        for tau in 1..<(bufferSize / 2) {
            runningSum += difference[tau]
            if runningSum > 0 {
                cmndf[tau] = difference[tau] / (runningSum / Float(tau))
            } else {
                cmndf[tau] = 1.0
            }
        }

        // Step 3: Absolute threshold
        let tauMin = Int(sampleRate / Double(maxFreq))  // Minimum period
        let tauMax = Int(sampleRate / Double(minFreq))  // Maximum period

        guard tauMin < tauMax && tauMax < cmndf.count else {
            return nil
        }

        // Find first tau where CMNDF drops below threshold
        var tau = tauMin
        while tau < tauMax {
            if cmndf[tau] < yinThreshold {
                // Found a candidate, look for local minimum
                while tau + 1 < tauMax && cmndf[tau + 1] < cmndf[tau] {
                    tau += 1
                }
                break
            }
            tau += 1
        }

        // No pitch found
        guard tau < tauMax && cmndf[tau] < yinThreshold else {
            return nil
        }

        // Step 4: Parabolic interpolation for better precision
        var betterTau = Float(tau)
        if tau > 0 && tau < cmndf.count - 1 {
            let s0 = cmndf[tau - 1]
            let s1 = cmndf[tau]
            let s2 = cmndf[tau + 1]
            let adjustment = (s2 - s0) / (2 * (2 * s1 - s2 - s0))
            betterTau = Float(tau) + adjustment
        }

        // Convert period to frequency
        let frequency = Float(sampleRate) / betterTau

        // Confidence is inverse of CMNDF value (lower CMNDF = higher confidence)
        let confidence = 1.0 - min(cmndf[tau], 1.0)

        // Validate frequency range
        guard frequency >= Float(minFreq) && frequency <= Float(maxFreq) else {
            return nil
        }

        return (frequency, confidence)
    }

    // MARK: - Spectrogram Analysis

    private func analyzeSpectrogram(samples: [Float], duration: Double, progress: @escaping @MainActor (Double) async -> Void) async throws -> SpectrogramData {
        var timeStamps: [Double] = []
        var magnitudesArray: [[Float]] = []

        let hopSamples = Int(sampleRate * spectrogramSamplingInterval)
        var position = 0
        let totalSamples = samples.count
        var lastReportedProgress: Double = 0.0

        // Define frequency bins
        let binSize = spectrogramMaxFreq / Double(spectrogramFreqBins)
        let frequencyBins = (0..<spectrogramFreqBins).map { Float($0) * Float(binSize) + Float(binSize / 2) }

        while position + spectrogramBufferSize <= samples.count {
            let timestamp = Double(position) / sampleRate
            let chunk = Array(samples[position..<(position + spectrogramBufferSize)])

            if let (magnitudes, freqBinSize) = performFFT(samples: chunk) {
                // Group magnitudes into frequency bins
                var binMagnitudes = [Float](repeating: 0, count: spectrogramFreqBins)

                for i in 0..<spectrogramFreqBins {
                    let startFreq = Double(i) * binSize
                    let endFreq = Double(i + 1) * binSize
                    let startBin = Int(startFreq / freqBinSize)
                    let endBin = Int(endFreq / freqBinSize)

                    if endBin <= magnitudes.count {
                        let binSlice = magnitudes[startBin..<endBin]
                        binMagnitudes[i] = binSlice.max() ?? 0.0
                    }
                }

                timeStamps.append(timestamp)
                magnitudesArray.append(binMagnitudes)
            }

            position += hopSamples

            // Report progress every 10% to avoid UI update overhead
            let currentProgress = Double(position) / Double(totalSamples)
            if currentProgress - lastReportedProgress >= 0.1 {
                await progress(currentProgress)
                lastReportedProgress = currentProgress
            }
        }

        // Report final progress
        await progress(1.0)

        logger.info("Spectrogram analysis: \(timeStamps.count) time frames, \(self.spectrogramFreqBins) frequency bins")

        return SpectrogramData(
            timeStamps: timeStamps,
            frequencyBins: frequencyBins,
            magnitudes: magnitudesArray
        )
    }

    // MARK: - FFT Utilities

    private func performFFT(samples: [Float]) -> (magnitudes: [Float], freqBinSize: Double)? {
        let bufferSize = samples.count

        guard let fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(bufferSize), vDSP_DFT_Direction.FORWARD) else {
            return nil
        }

        defer {
            vDSP_DFT_DestroySetup(fftSetup)
        }

        var realPartIn = [Float](repeating: 0, count: bufferSize)
        var imagPartIn = [Float](repeating: 0, count: bufferSize)
        var realPartOut = [Float](repeating: 0, count: bufferSize)
        var imagPartOut = [Float](repeating: 0, count: bufferSize)

        // Apply Hanning window
        var window = [Float](repeating: 0, count: bufferSize)
        vDSP_hann_window(&window, vDSP_Length(bufferSize), Int32(vDSP_HANN_NORM))

        var windowedSamples = [Float](repeating: 0, count: bufferSize)
        vDSP_vmul(samples, 1, window, 1, &windowedSamples, 1, vDSP_Length(bufferSize))

        realPartIn = windowedSamples

        // Perform FFT
        vDSP_DFT_Execute(fftSetup, &realPartIn, &imagPartIn, &realPartOut, &imagPartOut)

        // Calculate magnitude spectrum
        var magnitudes = [Float](repeating: 0, count: bufferSize / 2)
        realPartOut.withUnsafeMutableBufferPointer { realPtr in
            imagPartOut.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                vDSP_zvabs(&splitComplex, 1, &magnitudes, 1, vDSP_Length(bufferSize / 2))
            }
        }

        let freqBinSize = sampleRate / Double(bufferSize)

        return (magnitudes, freqBinSize)
    }
}

// MARK: - Errors

enum AnalysisError: Error, LocalizedError {
    case bufferAllocationFailed
    case noChannelData
    case fftSetupFailed

    var errorDescription: String? {
        switch self {
        case .bufferAllocationFailed:
            return "Failed to allocate audio buffer"
        case .noChannelData:
            return "No channel data available in audio buffer"
        case .fftSetupFailed:
            return "Failed to create FFT setup"
        }
    }
}
