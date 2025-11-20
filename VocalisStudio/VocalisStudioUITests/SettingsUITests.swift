//
//  SettingsUITests.swift
//  VocalisStudioUITests
//
//  UI tests for settings changes and their effects
//

import XCTest

final class SettingsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Test: Scale settings change (5-tone ↔ Off)
    /// Expected: ~30 seconds execution time
    @MainActor
    func testChangeScaleSettings() throws {
        let app = launchAppWithResetRecordingCount()

        // 1. Navigate to Recording screen
        let homeRecordButton = app.buttons["HomeRecordButton"]
        XCTAssertTrue(homeRecordButton.waitForExistence(timeout: 5), "Home record button should exist")
        homeRecordButton.tap()

        // Wait for recording screen to load by checking start button
        let startButton = app.buttons["StartRecordingButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Start button should exist on recording screen")

        // Screenshot: Initial recording screen
        let screenshot1 = app.screenshot()
        let attachment1 = XCTAttachment(screenshot: screenshot1)
        attachment1.name = "scale_01_initial_screen"
        attachment1.lifetime = .keepAlways
        add(attachment1)

        // 2. Show settings panel if it's hidden (portrait layout)
        // Look for "設定を表示" button - tap if it exists
        let showSettingsButton = app.buttons["設定を表示"]
        if showSettingsButton.waitForExistence(timeout: 2) {
            showSettingsButton.tap()
            // No animation wait needed - animations disabled in UI test mode
        }

        // 3. Find scale type picker
        let scaleTypePicker = app.segmentedControls["ScaleTypePicker"]
        XCTAssertTrue(scaleTypePicker.waitForExistence(timeout: 10), "Scale type picker should exist")

        // 4. Verify initial value is "5トーン" (5-tone)
        let fiveToneButton = scaleTypePicker.buttons["5トーン"]
        XCTAssertTrue(fiveToneButton.exists, "5-tone button should exist")
        XCTAssertTrue(fiveToneButton.isSelected, "5-tone should be selected by default")

        // Screenshot: Default 5-tone selected
        let screenshot2 = app.screenshot()
        let attachment2 = XCTAttachment(screenshot: screenshot2)
        attachment2.name = "scale_02_default_five_tone"
        attachment2.lifetime = .keepAlways
        add(attachment2)

        // 5. Change scale to "オフ" (Off)
        let offButton = scaleTypePicker.buttons["オフ"]
        XCTAssertTrue(offButton.exists, "Off button should exist")
        offButton.tap()

        // Verify scale changed to Off
        XCTAssertTrue(offButton.isSelected, "Off should be selected after tap")

        // Screenshot: Scale changed to Off
        let screenshot3 = app.screenshot()
        let attachment3 = XCTAttachment(screenshot: screenshot3)
        attachment3.name = "scale_03_changed_to_off"
        attachment3.lifetime = .keepAlways
        add(attachment3)

        // 6. Record with scale OFF
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Start button should exist")
        startButton.tap()

        // Wait for countdown to complete (3 seconds)
        Thread.sleep(forTimeInterval: 3.5)

        // During recording, verify target pitch remains "--" (no scale, no target)
        let targetPitchEmpty = app.staticTexts["TargetPitchEmpty"]
        XCTAssertTrue(targetPitchEmpty.waitForExistence(timeout: 2), "Target pitch display should exist during recording")
        XCTAssertEqual(targetPitchEmpty.label, "--", "Target pitch should remain '--' when scale is OFF during recording")

        // Continue recording for a moment
        Thread.sleep(forTimeInterval: 1.5)

        let stopButton = app.buttons["StopRecordingButton"]
        XCTAssertTrue(stopButton.exists, "Stop button should be available")
        stopButton.tap()

        // Wait for recording to be saved by checking PlayButton appearance
        // No Thread.sleep needed - waitForExistence will wait for save completion
        let playButton = app.buttons["PlayLastRecordingButton"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 5), "Play button should appear after save")

        // Screenshot: After recording with scale OFF
        let screenshot4 = app.screenshot()
        let attachment4 = XCTAttachment(screenshot: screenshot4)
        attachment4.name = "scale_04_recorded_without_scale"
        attachment4.lifetime = .keepAlways
        add(attachment4)

        // Verify first recording was saved by checking recording list
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let listButton1 = app.buttons["HomeListButton"]
        XCTAssertTrue(listButton1.waitForExistence(timeout: 5), "Home list button should exist")
        listButton1.tap()

        // Wait for list to load by checking for delete buttons
        let deleteButtons1 = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "DeleteRecordingButton_"))
        XCTAssertTrue(deleteButtons1.firstMatch.waitForExistence(timeout: 5), "Delete button should appear in list")
        XCTAssertGreaterThanOrEqual(deleteButtons1.count, 1, "At least 1 recording should exist after first recording")

        // Navigate back to home screen to start second recording
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // Navigate to Recording screen for second recording
        let homeRecordButton2 = app.buttons["HomeRecordButton"]
        XCTAssertTrue(homeRecordButton2.waitForExistence(timeout: 5), "Home record button should exist for second recording")
        homeRecordButton2.tap()

        // Wait for scale picker to be ready
        XCTAssertTrue(scaleTypePicker.waitForExistence(timeout: 5), "Scale type picker should exist for second recording")

        // 7. Show settings panel again if it was hidden after recording
        if showSettingsButton.waitForExistence(timeout: 2) {
            showSettingsButton.tap()
            // No animation wait needed - animations disabled in UI test mode
        }

        // 8. Change scale back to "5トーン" (5-tone)
        XCTAssertTrue(scaleTypePicker.waitForExistence(timeout: 5), "Scale type picker should exist after re-showing settings")
        XCTAssertTrue(fiveToneButton.exists, "5-tone button should still exist")
        fiveToneButton.tap()

        // Verify scale changed back to 5-tone
        XCTAssertTrue(fiveToneButton.isSelected, "5-tone should be selected after tap")

        // Screenshot: Scale changed back to 5-tone
        let screenshot5 = app.screenshot()
        let attachment5 = XCTAttachment(screenshot: screenshot5)
        attachment5.name = "scale_05_changed_to_five_tone"
        attachment5.lifetime = .keepAlways
        add(attachment5)

        // 9. Record with scale ON (5-tone)
        XCTAssertTrue(startButton.exists, "Start button should exist for second recording")
        startButton.tap()

        // Wait for countdown to complete (3 seconds) + extra time for scale/pitch monitoring to start
        Thread.sleep(forTimeInterval: 5.0)  // Increased from 3.5s to 5.0s for debugging

        // During recording, verify target pitch is displayed (not "--")
        // Scale playback should have started, showing actual pitch targets
        // When targetPitch is set, the UI uses "TargetPitchNoteName" accessibility identifier
        let targetPitchNoteName = app.staticTexts["TargetPitchNoteName"]
        XCTAssertTrue(targetPitchNoteName.waitForExistence(timeout: 2), "Target pitch note name should exist during recording with scale ON")

        // Target pitch should show actual note (e.g., "C3", "D3") when scale is ON
        // Verify the label is not empty and looks like a note name
        let noteLabel = targetPitchNoteName.label
        XCTAssertFalse(noteLabel.isEmpty, "Target pitch note name should not be empty when scale is ON")
        XCTAssertTrue(noteLabel.count >= 2, "Target pitch should display actual notes (e.g., 'C3', 'D3') when scale is ON during recording")

        // Continue recording for a moment
        Thread.sleep(forTimeInterval: 1.5)

        XCTAssertTrue(stopButton.exists, "Stop button should be available for second recording")
        stopButton.tap()

        // Wait for recording to be saved by checking PlayButton appearance
        // No Thread.sleep needed - waitForExistence will wait for save completion
        let playButton2 = app.buttons["PlayLastRecordingButton"]
        XCTAssertTrue(playButton2.waitForExistence(timeout: 5), "Play button should appear after second save")

        // Screenshot: After recording with scale ON
        let screenshot6 = app.screenshot()
        let attachment6 = XCTAttachment(screenshot: screenshot6)
        attachment6.name = "scale_06_recorded_with_scale"
        attachment6.lifetime = .keepAlways
        add(attachment6)

        // 10. Navigate to Recording List to verify both recordings were created
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let homeListButton = app.buttons["HomeListButton"]
        XCTAssertTrue(homeListButton.waitForExistence(timeout: 5), "Home list button should exist")
        homeListButton.tap()

        // Wait for list to load by checking for delete buttons
        let deleteButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "DeleteRecordingButton_"))
        XCTAssertTrue(deleteButtons.firstMatch.waitForExistence(timeout: 5), "Delete button should appear in list")

        // Screenshot: Recording list with both recordings
        let screenshot7 = app.screenshot()
        let attachment7 = XCTAttachment(screenshot: screenshot7)
        attachment7.name = "scale_07_recording_list"
        attachment7.lifetime = .keepAlways
        add(attachment7)

        // Verify at least 2 recordings exist
        let recordingCount = deleteButtons.count
        XCTAssertGreaterThanOrEqual(recordingCount, 2, "At least 2 recordings should exist (one with scale OFF, one with scale ON)")
    }
}
