import XCTest
import AVFoundation
import VocalisDomain
@testable import VocalisStudio

/// vocadito singing voice dataset accuracy evaluation tests
///
/// Dataset structure:
/// - Audio: vocadito_*.wav files
/// - F0 annotations: Annotations/F0/vocadito_*_f0.csv
/// - Note annotations: Annotations/Notes/vocadito_*_notesA1.csv, vocadito_*_notesA2.csv
///
@available(iOS 13.0, *)
final class VocaditoAccuracyEvaluationTests: XCTestCase {

    // MARK: - Properties

    private var pitchDetector: RealtimePitchDetector!
    private let f0Parser = VocaditoF0Parser()
    private let noteParser = VocaditoNoteParser()

    // MARK: - Setup/Teardown

    override func setUp() async throws {
        try await super.setUp()

        // Initialize pitch detector on MainActor
        pitchDetector = await MainActor.run {
            return RealtimePitchDetector()
        }
    }

    // MARK: - Resource Loading Tests

    /// Test loading vocadito F0 annotation file
    func testLoadVocaditoF0File() throws {
        let f0Path = getVocaditoResourcePath(filename: "vocadito_1_f0.csv", subdirectory: "Annotations/F0")

        guard FileManager.default.fileExists(atPath: f0Path) else {
            XCTFail("❌ vocadito F0 file not found at: \(f0Path)\n" +
                    "Please download vocadito dataset and place in dataset/vocadito/")
            return
        }

        let f0Content = try String(contentsOfFile: f0Path, encoding: .utf8)
        let f0Points = try f0Parser.parseF0Content(f0Content)

        XCTAssertGreaterThan(f0Points.count, 0, "F0 annotations should contain data points")
        print("✅ Loaded \(f0Points.count) F0 points from vocadito_1_f0.csv")
    }

    /// Test loading vocadito note annotation file
    func testLoadVocaditoNoteFile() throws {
        let notePath = getVocaditoResourcePath(filename: "vocadito_1_notesA1.csv", subdirectory: "Annotations/Notes")

        guard FileManager.default.fileExists(atPath: notePath) else {
            XCTFail("❌ vocadito note file not found at: \(notePath)\n" +
                    "Please download vocadito dataset and place in dataset/vocadito/")
            return
        }

        let noteContent = try String(contentsOfFile: notePath, encoding: .utf8)
        let notes = try noteParser.parseNoteContent(noteContent)

        XCTAssertGreaterThan(notes.count, 0, "Note annotations should contain notes")
        print("✅ Loaded \(notes.count) notes from vocadito_1_notesA1.csv")
    }

    /// Test loading vocadito audio file
    func testLoadVocaditoAudioFile() throws {
        let audioPath = getVocaditoResourcePath(filename: "vocadito_1.wav", subdirectory: "Audio")

        guard FileManager.default.fileExists(atPath: audioPath) else {
            XCTFail("❌ vocadito audio file not found at: \(audioPath)\n" +
                    "Please download vocadito dataset and place in dataset/vocadito/")
            return
        }

        let audioURL = URL(fileURLWithPath: audioPath)
        let audioFile = try AVAudioFile(forReading: audioURL)

        let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
        XCTAssertEqual(audioFile.processingFormat.sampleRate, 44100, "vocadito audio should be 44.1kHz")
        print("✅ Loaded audio file: \(audioFile.length) samples, \(String(format: "%.2f", duration)) seconds")
    }

    // MARK: - Single Note Accuracy Tests

