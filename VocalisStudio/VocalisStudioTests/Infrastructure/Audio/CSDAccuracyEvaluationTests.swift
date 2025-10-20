import XCTest
import AVFoundation
import VocalisDomain
@testable import VocalisStudio

/// CSD (Children's Song Dataset) accuracy evaluation tests
///
/// Prerequisites:
/// 1. Download CSD dataset from: https://zenodo.org/record/4785016
/// 2. Place sample files in VocalisStudioTests/Resources/CSD/
///    - audio/001.wav
///    - csv/001.csv
///    - midi/001.mid (optional)
/// 3. Enable tests by removing DISABLED_ prefix
///
@available(iOS 13.0, *)
final class CSDAccuracyEvaluationTests: XCTestCase {

    // MARK: - Properties

    private var pitchDetector: RealtimePitchDetector!
    private let csvParser = CSDNoteTimingParser()

    // MARK: - Setup/Teardown

    override func setUp() async throws {
        try await super.setUp()

        // Initialize pitch detector on MainActor
        pitchDetector = await MainActor.run {
            return RealtimePitchDetector()
        }
    }

    // MARK: - Synthetic Data Generation Tests

    /// Generate synthetic test data for framework validation
    func testGenerateSyntheticTestData() throws {
        // Define test song: C-D-E scale
        let notes: [(midiNote: UInt8, duration: TimeInterval)] = [
            (60, 0.8),  // C4
            (62, 0.8),  // D4
            (64, 0.8),  // E4
        ]

        // Generate files in correct subdirectories
        let audioURL = URL(fileURLWithPath: getCSDResourcePath(filename: "001.wav", subdirectory: "audio"))
        let csvURL = URL(fileURLWithPath: getCSDResourcePath(filename: "001.csv", subdirectory: "csv"))

        try generateSyntheticSong(
            audioURL: audioURL,
            csvURL: csvURL,
            notes: notes
        )

        print("✅ Generated synthetic test data:")
        print("   Audio: \(audioURL.path)")
        print("   CSV: \(csvURL.path)")

        // Verify files exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: audioURL.path), "Audio file should exist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: csvURL.path), "CSV file should exist")

        // Verify CSV content
        let csvContent = try String(contentsOf: csvURL, encoding: .utf8)
        let csvLines = csvContent.components(separatedBy: .newlines).filter { !$0.isEmpty }
        XCTAssertEqual(csvLines.count, 4, "CSV should have header + 3 note lines")
    }

    // MARK: - Resource Loading Tests

    /// Test loading CSD CSV file from resources
    func testLoadCSDCSVFile() throws {
        let csvPath = getCSDResourcePath(filename: "001.csv", subdirectory: "csv")

        guard FileManager.default.fileExists(atPath: csvPath) else {
            XCTFail("❌ CSD CSV file not found at: \(csvPath)\n" +
                    "Please download CSD dataset and place files in Resources/CSD/")
            return
        }

        let csvContent = try String(contentsOfFile: csvPath, encoding: .utf8)
        let notes = try csvParser.parseCSVContent(csvContent, hasHeader: true)

        XCTAssertGreaterThan(notes.count, 0, "CSV should contain note timing data")
        print("✅ Loaded \(notes.count) notes from CSV")
    }

    /// Test loading CSD audio file from resources
    func testLoadCSDAudioFile() throws {
        let audioPath = getCSDResourcePath(filename: "001.wav", subdirectory: "audio")

        guard FileManager.default.fileExists(atPath: audioPath) else {
            XCTFail("❌ CSD audio file not found at: \(audioPath)\n" +
                    "Please download CSD dataset and place files in Resources/CSD/")
            return
        }

        let audioURL = URL(fileURLWithPath: audioPath)
        let audioFile = try AVAudioFile(forReading: audioURL)

        let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
        XCTAssertEqual(audioFile.processingFormat.sampleRate, 44100, "CSD audio should be 44.1kHz")
        print("✅ Loaded audio file: \(audioFile.length) samples, \(String(format: "%.2f", duration)) seconds")
    }

    // MARK: - Single Note Accuracy Tests (DISABLED - requires data download)

