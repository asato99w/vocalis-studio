import XCTest
import AVFoundation
import VocalisDomain
@testable import VocalisStudio

final class AVAudioEngineScalePlayerTests: XCTestCase {

    var sut: AVAudioEngineScalePlayer!

    override func setUp() async throws {
        try await super.setUp()
        sut = AVAudioEngineScalePlayer()
    }

    override func tearDown() async throws {
        await sut.stop()
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInit_DefaultState_NotPlaying() {
        XCTAssertFalse(sut.isPlaying)
        XCTAssertEqual(sut.currentNoteIndex, 0)
        XCTAssertEqual(sut.progress, 0.0)
    }

    // MARK: - loadScale Tests

    func testLoadScale_ValidNotesAndTempo_Success() async throws {
        let notes = [
            try MIDINote(60), // C4
            try MIDINote(62), // D4
            try MIDINote(64)  // E4
        ]
        let tempo = try Tempo(secondsPerNote: 0.5)

        try await sut.loadScale(notes, tempo: tempo)

        // No error should be thrown
        XCTAssertFalse(sut.isPlaying)
    }

    func testLoadScale_EmptyNotes_Success() async throws {
        let notes: [MIDINote] = []
        let tempo = Tempo.standard

        try await sut.loadScale(notes, tempo: tempo)

        // Should not throw error for empty notes
    }

    // MARK: - play Tests

    func testPlay_WithoutLoad_ThrowsError() async {
        do {
            try await sut.play()
            XCTFail("Expected to throw ScalePlayerError.notLoaded")
        } catch let error as ScalePlayerError {
            XCTAssertEqual(error, ScalePlayerError.notLoaded)
        } catch {
            XCTFail("Expected ScalePlayerError.notLoaded, got \(error)")
        }
    }

    func testPlay_AfterLoad_StartsPlayback() async throws {
        let notes = [try MIDINote(60)]
        try await sut.loadScale(notes, tempo: .standard)

        let playTask = Task {
            try await sut.play()
        }

        // Give it a moment to start
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        XCTAssertTrue(sut.isPlaying)

        await sut.stop()
        playTask.cancel()
    }

    func testPlay_WhilePlaying_ThrowsError() async throws {
        let notes = [try MIDINote(60)]
        try await sut.loadScale(notes, tempo: .standard)

        let playTask = Task {
            try await sut.play()
        }

        // Give it a moment to start
        try await Task.sleep(nanoseconds: 100_000_000)

        // Try to play again while already playing
        do {
            try await sut.play()
            XCTFail("Expected to throw ScalePlayerError.alreadyPlaying")
        } catch let error as ScalePlayerError {
            XCTAssertEqual(error, ScalePlayerError.alreadyPlaying)
        }

        await sut.stop()
        playTask.cancel()
    }

    func testPlay_UpdatesCurrentNoteIndex() async throws {
        let notes = [
            try MIDINote(60),
            try MIDINote(62),
            try MIDINote(64)
        ]
        let tempo = try Tempo(secondsPerNote: 0.2)

        try await sut.loadScale(notes, tempo: tempo)

        let playTask = Task {
            try await sut.play()
        }

        // Wait for first note
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        let firstIndex = sut.currentNoteIndex
        XCTAssertGreaterThanOrEqual(firstIndex, 0)

        // Wait for progression
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        let secondIndex = sut.currentNoteIndex
        XCTAssertGreaterThan(secondIndex, firstIndex)

        await sut.stop()
        playTask.cancel()
    }

    func testProgress_Calculation_CorrectValues() {
        // Test progress calculation without actual playback
        // This avoids timing issues
        XCTAssertEqual(sut.progress, 0.0) // No scale loaded

        // Note: We can't directly test progress during playback without timing dependencies
        // The progress property is tested implicitly through testPlay_CompletesSuccessfully
    }

    func testPlay_CompletesSuccessfully() async throws {
        let notes = [try MIDINote(60)]
        let tempo = try Tempo(secondsPerNote: 0.1)

        try await sut.loadScale(notes, tempo: tempo)

        try await sut.play()

        // Wait for playback to complete (note duration + small buffer)
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        // After completion, should not be playing
        XCTAssertFalse(sut.isPlaying)
        XCTAssertEqual(sut.progress, 1.0)
    }

    // MARK: - stop Tests

    func testStop_WhilePlaying_StopsPlayback() async throws {
        let notes = [try MIDINote(60), try MIDINote(62)]
        let tempo = try Tempo(secondsPerNote: 1.0)

        try await sut.loadScale(notes, tempo: tempo)

        let playTask = Task {
            try await sut.play()
        }

        // Start playing
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(sut.isPlaying)

        // Stop
        await sut.stop()

        // Should stop immediately
        XCTAssertFalse(sut.isPlaying)

        playTask.cancel()
    }

    func testStop_WhenNotPlaying_DoesNothing() async {
        // Should not crash or throw
        await sut.stop()
        XCTAssertFalse(sut.isPlaying)
    }

    // MARK: - Multiple playback cycle tests

    func testMultipleCycles_LoadPlayStopMultipleTimes_Success() async throws {
        for i in 0..<3 {
            let note = try MIDINote(UInt8(60 + i))
            try await sut.loadScale([note], tempo: .standard)

            let playTask = Task {
                try await sut.play()
            }

            try await Task.sleep(nanoseconds: 100_000_000)
            await sut.stop()
            playTask.cancel()

            XCTAssertFalse(sut.isPlaying, "Cycle \(i) should be stopped")
        }
    }
}
