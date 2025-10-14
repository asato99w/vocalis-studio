//
//  PitchDetector.swift
//  PoC
//
//  Pitch detection using Accelerate framework (FFT)
//

import Foundation
import AVFoundation
import Accelerate

/// Represents a single pitch detection result
struct PitchData {
    let timestamp: TimeInterval  // Time position in audio (seconds)
    let frequency: Double        // Detected frequency in Hz
    let confidence: Double       // Confidence level 0.0-1.0

    /// Convert frequency to MIDI note number
    var midiNote: Double {
        guard frequency > 0 else { return 0 }
        return 69 + 12 * log2(frequency / 440.0)
    }

    /// Get note name (e.g., "C4", "A4")
    var noteName: String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let midi = Int(round(midiNote))
        let noteIndex = midi % 12
        let octave = (midi / 12) - 1
        return "\(noteNames[noteIndex])\(octave)"
    }
}

/// Pitch detector using FFT analysis
class PitchDetector {

    // FFT configuration
    private let fftSize: Int = 2048  // Reduced for faster processing
    private let hopSize: Int = 4410  // ~100ms intervals (10 points per second)
    private let sampleRate: Double = 44100.0

    // Pitch detection range (human voice: ~80Hz - 1000Hz)
    private let minFrequency: Double = 80.0
    private let maxFrequency: Double = 1000.0

    // FFT setup
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

    /// Analyze audio file and extract pitch data
    func analyze(audioFile: URL) async throws -> [PitchData] {
        print("Starting pitch analysis for: \(audioFile.lastPathComponent)")

        let file = try AVAudioFile(forReading: audioFile)
        let format = file.processingFormat
        let sampleRate = format.sampleRate

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else {
            throw NSError(domain: "PitchDetector", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create audio buffer"
            ])
        }

        try file.read(into: buffer)

        guard let floatChannelData = buffer.floatChannelData else {
            throw NSError(domain: "PitchDetector", code: -2, userInfo: [
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

    /// Analyze audio buffer and detect pitch at each time window
    private func analyzeBuffer(samples: [Float], sampleRate: Double) -> [PitchData] {
        var pitchData: [PitchData] = []

        let windowCount = (samples.count - fftSize) / hopSize + 1
        print("Analyzing \(windowCount) windows...")

        for windowIndex in 0..<windowCount {
            // Progress logging every 50 windows
            if windowIndex % 50 == 0 {
                print("Progress: \(windowIndex)/\(windowCount) windows...")
            }

            let startIndex = windowIndex * hopSize
            let endIndex = min(startIndex + fftSize, samples.count)

            guard endIndex - startIndex == fftSize else { continue }

            let windowSamples = Array(samples[startIndex..<endIndex])
            let timestamp = Double(startIndex) / sampleRate

            if let (frequency, confidence) = detectPitch(
                samples: windowSamples,
                sampleRate: sampleRate
            ) {
                // Filter by frequency range and confidence
                if frequency >= minFrequency && frequency <= maxFrequency && confidence > 0.3 {
                    pitchData.append(PitchData(
                        timestamp: timestamp,
                        frequency: frequency,
                        confidence: confidence
                    ))
                }
            }
        }

        print("Detected \(pitchData.count) pitch points")
        return pitchData
    }

    /// Detect pitch in a single window using autocorrelation method (optimized)
    private func detectPitch(samples: [Float], sampleRate: Double) -> (frequency: Double, confidence: Double)? {
        guard samples.count == fftSize else { return nil }

        // Apply Hamming window to reduce spectral leakage
        var windowedSamples = [Float](repeating: 0, count: fftSize)
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hamm_window(&window, vDSP_Length(fftSize), 0)
        vDSP_vmul(samples, 1, window, 1, &windowedSamples, 1, vDSP_Length(fftSize))

        // Calculate only the necessary range for autocorrelation
        let minLag = Int(sampleRate / maxFrequency)
        let maxLag = min(Int(sampleRate / minFrequency), fftSize / 2)

        guard minLag < maxLag else { return nil }

        // Autocorrelation for lag=0 (energy)
        var energy: Float = 0
        vDSP_svesq(windowedSamples, 1, &energy, vDSP_Length(fftSize))

        guard energy > 0 else { return nil }

        // Autocorrelation for limited range using manual calculation (simpler approach)
        var autocorrelation = [Float](repeating: 0, count: maxLag - minLag + 1)

        for (index, lag) in (minLag...maxLag).enumerated() {
            var sum: Float = 0
            for i in 0..<(fftSize - lag) {
                sum += windowedSamples[i] * windowedSamples[i + lag]
            }
            autocorrelation[index] = sum
        }

        // Find the peak in autocorrelation
        var maxValue: Float = 0
        var maxIndex: vDSP_Length = 0
        vDSP_maxvi(autocorrelation, 1, &maxValue, &maxIndex, vDSP_Length(autocorrelation.count))

        let peakLag = minLag + Int(maxIndex)

        // Calculate confidence based on peak strength
        let confidence = min(maxValue / energy, 1.0)

        guard confidence > 0.1 else { return nil }

        // Parabolic interpolation for better accuracy
        let y1 = maxIndex > 0 ? autocorrelation[Int(maxIndex) - 1] : maxValue
        let y2 = maxValue
        let y3 = maxIndex < autocorrelation.count - 1 ? autocorrelation[Int(maxIndex) + 1] : maxValue

        let interpolatedLag = parabolicInterpolation(
            y1: y1,
            y2: y2,
            y3: y3,
            peakIndex: peakLag
        )

        let frequency = sampleRate / Double(interpolatedLag)

        return (frequency, Double(confidence))
    }

    /// Parabolic interpolation for sub-sample peak estimation
    private func parabolicInterpolation(y1: Float, y2: Float, y3: Float, peakIndex: Int) -> Double {
        let numerator = Double(y1 - y3)
        let denominator = Double(2 * (2 * y2 - y1 - y3))

        guard abs(denominator) > 0.0001 else {
            return Double(peakIndex)
        }

        let offset = numerator / denominator
        return Double(peakIndex) + offset
    }
}