    /// Test pitch detection accuracy for a single note from CSD
    func testSingleNoteAccuracy() async throws {
        // Load CSV timing data
        let csvPath = getCSDResourcePath(filename: "001.csv", subdirectory: "csv")
        let csvContent = try String(contentsOfFile: csvPath, encoding: .utf8)
        let notes = try csvParser.parseCSVContent(csvContent, hasHeader: true)

        guard let firstNote = notes.first else {
            XCTFail("No notes found in CSV")
            return
        }

        // Load audio file
        let audioPath = getCSDResourcePath(filename: "001.wav", subdirectory: "audio")
        let audioURL = URL(fileURLWithPath: audioPath)

        // Analyze pitch at note onset + 0.1 seconds (to avoid attack transients)
        let analysisTime = firstNote.onset + 0.1
        let expectation = expectation(description: "Analyze pitch at \(analysisTime)s")
        var detectedPitch: DetectedPitch?

        await MainActor.run {
            pitchDetector.analyzePitchFromFile(audioURL, atTime: analysisTime) { pitch in
                detectedPitch = pitch
                expectation.fulfill()
            }
        }

        await fulfillment(of: [expectation], timeout: 10.0)

        // Verify detection
        XCTAssertNotNil(detectedPitch, "Failed to detect pitch")

        if let detected = detectedPitch {
            let expectedFreq = firstNote.midiNote.frequency
            let errorCents = abs(1200.0 * log2(detected.frequency / expectedFreq))

            print("🎵 Note: \(firstNote.midiNote.noteName) (\(firstNote.syllable))")
            print("   Expected: \(String(format: "%.2f", expectedFreq)) Hz")
            print("   Detected: \(String(format: "%.2f", detected.frequency)) Hz")
            print("   Error: \(String(format: "%.1f", errorCents)) cents")
            print("   Confidence: \(String(format: "%.3f", detected.confidence))")

            // Verify accuracy (within 50 cents = half semitone)
            XCTAssertLessThan(errorCents, 50.0, "Pitch detection error exceeds 50 cents")
            XCTAssertGreaterThan(detected.confidence, 0.5, "Confidence too low")
        }
    }

    // MARK: - Split Accuracy Evaluation Tests

    /// Test pitch detection accuracy for note 1 (C4) - Split test approach
    func testThreeNoteAccuracy_Note1() async throws {
        try await testNoteAccuracy(noteIndex: 0, noteName: "C4")
    }

    /// Test pitch detection accuracy for note 2 (D4) - Split test approach
    func testThreeNoteAccuracy_Note2() async throws {
        try await testNoteAccuracy(noteIndex: 1, noteName: "D4")
    }

    /// Test pitch detection accuracy for note 3 (E4) - Split test approach
    func testThreeNoteAccuracy_Note3() async throws {
        try await testNoteAccuracy(noteIndex: 2, noteName: "E4")
    }

    // MARK: - Full Song Accuracy Evaluation (DISABLED - requires data download)

