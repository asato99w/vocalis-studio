//
//  SpectrumAnalyzer.swift
//  PoC
//
//  FFT-based spectrum analyzer
//

import Foundation
import AVFoundation
import Accelerate

/// Represents spectrum data at a specific time
struct SpectrumData {
    let timestamp: TimeInterval
    let frequencies: [Float]        // Frequency bins (Hz)
    let magnitudes: [Float]         // Magnitude for each frequency
    let sampleRate: Double

    /// Get the dominant frequency (peak)
    var dominantFrequency: Float? {
        guard let maxIndex = magnitudes.enumerated().max(by: { $0.element < $1.element })?.offset else {
            return nil
        }
        return frequencies[maxIndex]
    }
}

/// FFT-based spectrum analyzer
class SpectrumAnalyzer {

    private let fftSize: Int = 2048
    private let hopSize: Int = 1024
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

    /// Analyze audio file and extract spectrum data over time
    func analyze(audioFile: URL) async throws -> [SpectrumData] {
        print("Starting spectrum analysis for: \(audioFile.lastPathComponent)")

        let file = try AVAudioFile(forReading: audioFile)
        let format = file.processingFormat
        let sampleRate = format.sampleRate

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else {
            throw NSError(domain: "SpectrumAnalyzer", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create audio buffer"
            ])
        }

        try file.read(into: buffer)

        guard let floatChannelData = buffer.floatChannelData else {
            throw NSError(domain: "SpectrumAnalyzer", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "Failed to get float channel data"
            ])
        }

        let samples = Array(UnsafeBufferPointer(
            start: floatChannelData[0],
            count: Int(buffer.frameLength)
        ))

        print("Loaded \(samples.count) samples at \(sampleRate) Hz")

        return analyzeBuffer(samples: samples, sampleRate: sampleRate)
    }

    /// Analyze buffer and extract spectrum at each time window
    private func analyzeBuffer(samples: [Float], sampleRate: Double) -> [SpectrumData] {
        var spectrumData: [SpectrumData] = []

        let windowCount = (samples.count - fftSize) / hopSize + 1
        print("Analyzing \(windowCount) spectrum windows...")

        // Pre-calculate frequency bins
        let nyquist = Float(sampleRate / 2.0)
        let binCount = fftSize / 2
        let frequencies = (0..<binCount).map { Float($0) * nyquist / Float(binCount) }

        for windowIndex in 0..<windowCount {
            if windowIndex % 50 == 0 {
                print("Spectrum progress: \(windowIndex)/\(windowCount) windows...")
            }

            let startIndex = windowIndex * hopSize
            let endIndex = min(startIndex + fftSize, samples.count)

            guard endIndex - startIndex == fftSize else { continue }

            let windowSamples = Array(samples[startIndex..<endIndex])
            let timestamp = Double(startIndex) / sampleRate

            if let magnitudes = performFFT(samples: windowSamples) {
                spectrumData.append(SpectrumData(
                    timestamp: timestamp,
                    frequencies: frequencies,
                    magnitudes: magnitudes,
                    sampleRate: sampleRate
                ))
            }
        }

        print("Extracted \(spectrumData.count) spectrum frames")
        return spectrumData
    }

    /// Perform FFT on a single window
    private func performFFT(samples: [Float]) -> [Float]? {
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

        // Convert to dB scale
        var dBMagnitudes = [Float](repeating: 0, count: halfSize)
        var one: Float = 1.0
        vDSP_vdbcon(magnitudes, 1, &one, &dBMagnitudes, 1, vDSP_Length(halfSize), 1)

        // Normalize to 0-1 range (assuming -100dB to 0dB range)
        var normalized = dBMagnitudes.map { max(0, ($0 + 100) / 100) }

        return normalized
    }

    /// Get spectrum at a specific timestamp (nearest frame)
    func getSpectrum(at timestamp: TimeInterval, from spectrumData: [SpectrumData]) -> SpectrumData? {
        return spectrumData.min(by: { abs($0.timestamp - timestamp) < abs($1.timestamp - timestamp) })
    }
}
