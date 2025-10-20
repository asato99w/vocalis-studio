import XCTest
import AVFoundation
import VocalisDomain
@testable import VocalisStudio

/// Simple test to verify basic infrastructure works
final class SimpleBaselineTest: XCTestCase {

    func testSingleNoteDetection() async throws {
        // Initialize detector on MainActor
        let pitchDetector = await MainActor.run {
            return RealtimePitchDetector()
        }

        // Test C4 (261.63 Hz)
        let note = try MIDINote(60)
        let expectedFreq = note.frequency

        print("Testing C4: expected frequency = \(expectedFreq) Hz")

        // Generate simple sine wave audio
        let fileURL = try createTestAudioFile(duration: 1.0, frequency: expectedFreq)
        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        // Analyze pitch with longer timeout
        let expectation = expectation(description: "Analyze C4")
        var detectedPitch: DetectedPitch?

        await MainActor.run {
            pitchDetector.analyzePitchFromFile(fileURL, atTime: 0.1) { pitch in  // Changed from 0.5 to 0.1
                detectedPitch = pitch
                expectation.fulfill()
            }
        }

        await fulfillment(of: [expectation], timeout: 10.0) // Increased timeout

        // Verify detection
        XCTAssertNotNil(detectedPitch, "Failed to detect pitch from generated audio")

        if let detected = detectedPitch {
            let errorCents = abs(1200.0 * log2(detected.frequency / expectedFreq))
            print("✅ Detection successful:")
            print("   Expected: \(String(format: "%.2f", expectedFreq)) Hz")
            print("   Detected: \(String(format: "%.2f", detected.frequency)) Hz")
            print("   Error: \(String(format: "%.1f", errorCents)) cents")
            print("   Confidence: \(String(format: "%.3f", detected.confidence))")

            // Verify accuracy (within 50 cents = half semitone)
            XCTAssertLessThan(errorCents, 50.0, "Pitch detection error exceeds 50 cents")

            // Verify confidence (should be high for synthetic audio with harmonics)
            XCTAssertGreaterThan(detected.confidence, 0.5, "Confidence too low")
        }
    }

    private func createTestAudioFile(duration: TimeInterval, frequency: Double) throws -> URL {
        let sampleRate = 44100.0
        let frameCount = AVAudioFrameCount(duration * sampleRate)

        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        )!

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameCount
        ) else {
            throw NSError(domain: "Test", code: -1)
        }

        buffer.frameLength = frameCount

        // Generate sine wave with harmonics (to simulate real voice)
        guard let floatChannelData = buffer.floatChannelData else {
            throw NSError(domain: "Test", code: -2)
        }

        let samples = floatChannelData[0]
        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            // Fundamental + harmonics (similar to a real voice)
            let fundamental = sin(2.0 * .pi * frequency * time)
            let harmonic2 = 0.5 * sin(2.0 * .pi * frequency * 2.0 * time)
            let harmonic3 = 0.25 * sin(2.0 * .pi * frequency * 3.0 * time)
            let harmonic4 = 0.125 * sin(2.0 * .pi * frequency * 4.0 * time)
            let value = Float(fundamental + harmonic2 + harmonic3 + harmonic4)
            samples[frame] = value * 0.3  // Reduce amplitude to avoid clipping
        }

        // Write to file (using float PCM format to match buffer)
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test_simple_\(UUID().uuidString).wav")

        let audioFile = try AVAudioFile(
            forWriting: fileURL,
            settings: [
                AVFormatIDKey: Int(kAudioFormatLinearPCM) as Any,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,  // Use float format
                AVLinearPCMIsBigEndianKey: false
            ]
        )

        try audioFile.write(from: buffer)

        return fileURL
    }
}
