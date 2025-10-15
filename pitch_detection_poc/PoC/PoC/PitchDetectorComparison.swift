//
//  PitchDetectorComparison.swift
//  PoC
//
//  Compare different pitch detection algorithms
//

import Foundation
import AVFoundation
import Accelerate

// MARK: - Pitch Detection Methods

enum PitchDetectionMethod: String, CaseIterable {
    case fft = "FFT-based"
    case autocorrelation = "Autocorrelation"
    case yin = "YIN Algorithm"
    case cepstrum = "Cepstrum Analysis"

    var description: String {
        switch self {
        case .fft:
            return "Frequency domain analysis using Fast Fourier Transform"
        case .autocorrelation:
            return "Time domain analysis using autocorrelation function"
        case .yin:
            return "YIN algorithm - improved autocorrelation method"
        case .cepstrum:
            return "Cepstral analysis - FFT of log magnitude spectrum"
        }
    }
}

// MARK: - Comparison Result

struct PitchComparisonResult {
    let method: PitchDetectionMethod
    let pitchData: [PitchData]
    let processingTime: TimeInterval
    let averageConfidence: Double
    let detectionRate: Double  // Percentage of windows with detected pitch

    var summary: String {
        """
        Method: \(method.rawValue)
        Processing Time: \(String(format: "%.2f", processingTime))s
        Detection Rate: \(String(format: "%.1f", detectionRate * 100))%
        Avg Confidence: \(String(format: "%.2f", averageConfidence))
        Detected Points: \(pitchData.count)
        """
    }
}

// MARK: - Multi-Method Pitch Detector

class MultiMethodPitchDetector {

    private let fftSize: Int = 2048
    private let hopSize: Int = 4410  // ~100ms intervals
    private let sampleRate: Double = 44100.0
    private let minFrequency: Double = 80.0
    private let maxFrequency: Double = 1000.0

    private var fftSetup: FFTSetup?
    private let log2n: vDSP_Length

    init() {
        self.log2n = vDSP_Length(log2(Double(fftSize)))
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
    }

    deinit {
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }

    /// Compare all pitch detection methods
    func compareAll(audioFile: URL) async throws -> [PitchComparisonResult] {
        print("\n=== Starting Multi-Method Pitch Detection Comparison ===\n")

        // Load audio once
        let (samples, sampleRate) = try loadAudioFile(audioFile)

        var results: [PitchComparisonResult] = []

        // Test each method
        for method in PitchDetectionMethod.allCases {
            print("Testing \(method.rawValue)...")
            let result = try await analyzeWithMethod(
                method: method,
                samples: samples,
                sampleRate: sampleRate
            )
            results.append(result)
            print(result.summary)
            print()
        }

        print("=== Comparison Complete ===\n")
        return results
    }

    /// Analyze with specific method
    private func analyzeWithMethod(
        method: PitchDetectionMethod,
        samples: [Float],
        sampleRate: Double
    ) async throws -> PitchComparisonResult {
        let startTime = Date()

        var pitchData: [PitchData] = []
        let windowCount = (samples.count - fftSize) / hopSize + 1
        var totalWindows = 0

        for windowIndex in 0..<windowCount {
            let startIndex = windowIndex * hopSize
            let endIndex = min(startIndex + fftSize, samples.count)

            guard endIndex - startIndex == fftSize else { continue }

            let windowSamples = Array(samples[startIndex..<endIndex])
            let timestamp = Double(startIndex) / sampleRate
            totalWindows += 1

            // Detect pitch using selected method
            if let (frequency, confidence) = detectPitchWithMethod(
                method: method,
                samples: windowSamples,
                sampleRate: sampleRate
            ) {
                if frequency >= minFrequency && frequency <= maxFrequency && confidence > 0.3 {
                    pitchData.append(PitchData(
                        timestamp: timestamp,
                        frequency: frequency,
                        confidence: confidence
                    ))
                }
            }
        }

        let processingTime = Date().timeIntervalSince(startTime)
        let averageConfidence = pitchData.isEmpty ? 0 : pitchData.reduce(0) { $0 + $1.confidence } / Double(pitchData.count)
        let detectionRate = Double(pitchData.count) / Double(totalWindows)

        return PitchComparisonResult(
            method: method,
            pitchData: pitchData,
            processingTime: processingTime,
            averageConfidence: averageConfidence,
            detectionRate: detectionRate
        )
    }

    /// Detect pitch using specified method
    private func detectPitchWithMethod(
        method: PitchDetectionMethod,
        samples: [Float],
        sampleRate: Double
    ) -> (frequency: Double, confidence: Double)? {
        switch method {
        case .fft:
            return detectPitchFFT(samples: samples, sampleRate: sampleRate)
        case .autocorrelation:
            return detectPitchAutocorrelation(samples: samples, sampleRate: sampleRate)
        case .yin:
            return detectPitchYIN(samples: samples, sampleRate: sampleRate)
        case .cepstrum:
            return detectPitchCepstrum(samples: samples, sampleRate: sampleRate)
        }
    }

    // MARK: - Method 1: FFT-based Detection