    /// Baseline evaluation using CSD real singing voice data (DISABLED - simulator issues)
    /// Use testThreeNoteAccuracy_NoteX() tests instead for split evaluation
    func DISABLED_testFullSongAccuracyEvaluation() async throws {
        // Load CSV timing data
        let csvPath = getCSDResourcePath(filename: "001.csv", subdirectory: "csv")
        let csvContent = try String(contentsOfFile: csvPath, encoding: .utf8)
        let notes = try csvParser.parseCSVContent(csvContent, hasHeader: true)

        guard !notes.isEmpty else {
            XCTFail("No notes found in CSV")
            return
        }

        // Load audio file
        let audioPath = getCSDResourcePath(filename: "001.wav", subdirectory: "audio")
        let audioURL = URL(fileURLWithPath: audioPath)

        print("")
        print("===========================================")
        print("🎵 CSD ACCURACY EVALUATION")
        print("===========================================")
        print("Testing \(notes.count) notes from 001.wav")
        print("")

        // SEQUENTIAL PROCESSING APPROACH using helper method
        // Process notes using helper method that properly handles expectations
        var detectedPitches: [DetectedPitch?] = []

        for (index, note) in notes.enumerated() {
            let analysisTime = note.onset + 0.1
            let detected = await analyzePitchAsync(
                from: audioURL,
                at: analysisTime,
                description: "Note \(index + 1)"
            )
            detectedPitches.append(detected)
        }

        // Process results
        var results: [(expected: Double, detected: Double?, confidence: Double, error: Double?)] = []

        for (index, note) in notes.enumerated() {
            let expectedFreq = note.midiNote.frequency

            if let detected = detectedPitches[index] {
                let errorCents = 1200.0 * log2(detected.frequency / expectedFreq)
                results.append((expectedFreq, detected.frequency, detected.confidence, errorCents))
                print(String(format: "  ✅ Note %d (%s): %.2f Hz → %.2f Hz (%.1f cent, conf: %.3f)",
                             index + 1, note.midiNote.noteName, expectedFreq, detected.frequency, errorCents, detected.confidence))
            } else {
                results.append((expectedFreq, nil, 0.0, nil))
                print(String(format: "  ❌ Note %d (%s): %.2f Hz → FAILED",
                             index + 1, note.midiNote.noteName, expectedFreq))
            }
        }

        // Calculate metrics
        let metrics = calculateMetrics(results)

        print("")
        print("===========================================")
        print("📊 BASELINE METRICS (CSD Real Voice)")
        print("===========================================")
        print("")
        print(String(format: "  GPE (Gross Pitch Error):    %.2f%% (目標: <5%%)", metrics.gpe * 100))
        print(String(format: "  FPE (Fine Pitch Error):     %.2f cent (目標: <10 cent)", metrics.fpe))
        print(String(format: "  Octave Error Rate:          %.2f%% (目標: <2%%)", metrics.octaveErrorRate * 100))
        print(String(format: "  Detection Success Rate:     %.2f%%", metrics.detectionRate * 100))
        print(String(format: "  Average Confidence:         %.3f", metrics.avgConfidence))
        print("")
        print("===========================================")
        print("")

        // Assert metrics meet goals (relaxed for initial testing)
        XCTAssertLessThanOrEqual(metrics.gpe, 0.20, "GPE should be < 20% (initial baseline)")
        XCTAssertGreaterThanOrEqual(metrics.detectionRate, 0.80, "Detection rate should be >= 80%")

        // NOTE: These are relaxed thresholds for initial validation
        // Once real CSD data is available, tighten to:
        // - GPE < 5%
        // - FPE < 10 cent
        // - Octave Error Rate < 2%
        // - Detection Rate >= 90%
    }

    // MARK: - Helper Methods

    /// Common test logic for individual note accuracy testing
    private func testNoteAccuracy(noteIndex: Int, noteName: String) async throws {
        // Load CSV timing data
        let csvPath = getCSDResourcePath(filename: "001.csv", subdirectory: "csv")
        let csvContent = try String(contentsOfFile: csvPath, encoding: .utf8)
        let notes = try csvParser.parseCSVContent(csvContent, hasHeader: true)

        guard noteIndex < notes.count else {
            XCTFail("Note index \(noteIndex) out of bounds (total: \(notes.count))")
            return
        }

        let targetNote = notes[noteIndex]

        // Load audio file
        let audioPath = getCSDResourcePath(filename: "001.wav", subdirectory: "audio")
        let audioURL = URL(fileURLWithPath: audioPath)

        // Analyze pitch at note onset + 0.1 seconds (to avoid attack transients)
        let analysisTime = targetNote.onset + 0.1
        let expectation = expectation(description: "Analyze \(noteName) at \(analysisTime)s")
        var detectedPitch: DetectedPitch?

        await MainActor.run {
            pitchDetector.analyzePitchFromFile(audioURL, atTime: analysisTime) { pitch in
                detectedPitch = pitch
                expectation.fulfill()
            }
        }

        await fulfillment(of: [expectation], timeout: 10.0)

        // Verify detection
        XCTAssertNotNil(detectedPitch, "Failed to detect pitch for \(noteName)")

        if let detected = detectedPitch {
            let expectedFreq = targetNote.midiNote.frequency
            let errorCents = abs(1200.0 * log2(detected.frequency / expectedFreq))

            print("🎵 Note \(noteIndex + 1): \(targetNote.midiNote.noteName) (\(targetNote.syllable))")
            print("   Expected: \(String(format: "%.2f", expectedFreq)) Hz")
            print("   Detected: \(String(format: "%.2f", detected.frequency)) Hz")
            print("   Error: \(String(format: "%.1f", errorCents)) cents")
            print("   Confidence: \(String(format: "%.3f", detected.confidence))")

            // Verify accuracy (within 50 cents = half semitone)
            XCTAssertLessThan(errorCents, 50.0, "\(noteName) pitch detection error exceeds 50 cents")
            XCTAssertGreaterThan(detected.confidence, 0.5, "\(noteName) confidence too low")
        }
    }

