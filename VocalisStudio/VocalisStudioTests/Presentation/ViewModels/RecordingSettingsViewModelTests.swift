import XCTest
import VocalisDomain
@testable import VocalisStudio

final class RecordingSettingsViewModelTests: XCTestCase {

    var sut: RecordingSettingsViewModel!

    override func setUp() {
        super.setUp()
        sut = RecordingSettingsViewModel()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInit_DefaultValues_AreSet() {
        // Then
        XCTAssertEqual(sut.scaleType, .fiveTone)
        XCTAssertEqual(sut.startPitchIndex, 12) // C3
        XCTAssertEqual(sut.tempo, 120)
        XCTAssertEqual(sut.ascendingCount, 3)
        XCTAssertTrue(sut.isSettingsEnabled)
    }

    func testAvailablePitches_Contains49Pitches() {
        // Then
        XCTAssertEqual(sut.availablePitches.count, 49)
        XCTAssertEqual(sut.availablePitches.first, "C2")
        XCTAssertEqual(sut.availablePitches.last, "C6")
    }

    // MARK: - Settings Enabled Tests

    func testIsSettingsEnabled_WhenFiveTone_ReturnsTrue() {
        // Given
        sut.scaleType = .fiveTone

        // Then
        XCTAssertTrue(sut.isSettingsEnabled)
    }

    func testIsSettingsEnabled_WhenOff_ReturnsFalse() {
        // Given
        sut.scaleType = .off

        // Then
        XCTAssertFalse(sut.isSettingsEnabled)
    }

    // MARK: - Generate Scale Settings Tests

    func testGenerateScaleSettings_WhenFiveTone_ReturnsValidSettings() {
        // Given
        sut.scaleType = .fiveTone
        sut.startPitchIndex = 12 // C3 (MIDI 48)
        sut.tempo = 120 // 0.5 seconds per note
        sut.ascendingCount = 3

        // When
        let settings = sut.generateScaleSettings()

        // Then
        XCTAssertNotNil(settings)
        XCTAssertEqual(settings!.startNote.value, 48) // C3
        XCTAssertEqual(settings!.endNote.value, 60) // C4 (one octave up)
        XCTAssertEqual(settings!.notePattern, .fiveToneScale)
        XCTAssertEqual(settings!.tempo.secondsPerNote, 0.5, accuracy: 0.001)
        XCTAssertEqual(settings!.ascendingCount, 3)
    }

    func testGenerateScaleSettings_WhenOff_ReturnsNil() {
        // Given
        sut.scaleType = .off

        // When
        let settings = sut.generateScaleSettings()

        // Then
        XCTAssertNil(settings)
    }

    func testGenerateScaleSettings_DifferentStartPitch_CalculatesCorrectMIDINote() {
        // Given
        sut.scaleType = .fiveTone
        sut.startPitchIndex = 0 // C2 (MIDI 36)
        sut.tempo = 120

        // When
        let settings = sut.generateScaleSettings()

        // Then
        XCTAssertNotNil(settings)
        XCTAssertEqual(settings?.startNote.value, 36) // C2
        XCTAssertEqual(settings?.endNote.value, 48) // C3
    }

    func testGenerateScaleSettings_DifferentStartPitch_HighNote_CalculatesCorrectMIDINote() {
        // Given
        sut.scaleType = .fiveTone
        sut.startPitchIndex = 48 // C6 (MIDI 84)
        sut.tempo = 120

        // When
        let settings = sut.generateScaleSettings()

        // Then
        XCTAssertNotNil(settings)
        XCTAssertEqual(settings?.startNote.value, 84) // C6
        XCTAssertEqual(settings?.endNote.value, 96) // C7
    }

    func testGenerateScaleSettings_DifferentTempo_CalculatesCorrectSecondsPerNote() {
        // Given
        sut.scaleType = .fiveTone
        sut.startPitchIndex = 12
        sut.tempo = 60 // 60 BPM = 1 second per note

        // When
        let settings = sut.generateScaleSettings()

        // Then
        XCTAssertNotNil(settings)
        XCTAssertEqual(settings!.tempo.secondsPerNote, 1.0, accuracy: 0.001)
    }

    func testGenerateScaleSettings_FastTempo_CalculatesCorrectSecondsPerNote() {
        // Given
        sut.scaleType = .fiveTone
        sut.startPitchIndex = 12
        sut.tempo = 180 // 180 BPM = 0.333... seconds per note

        // When
        let settings = sut.generateScaleSettings()

        // Then
        XCTAssertNotNil(settings)
        XCTAssertEqual(settings!.tempo.secondsPerNote, 60.0 / 180.0, accuracy: 0.001)
    }

    func testGenerateScaleSettings_DifferentAscendingCount_ReturnsCorrectValue() {
        // Given
        sut.scaleType = .fiveTone
        sut.startPitchIndex = 12
        sut.tempo = 120
        sut.ascendingCount = 5

        // When
        let settings = sut.generateScaleSettings()

        // Then
        XCTAssertNotNil(settings)
        XCTAssertEqual(settings?.ascendingCount, 5)
    }

    // MARK: - Edge Cases

    func testGenerateScaleSettings_MinimumTempo_DoesNotCrash() {
        // Given
        sut.scaleType = .fiveTone
        sut.tempo = 1 // Very slow

        // When
        let settings = sut.generateScaleSettings()

        // Then
        XCTAssertNotNil(settings)
        XCTAssertEqual(settings!.tempo.secondsPerNote, 60.0, accuracy: 0.001)
    }

    func testGenerateScaleSettings_MaximumTempo_DoesNotCrash() {
        // Given
        sut.scaleType = .fiveTone
        sut.tempo = 300 // Very fast

        // When
        let settings = sut.generateScaleSettings()

        // Then
        XCTAssertNotNil(settings)
        XCTAssertEqual(settings!.tempo.secondsPerNote, 60.0 / 300.0, accuracy: 0.001)
    }

    func testGenerateScaleSettings_InvalidMIDIRange_ReturnsNil() {
        // Given
        sut.scaleType = .fiveTone
        sut.startPitchIndex = 100 // Invalid - would result in MIDI > 127

        // When
        let settings = sut.generateScaleSettings()

        // Then
        XCTAssertNil(settings) // Should fail due to MIDI note validation
    }

    // MARK: - Integration Tests

    func testFullSettingsFlow_ModifyAllParameters_GeneratesCorrectSettings() {
        // Given
        sut.scaleType = .fiveTone
        sut.startPitchIndex = 24 // C4 (MIDI 60)
        sut.tempo = 90 // 0.666... seconds per note
        sut.ascendingCount = 4

        // When
        let settings = sut.generateScaleSettings()

        // Then
        XCTAssertNotNil(settings)
        XCTAssertEqual(settings!.startNote.value, 60) // C4
        XCTAssertEqual(settings!.endNote.value, 72) // C5
        XCTAssertEqual(settings!.tempo.secondsPerNote, 60.0 / 90.0, accuracy: 0.001)
        XCTAssertEqual(settings!.ascendingCount, 4)
        XCTAssertEqual(settings!.notePattern, .fiveToneScale)
    }
}
