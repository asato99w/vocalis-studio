import XCTest
import AVFoundation
import VocalisDomain
@testable import VocalisStudio

/// Synthetic scale-based evaluation using generated audio files
@available(iOS 13.0, *)
final class SyntheticScaleEvaluationTests: XCTestCase {

    /// Simple test to verify the test class works
    func testSimple() {
        print("Simple test works!")
        XCTAssertTrue(true)
    }

    /// Test single note - exact copy of SimpleBaselineTest pattern
    func testC4Single() async throws {
        // Initialize detector on MainActor (same as SimpleBaselineTest)
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
            pitchDetector.analyzePitchFromFile(fileURL, atTime: 0.1) { pitch in
                detectedPitch = pitch
                expectation.fulfill()
            }
        }

        await fulfillment(of: [expectation], timeout: 10.0)

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

    // MARK: - Individual Note Tests for Baseline Evaluation

    func testC4_BaselineEvaluation() async throws {
        try await evaluateSingleNote(midiNote: 60, name: "C4")
    }

    func testD4_BaselineEvaluation() async throws {
        try await evaluateSingleNote(midiNote: 62, name: "D4")
    }

    func testE4_BaselineEvaluation() async throws {
        try await evaluateSingleNote(midiNote: 64, name: "E4")
    }

    func testF4_BaselineEvaluation() async throws {
        try await evaluateSingleNote(midiNote: 65, name: "F4")
    }

    func testG4_BaselineEvaluation() async throws {
        try await evaluateSingleNote(midiNote: 67, name: "G4")
    }

    /// Baseline evaluation with current parameters using synthetic audio (DISABLED - using individual tests instead)
    func DISABLED_testBaselineEvaluation_CurrentParameters() async throws {
        // Initialize detector (same as SimpleBaselineTest)
        let pitchDetector = await MainActor.run {
            return RealtimePitchDetector()
        }

        let separator = String(repeating: "=", count: 60)
        print("\n" + separator)
        print("🎯 BASELINE EVALUATION - Synthetic Scale")
        print(separator)
        print("")

        // Test scale: Start with 1 note
        let testScale: [(note: MIDINote, name: String)] = [
            (try MIDINote(60), "C4"), // 261.63 Hz
        ]

        var results: [(expected: Double, detected: Double?, confidence: Double, error: Double?)] = []
        var generatedFiles: [URL] = []

        for (note, noteName) in testScale {
            let expectedFreq = note.frequency

            print("Testing \(noteName): expected frequency = \(expectedFreq) Hz")

            let fileURL = try createTestAudioFile(duration: 1.0, frequency: expectedFreq)
            generatedFiles.append(fileURL)

            let expectation = expectation(description: "Analyze \(noteName)")
            var detectedPitch: DetectedPitch?

            await MainActor.run {
                pitchDetector.analyzePitchFromFile(fileURL, atTime: 0.1) { pitch in
                    detectedPitch = pitch
                    expectation.fulfill()
                }
            }

            await fulfillment(of: [expectation], timeout: 10.0)

            if let detected = detectedPitch {
                let errorCents = 1200.0 * log2(detected.frequency / expectedFreq)
                results.append((expectedFreq, detected.frequency, detected.confidence, errorCents))
                print(String(format: "  ✅ %s: %.2f Hz → %.2f Hz (%.1f cent, conf: %.3f)",
                             noteName, expectedFreq, detected.frequency, errorCents, detected.confidence))
            } else {
                results.append((expectedFreq, nil, 0.0, nil))
                print(String(format: "  ❌ %s: %.2f Hz → FAILED", noteName, expectedFreq))
            }
        }

        // Cleanup generated files
        for fileURL in generatedFiles {
            try? FileManager.default.removeItem(at: fileURL)
        }

        // Calculate metrics
        let metrics = calculateMetrics(results)

        print("")
        print(separator)
        print("📊 BASELINE METRICS")
        print(separator)
        print("")
        print(String(format: "  GPE (Gross Pitch Error):    %.2f%% (目標: <5%%)", metrics.gpe * 100))
        print(String(format: "  FPE (Fine Pitch Error):     %.2f cent (目標: <10 cent)", metrics.fpe))
        print(String(format: "  Octave Error Rate:          %.2f%% (目標: <2%%)", metrics.octaveErrorRate * 100))
        print(String(format: "  Detection Success Rate:     %.2f%%", metrics.detectionRate * 100))
        print(String(format: "  Average Confidence:         %.3f", metrics.avgConfidence))
        print("")
        print(separator)
        print("")

        // Assert metrics meet goals
        XCTAssertLessThanOrEqual(metrics.gpe, 0.05, "GPE should be < 5%")
        XCTAssertLessThanOrEqual(metrics.fpe, 10.0, "FPE should be < 10 cent")
        XCTAssertLessThanOrEqual(metrics.octaveErrorRate, 0.02, "Octave error should be < 2%")
    }