    private func detectPitchFFT(samples: [Float], sampleRate: Double) -> (frequency: Double, confidence: Double)? {
        guard samples.count == fftSize else { return nil }
        guard let fftSetup = fftSetup else { return nil }

        // Apply Hamming window
        var windowedSamples = [Float](repeating: 0, count: fftSize)
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hamm_window(&window, vDSP_Length(fftSize), 0)
        vDSP_vmul(samples, 1, window, 1, &windowedSamples, 1, vDSP_Length(fftSize))

        // Setup split complex buffer
        let halfSize = fftSize / 2
        var realp = [Float](repeating: 0, count: halfSize)
        var imagp = [Float](repeating: 0, count: halfSize)

        // Convert to split complex format
        windowedSamples.withUnsafeBytes { ptr in
            let complexPtr = ptr.bindMemory(to: DSPComplex.self)
            var splitComplex = DSPSplitComplex(realp: &realp, imagp: &imagp)
            vDSP_ctoz(complexPtr.baseAddress!, 2, &splitComplex, 1, vDSP_Length(halfSize))
        }

        // Perform FFT
        var splitComplex = DSPSplitComplex(realp: &realp, imagp: &imagp)
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))

        // Calculate magnitude spectrum
        var magnitudes = [Float](repeating: 0, count: halfSize)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfSize))

        // Find peak in valid frequency range
        let minBin = Int(minFrequency * Double(fftSize) / sampleRate)
        let maxBin = Int(maxFrequency * Double(fftSize) / sampleRate)

        guard minBin < maxBin && maxBin < halfSize else { return nil }

        let validMagnitudes = Array(magnitudes[minBin...maxBin])
        var maxValue: Float = 0
        var maxIndex: vDSP_Length = 0
        vDSP_maxvi(validMagnitudes, 1, &maxValue, &maxIndex, vDSP_Length(validMagnitudes.count))

        let peakBin = minBin + Int(maxIndex)

        // Parabolic interpolation for better accuracy
        let y1 = peakBin > 0 ? magnitudes[peakBin - 1] : maxValue
        let y2 = maxValue
        let y3 = peakBin < halfSize - 1 ? magnitudes[peakBin + 1] : maxValue

        let delta = 0.5 * (y1 - y3) / (y1 - 2*y2 + y3)
        let interpolatedBin = Double(peakBin) + Double(delta)

        let frequency = interpolatedBin * sampleRate / Double(fftSize)

        // Calculate confidence based on peak prominence
        let avgMagnitude = magnitudes.reduce(0, +) / Float(magnitudes.count)
        let confidence = min(Double(maxValue / (avgMagnitude * 10)), 1.0)

        return (frequency, confidence)
    }

    // MARK: - Method 2: Autocorrelation

    private func detectPitchAutocorrelation(samples: [Float], sampleRate: Double) -> (frequency: Double, confidence: Double)? {
        guard samples.count == fftSize else { return nil }

        // Apply Hamming window
        var windowedSamples = [Float](repeating: 0, count: fftSize)
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hamm_window(&window, vDSP_Length(fftSize), 0)
        vDSP_vmul(samples, 1, window, 1, &windowedSamples, 1, vDSP_Length(fftSize))

        let minLag = Int(sampleRate / maxFrequency)
        let maxLag = min(Int(sampleRate / minFrequency), fftSize / 2)

        guard minLag < maxLag else { return nil }

        // Calculate energy
        var energy: Float = 0
        vDSP_svesq(windowedSamples, 1, &energy, vDSP_Length(fftSize))
        guard energy > 0 else { return nil }

        // Autocorrelation
        var autocorrelation = [Float](repeating: 0, count: maxLag - minLag + 1)
        for (index, lag) in (minLag...maxLag).enumerated() {
            var sum: Float = 0
            for i in 0..<(fftSize - lag) {
                sum += windowedSamples[i] * windowedSamples[i + lag]
            }
            autocorrelation[index] = sum
        }

        // Find peak
        var maxValue: Float = 0
        var maxIndex: vDSP_Length = 0
        vDSP_maxvi(autocorrelation, 1, &maxValue, &maxIndex, vDSP_Length(autocorrelation.count))

        let peakLag = minLag + Int(maxIndex)
        let confidence = min(maxValue / energy, 1.0)

        guard confidence > 0.1 else { return nil }

        let frequency = sampleRate / Double(peakLag)

        return (frequency, Double(confidence))
    }

    // MARK: - Method 3: YIN Algorithm

    private func detectPitchYIN(samples: [Float], sampleRate: Double) -> (frequency: Double, confidence: Double)? {
        guard samples.count == fftSize else { return nil }

        let minLag = Int(sampleRate / maxFrequency)
        let maxLag = min(Int(sampleRate / minFrequency), fftSize / 2)

        guard minLag < maxLag else { return nil }

        // Step 1: Difference function
        var difference = [Float](repeating: 0, count: maxLag)
        for lag in 0..<maxLag {
            var sum: Float = 0
            for i in 0..<(fftSize - lag) {
                let delta = samples[i] - samples[i + lag]
                sum += delta * delta
            }
            difference[lag] = sum
        }

        // Step 2: Cumulative mean normalized difference
        var cmndf = [Float](repeating: 1, count: maxLag)
        cmndf[0] = 1

        var runningSum: Float = 0
        for lag in 1..<maxLag {
            runningSum += difference[lag]
            cmndf[lag] = difference[lag] / (runningSum / Float(lag))
        }

        // Step 3: Absolute threshold
        let threshold: Float = 0.1
        var bestLag = minLag

        for lag in minLag..<maxLag {
            if cmndf[lag] < threshold {
                // Find local minimum
                while lag + 1 < maxLag && cmndf[lag + 1] < cmndf[lag] {
                    bestLag = lag + 1
                }
                break
            }
        }

        guard bestLag > minLag else { return nil }

        // Step 4: Parabolic interpolation
        let y1 = bestLag > 0 ? cmndf[bestLag - 1] : cmndf[bestLag]
        let y2 = cmndf[bestLag]
        let y3 = bestLag < maxLag - 1 ? cmndf[bestLag + 1] : cmndf[bestLag]

        let delta = (y1 - y3) / (2 * (y1 - 2*y2 + y3))
        let interpolatedLag = Float(bestLag) + delta

        let frequency = sampleRate / Double(interpolatedLag)
        let confidence = 1.0 - Double(y2)  // YIN uses lower values for better matches

        return (frequency, confidence)
    }

    // MARK: - Method 4: Cepstrum Analysis

    private func detectPitchCepstrum(samples: [Float], sampleRate: Double) -> (frequency: Double, confidence: Double)? {
        guard samples.count == fftSize else { return nil }
        guard let fftSetup = fftSetup else { return nil }

        // Apply Hamming window
        var windowedSamples = [Float](repeating: 0, count: fftSize)
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hamm_window(&window, vDSP_Length(fftSize), 0)
        vDSP_vmul(samples, 1, window, 1, &windowedSamples, 1, vDSP_Length(fftSize))

        // First FFT
        let halfSize = fftSize / 2
        var realp = [Float](repeating: 0, count: halfSize)
        var imagp = [Float](repeating: 0, count: halfSize)

        windowedSamples.withUnsafeBytes { ptr in
            let complexPtr = ptr.bindMemory(to: DSPComplex.self)
            var splitComplex = DSPSplitComplex(realp: &realp, imagp: &imagp)
            vDSP_ctoz(complexPtr.baseAddress!, 2, &splitComplex, 1, vDSP_Length(halfSize))
        }

        var splitComplex = DSPSplitComplex(realp: &realp, imagp: &imagp)
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))

        // Log magnitude
        var magnitudes = [Float](repeating: 0, count: halfSize)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfSize))

        // Add small epsilon to avoid log(0)
        var epsilon: Float = 1e-10
        vDSP_vsadd(magnitudes, 1, &epsilon, &magnitudes, 1, vDSP_Length(halfSize))

        // Take log
        var logMagnitudes = [Float](repeating: 0, count: halfSize)
        var count = Int32(halfSize)
        vvlogf(&logMagnitudes, magnitudes, &count)

        // Inverse FFT (cepstrum)
        // Prepare for inverse FFT
        for i in 0..<halfSize {
            realp[i] = logMagnitudes[i]
            imagp[i] = 0
        }

        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Inverse))

        // Get magnitude of cepstrum
        var cepstrum = [Float](repeating: 0, count: halfSize)
        vDSP_zvmags(&splitComplex, 1, &cepstrum, 1, vDSP_Length(halfSize))

        // Find peak in valid quefrency range (quefrency = 1/frequency)
        let minQuefrency = Int(sampleRate / maxFrequency)
        let maxQuefrency = Int(sampleRate / minFrequency)

        guard minQuefrency < maxQuefrency && maxQuefrency < halfSize else { return nil }

        let validCepstrum = Array(cepstrum[minQuefrency...maxQuefrency])
        var maxValue: Float = 0
        var maxIndex: vDSP_Length = 0
        vDSP_maxvi(validCepstrum, 1, &maxValue, &maxIndex, vDSP_Length(validCepstrum.count))

        let peakQuefrency = minQuefrency + Int(maxIndex)
        let frequency = sampleRate / Double(peakQuefrency)

        let avgCepstrum = cepstrum.reduce(0, +) / Float(cepstrum.count)
        let confidence = min(Double(maxValue / (avgCepstrum * 5)), 1.0)

        return (frequency, confidence)
    }

    // MARK: - Helper Methods

    private func loadAudioFile(_ url: URL) throws -> ([Float], Double) {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let sampleRate = format.sampleRate

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else {
            throw NSError(domain: "MultiMethodPitchDetector", code: -1, userInfo: nil)
        }

        try file.read(into: buffer)

        guard let floatChannelData = buffer.floatChannelData else {
            throw NSError(domain: "MultiMethodPitchDetector", code: -2, userInfo: nil)
        }

        let samples = Array(UnsafeBufferPointer(
            start: floatChannelData[0],
            count: Int(buffer.frameLength)
        ))

        return (samples, sampleRate)
    }
}
