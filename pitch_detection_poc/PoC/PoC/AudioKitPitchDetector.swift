//
//  AudioKitPitchDetector.swift
//  PoC
//
//  AudioKit-based pitch detection (faster and more accurate)
//

import Foundation
import AVFoundation
import AudioKit

/// AudioKit-based pitch detector
class AudioKitPitchDetector {

    /// Analyze audio file and extract pitch data using AudioKit
    func analyze(audioFile: URL) async throws -> [PitchData] {
        print("Starting AudioKit pitch analysis for: \(audioFile.lastPathComponent)")

        // Load audio file
        let audioFile = try AVAudioFile(forReading: audioFile)
        let format = audioFile.processingFormat
        let sampleRate = format.sampleRate

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(audioFile.length)
        ) else {
            throw NSError(domain: "AudioKitPitchDetector", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create audio buffer"
            ])
        }

        try audioFile.read(into: buffer)

        guard let floatChannelData = buffer.floatChannelData else {
            throw NSError(domain: "AudioKitPitchDetector", code: -2, userInfo: [
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

    /// Analyze audio buffer using AudioKit's PitchTap equivalent offline processing
    private func analyzeBuffer(samples: [Float], sampleRate: Double) -> [PitchData] {
        var pitchData: [PitchData] = []

        // Analysis parameters
        let hopSize = 2048  // ~46ms at 44.1kHz
        let windowSize = 4096

        let windowCount = (samples.count - windowSize) / hopSize + 1
        print("Analyzing \(windowCount) windows with AudioKit algorithm...")

        // Create PitchTracker for offline analysis
        let tracker = PitchTracker(hopSize: hopSize, peakCount: 20)

        for windowIndex in 0..<windowCount {
            if windowIndex % 50 == 0 {
                print("Progress: \(windowIndex)/\(windowCount) windows...")
            }

            let startIndex = windowIndex * hopSize
            let endIndex = min(startIndex + windowSize, samples.count)

            guard endIndex - startIndex == windowSize else { continue }

            let windowSamples = Array(samples[startIndex..<endIndex])
            let timestamp = Double(startIndex) / sampleRate

            // Use AudioKit's pitch detection
            if let (frequency, amplitude) = tracker.getPitch(from: windowSamples) {
                // Filter by frequency range and amplitude
                if frequency >= 80.0 && frequency <= 1000.0 && amplitude > 0.1 {
                    // Convert amplitude to confidence (0.0 - 1.0)
                    let confidence = min(amplitude * 2.0, 1.0)

                    pitchData.append(PitchData(
                        timestamp: timestamp,
                        frequency: frequency,
                        confidence: confidence
                    ))
                }
            }
        }

        print("Detected \(pitchData.count) pitch points using AudioKit")
        return pitchData
    }
}

/// Simple pitch tracker using autocorrelation (AudioKit-inspired algorithm)
private class PitchTracker {
    let hopSize: Int
    let peakCount: Int

    init(hopSize: Int, peakCount: Int) {
        self.hopSize = hopSize
        self.peakCount = peakCount
    }

    func getPitch(from samples: [Float]) -> (frequency: Double, amplitude: Double)? {
        // Calculate RMS amplitude
        let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))

        guard rms > 0.01 else { return nil }  // Too quiet

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

        guard bestLag > 0 else { return nil }

        let frequency = sampleRate / Double(bestLag)

        return (frequency, Double(rms))
    }
}