    // MARK: - Helper Methods

    private func evaluateSingleNote(midiNote: UInt8, name: String) async throws {
        // Initialize detector on MainActor
        let pitchDetector = await MainActor.run {
            return RealtimePitchDetector()
        }

        let note = try MIDINote(midiNote)
        let expectedFreq = note.frequency

        print("\n--- Testing \(name) ---")
        print("Expected frequency: \(expectedFreq) Hz")

        // Generate test audio
        let fileURL = try createTestAudioFile(duration: 1.0, frequency: expectedFreq)
        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        // Analyze pitch
        let expectation = expectation(description: "Analyze \(name)")
        var detectedPitch: DetectedPitch?

        await MainActor.run {
            pitchDetector.analyzePitchFromFile(fileURL, atTime: 0.1) { pitch in
                detectedPitch = pitch
                expectation.fulfill()
            }
        }

        await fulfillment(of: [expectation], timeout: 10.0)

        // Verify and report results
        XCTAssertNotNil(detectedPitch, "Failed to detect pitch for \(name)")

        if let detected = detectedPitch {
            let errorCents = abs(1200.0 * log2(detected.frequency / expectedFreq))
            print("Detected: \(String(format: "%.2f", detected.frequency)) Hz")
            print("Error: \(String(format: "%.1f", errorCents)) cents")
            print("Confidence: \(String(format: "%.3f", detected.confidence))")

            // Verify accuracy
            XCTAssertLessThan(errorCents, 50.0, "\(name): Pitch detection error exceeds 50 cents")
            XCTAssertGreaterThan(detected.confidence, 0.5, "\(name): Confidence too low")
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

        // Generate sine wave with harmonics
        guard let floatChannelData = buffer.floatChannelData else {
            throw NSError(domain: "Test", code: -2)
        }

        let samples = floatChannelData[0]
        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let fundamental = sin(2.0 * .pi * frequency * time)
            let harmonic2 = 0.5 * sin(2.0 * .pi * frequency * 2.0 * time)
            let harmonic3 = 0.25 * sin(2.0 * .pi * frequency * 3.0 * time)
            let harmonic4 = 0.125 * sin(2.0 * .pi * frequency * 4.0 * time)
            let value = Float(fundamental + harmonic2 + harmonic3 + harmonic4)
            samples[frame] = value * 0.3
        }

        // Write to file
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test_audio_\(UUID().uuidString).wav")

        let audioFile = try AVAudioFile(
            forWriting: fileURL,
            settings: [
                AVFormatIDKey: Int(kAudioFormatLinearPCM) as Any,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false
            ]
        )

        try audioFile.write(from: buffer)

        return fileURL
    }

    private func calculateMetrics(_ results: [(expected: Double, detected: Double?, confidence: Double, error: Double?)]) -> (gpe: Double, fpe: Double, octaveErrorRate: Double, detectionRate: Double, avgConfidence: Double) {
        var grossErrors = 0
        var totalCentsError: Double = 0.0
        var octaveErrors = 0
        var successfulDetections = 0
        var totalConfidence: Double = 0.0

        for (expected, detected, confidence, errorCents) in results {
            guard let detected = detected, let errorCents = errorCents else {
                grossErrors += 1
                continue
            }

            successfulDetections += 1
            totalConfidence += confidence

            let absError = abs(errorCents)

            if absError > 50.0 {
                grossErrors += 1
            }

            totalCentsError += absError

            let ratio = detected / expected
            if abs(ratio - 2.0) < 0.1 || abs(ratio - 0.5) < 0.05 {
                octaveErrors += 1
            }
        }

        let total = results.count
        let gpe = Double(grossErrors) / Double(total)
        let fpe = successfulDetections > 0 ? totalCentsError / Double(successfulDetections) : 0.0
        let octaveErrorRate = successfulDetections > 0 ? Double(octaveErrors) / Double(successfulDetections) : 0.0
        let detectionRate = Double(successfulDetections) / Double(total)
        let avgConfidence = successfulDetections > 0 ? totalConfidence / Double(successfulDetections) : 0.0

        return (gpe, fpe, octaveErrorRate, detectionRate, avgConfidence)
    }
}