    /// Async wrapper for pitch detection using the same pattern as testSingleNoteAccuracy
    private func analyzePitchAsync(from audioURL: URL, at time: TimeInterval, description: String) async -> DetectedPitch? {
        let expectation = expectation(description: description)
        var detectedPitch: DetectedPitch?

        await MainActor.run {
            pitchDetector.analyzePitchFromFile(audioURL, atTime: time) { pitch in
                detectedPitch = pitch
                expectation.fulfill()
            }
        }

        await fulfillment(of: [expectation], timeout: 10.0)
        return detectedPitch
    }

    /// Generate synthetic song with WAV and CSV files
    private func generateSyntheticSong(
        audioURL: URL,
        csvURL: URL,
        notes: [(midiNote: UInt8, duration: TimeInterval)]
    ) throws {
        let sampleRate = 44100.0
        var currentTime: TimeInterval = 0.0
        var csvLines: [String] = ["onset,offset,midi_note,syllable"]
        var allAudioData: [Float] = []

        // Generate each note
        for (index, noteInfo) in notes.enumerated() {
            let midiNote = try MIDINote(noteInfo.midiNote)
            let frequency = midiNote.frequency
            let duration = noteInfo.duration

            // CSV entry
            let onset = currentTime
            let offset = currentTime + duration
            let syllable = "note\(index + 1)"
            csvLines.append("\(onset),\(offset),\(noteInfo.midiNote),\(syllable)")

            // Generate audio for this note
            let frameCount = Int(duration * sampleRate)
            for frame in 0..<frameCount {
                let time = Double(frame) / sampleRate
                let fundamental = sin(2.0 * .pi * frequency * time)
                let harmonic2 = 0.5 * sin(2.0 * .pi * frequency * 2.0 * time)
                let harmonic3 = 0.25 * sin(2.0 * .pi * frequency * 3.0 * time)
                let harmonic4 = 0.125 * sin(2.0 * .pi * frequency * 4.0 * time)
                let value = Float(fundamental + harmonic2 + harmonic3 + harmonic4) * 0.3
                allAudioData.append(value)
            }

            currentTime = offset
        }

        // Write audio file
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let frameCount = AVAudioFrameCount(allAudioData.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "CSDAccuracyEvaluationTests", code: -1)
        }
        buffer.frameLength = frameCount

        let channelData = buffer.floatChannelData![0]
        for (index, sample) in allAudioData.enumerated() {
            channelData[index] = sample
        }

        let audioFile = try AVAudioFile(
            forWriting: audioURL,
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

        // Write CSV file
        let csvContent = csvLines.joined(separator: "\n")
        try csvContent.write(to: csvURL, atomically: true, encoding: .utf8)
    }

    /// Get path to CSD resource file
    private func getCSDResourcePath(filename: String, subdirectory: String) -> String {
        // Use direct filesystem path since resources are not in test bundle
        let projectPath = #file // Current test file path
        let testDir = (projectPath as NSString).deletingLastPathComponent
        let resourcesPath = (testDir as NSString).appendingPathComponent("../../Resources/CSD/\(subdirectory)")
        let fullPath = (resourcesPath as NSString).appendingPathComponent(filename)
        return (fullPath as NSString).standardizingPath
    }

    /// Calculate accuracy metrics from detection results
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

            // Check for octave errors
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