    /// Test pitch detection accuracy for a single note from vocadito
    func testSingleNoteAccuracy() async throws {
        // Load note annotations
        let notePath = getVocaditoResourcePath(filename: "vocadito_1_notesA1.csv", subdirectory: "Annotations/Notes")
        let noteContent = try String(contentsOfFile: notePath, encoding: .utf8)
        let notes = try noteParser.parseNoteContent(noteContent)

        guard let firstNote = notes.first else {
            XCTFail("No notes found in annotation")
            return
        }

        // Load audio file
        let audioPath = getVocaditoResourcePath(filename: "vocadito_1.wav", subdirectory: "Audio")
        let audioURL = URL(fileURLWithPath: audioPath)

        // Analyze pitch at note center (start + duration/2) to avoid onset/offset transients
        let analysisTime = firstNote.startTime + (firstNote.duration / 2.0)
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
            let expectedFreq = firstNote.frequency
            let errorCents = abs(1200.0 * log2(detected.frequency / expectedFreq))

            print("🎵 Note at \(String(format: "%.2f", firstNote.startTime))s")
            print("   Expected: \(String(format: "%.2f", expectedFreq)) Hz")
            print("   Detected: \(String(format: "%.2f", detected.frequency)) Hz")
            print("   Error: \(String(format: "%.1f", errorCents)) cents")
            print("   Confidence: \(String(format: "%.3f", detected.confidence))")

            // Verify accuracy (within 50 cents = half semitone)
            XCTAssertLessThan(errorCents, 50.0, "Pitch detection error exceeds 50 cents")
            XCTAssertGreaterThan(detected.confidence, 0.5, "Confidence too low")
        }
    }

    // MARK: - Multi-Note Accuracy Tests

    /// Test pitch detection accuracy for Track 1, first 3 notes
    func testTrack1_Note1() async throws {
        try await testNoteAccuracy(trackId: 1, noteIndex: 0, noteName: "Track1_Note1")
    }

    func testTrack1_Note2() async throws {
        try await testNoteAccuracy(trackId: 1, noteIndex: 1, noteName: "Track1_Note2")
    }

    func testTrack1_Note3() async throws {
        try await testNoteAccuracy(trackId: 1, noteIndex: 2, noteName: "Track1_Note3")
    }

    /// Test pitch detection accuracy for Track 2, first 3 notes
    func testTrack2_Note1() async throws {
        try await testNoteAccuracy(trackId: 2, noteIndex: 0, noteName: "Track2_Note1")
    }

    func testTrack2_Note2() async throws {
        try await testNoteAccuracy(trackId: 2, noteIndex: 1, noteName: "Track2_Note2")
    }

    func testTrack2_Note3() async throws {
        try await testNoteAccuracy(trackId: 2, noteIndex: 2, noteName: "Track2_Note3")
    }

    /// Test pitch detection accuracy for Track 3, first 3 notes
    func testTrack3_Note1() async throws {
        try await testNoteAccuracy(trackId: 3, noteIndex: 0, noteName: "Track3_Note1")
    }

    func testTrack3_Note2() async throws {
        try await testNoteAccuracy(trackId: 3, noteIndex: 1, noteName: "Track3_Note2")
    }

    func testTrack3_Note3() async throws {
        try await testNoteAccuracy(trackId: 3, noteIndex: 2, noteName: "Track3_Note3")
    }

    /// Test pitch detection accuracy for Track 4, first 3 notes
    func testTrack4_Note1() async throws {
        try await testNoteAccuracy(trackId: 4, noteIndex: 0, noteName: "Track4_Note1")
    }

    func testTrack4_Note2() async throws {
        try await testNoteAccuracy(trackId: 4, noteIndex: 1, noteName: "Track4_Note2")
    }

    func testTrack4_Note3() async throws {
        try await testNoteAccuracy(trackId: 4, noteIndex: 2, noteName: "Track4_Note3")
    }

    /// Test pitch detection accuracy for Track 5, first 3 notes
    func testTrack5_Note1() async throws {
        try await testNoteAccuracy(trackId: 5, noteIndex: 0, noteName: "Track5_Note1")
    }

    func testTrack5_Note2() async throws {
        try await testNoteAccuracy(trackId: 5, noteIndex: 1, noteName: "Track5_Note2")
    }

    func testTrack5_Note3() async throws {
        try await testNoteAccuracy(trackId: 5, noteIndex: 2, noteName: "Track5_Note3")
    }

    /// Test pitch detection accuracy for Track 6, first 3 notes
    func testTrack6_Note1() async throws {
        try await testNoteAccuracy(trackId: 6, noteIndex: 0, noteName: "Track6_Note1")
    }

    func testTrack6_Note2() async throws {
        try await testNoteAccuracy(trackId: 6, noteIndex: 1, noteName: "Track6_Note2")
    }

    func testTrack6_Note3() async throws {
        try await testNoteAccuracy(trackId: 6, noteIndex: 2, noteName: "Track6_Note3")
    }

    /// Test pitch detection accuracy for Track 7, first 3 notes
    func testTrack7_Note1() async throws {
        try await testNoteAccuracy(trackId: 7, noteIndex: 0, noteName: "Track7_Note1")
    }

    func testTrack7_Note2() async throws {
        try await testNoteAccuracy(trackId: 7, noteIndex: 1, noteName: "Track7_Note2")
    }

    func testTrack7_Note3() async throws {
        try await testNoteAccuracy(trackId: 7, noteIndex: 2, noteName: "Track7_Note3")
    }

    /// Test pitch detection accuracy for Track 8, first 3 notes
    func testTrack8_Note1() async throws {
        try await testNoteAccuracy(trackId: 8, noteIndex: 0, noteName: "Track8_Note1")
    }

    func testTrack8_Note2() async throws {
        try await testNoteAccuracy(trackId: 8, noteIndex: 1, noteName: "Track8_Note2")
    }

    func testTrack8_Note3() async throws {
        try await testNoteAccuracy(trackId: 8, noteIndex: 2, noteName: "Track8_Note3")
    }

    /// Test pitch detection accuracy for Track 9, first 3 notes
    func testTrack9_Note1() async throws {
        try await testNoteAccuracy(trackId: 9, noteIndex: 0, noteName: "Track9_Note1")
    }

    func testTrack9_Note2() async throws {
        try await testNoteAccuracy(trackId: 9, noteIndex: 1, noteName: "Track9_Note2")
    }

    func testTrack9_Note3() async throws {
        try await testNoteAccuracy(trackId: 9, noteIndex: 2, noteName: "Track9_Note3")
    }

    /// Test pitch detection accuracy for Track 10, first 3 notes
    func testTrack10_Note1() async throws {
        try await testNoteAccuracy(trackId: 10, noteIndex: 0, noteName: "Track10_Note1")
    }

    func testTrack10_Note2() async throws {
        try await testNoteAccuracy(trackId: 10, noteIndex: 1, noteName: "Track10_Note2")
    }

    func testTrack10_Note3() async throws {
        try await testNoteAccuracy(trackId: 10, noteIndex: 2, noteName: "Track10_Note3")
    }

    // MARK: - Helper Methods

    /// Test accuracy for a specific note by index
    private func testNoteAccuracy(trackId: Int, noteIndex: Int, noteName: String) async throws {
        // Load note annotations
        let notePath = getVocaditoResourcePath(
            filename: "vocadito_\(trackId)_notesA1.csv",
            subdirectory: "Annotations/Notes"
        )
        let noteContent = try String(contentsOfFile: notePath, encoding: .utf8)
        let notes = try noteParser.parseNoteContent(noteContent)

        guard noteIndex < notes.count else {
            XCTFail("Note index \(noteIndex) out of range (total: \(notes.count) notes)")
            return
        }

        let note = notes[noteIndex]

        // Load audio file
        let audioPath = getVocaditoResourcePath(filename: "vocadito_\(trackId).wav", subdirectory: "Audio")
        let audioURL = URL(fileURLWithPath: audioPath)

        // Analyze pitch at note center
        let analysisTime = note.startTime + (note.duration / 2.0)
        let expectation = expectation(description: "Analyze \(noteName)")
        var detectedPitch: DetectedPitch?

        print("\n[DEBUG] Analyzing \(noteName) at time \(String(format: "%.3f", analysisTime))s")
        print("[DEBUG] Expected frequency: \(String(format: "%.2f", note.frequency)) Hz")

        await MainActor.run {
            pitchDetector.analyzePitchFromFile(audioURL, atTime: analysisTime) { pitch in
                detectedPitch = pitch
                print("[DEBUG] Pitch detection callback received: \(pitch != nil ? "SUCCESS" : "FAILED")")
                expectation.fulfill()
            }
        }

        await fulfillment(of: [expectation], timeout: 10.0)

        // Verify detection
        print("[DEBUG] detectedPitch after fulfillment: \(detectedPitch != nil ? "NOT NIL" : "NIL")")
        XCTAssertNotNil(detectedPitch, "Failed to detect pitch for \(noteName)")

        if let detected = detectedPitch {
            let expectedFreq = note.frequency
            let errorCents = abs(1200.0 * log2(detected.frequency / expectedFreq))

            // Write results to file for debugging
            let logMessage = """
            🎵 \(noteName) (\(String(format: "%.2f", note.startTime))s - \(String(format: "%.2f", note.endTime))s)
               Expected: \(String(format: "%.2f", expectedFreq)) Hz
               Detected: \(String(format: "%.2f", detected.frequency)) Hz
               Error: \(String(format: "%.1f", errorCents)) cents
               Confidence: \(String(format: "%.3f", detected.confidence))
               Pass errorCents check: \(errorCents < 50.0 ? "YES" : "NO")
               Pass confidence check: \(detected.confidence > 0.5 ? "YES" : "NO")

            """
            try? logMessage.appendToFile(at: "/tmp/vocadito_pitch_results.txt")

            print("\n🎵 \(noteName) (\(String(format: "%.2f", note.startTime))s - \(String(format: "%.2f", note.endTime))s)")
            print("   Expected: \(String(format: "%.2f", expectedFreq)) Hz")
            print("   Detected: \(String(format: "%.2f", detected.frequency)) Hz")
            print("   Error: \(String(format: "%.1f", errorCents)) cents")
            print("   Confidence: \(String(format: "%.3f", detected.confidence))")

            // Verify accuracy
            print("[DEBUG] Checking errorCents (\(String(format: "%.1f", errorCents))) < 50.0")
            print("[DEBUG] Checking confidence (\(String(format: "%.3f", detected.confidence))) > 0.5")

            XCTAssertLessThan(errorCents, 50.0, "\(noteName): Pitch error exceeds 50 cents (actual: \(String(format: "%.1f", errorCents)) cents)")
            XCTAssertGreaterThan(detected.confidence, 0.5, "\(noteName): Confidence too low (actual: \(String(format: "%.3f", detected.confidence)))")
        } else {
            print("[DEBUG] ERROR: detectedPitch is nil in the if-let block - this should never happen!")
        }
    }

    /// Get resource path for vocadito dataset files
    private func getVocaditoResourcePath(filename: String, subdirectory: String) -> String {
        // Use absolute path to project root
        // This file is in VocalisStudio/VocalisStudioTests, so go up 2 levels to reach project root
        let testFileURL = URL(fileURLWithPath: #file)
        let projectRoot = testFileURL
            .deletingLastPathComponent()  // Remove filename
            .deletingLastPathComponent()  // Remove Audio
            .deletingLastPathComponent()  // Remove Infrastructure
            .deletingLastPathComponent()  // Remove VocalisStudioTests
            .deletingLastPathComponent()  // Remove VocalisStudio

        let datasetPath = projectRoot
            .appendingPathComponent("dataset")
            .appendingPathComponent("vocadito")
            .appendingPathComponent(subdirectory)
            .appendingPathComponent(filename)
            .path

        return datasetPath
    }
}

// MARK: - String Extension for File Logging
extension String {
    func appendToFile(at path: String) throws {
        let url = URL(fileURLWithPath: path)

        if FileManager.default.fileExists(atPath: path) {
            let fileHandle = try FileHandle(forWritingTo: url)
            fileHandle.seekToEndOfFile()
            if let data = self.data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        } else {
            try self.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
