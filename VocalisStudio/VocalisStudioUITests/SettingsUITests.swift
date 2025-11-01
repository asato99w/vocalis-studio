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

        Thread.sleep(forTimeInterval: 1.0)

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
            Thread.sleep(forTimeInterval: 2.0) // Wait for panel expansion animation
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

        Thread.sleep(forTimeInterval: 0.5)

        // Verify scale changed to Off
        XCTAssertTrue(offButton.isSelected, "Off should be selected after tap")

        // Verify target pitch is not displayed when scale is OFF
        let targetPitchEmpty = app.staticTexts["TargetPitchEmpty"]
        XCTAssertTrue(targetPitchEmpty.exists, "Target pitch display should exist")
        XCTAssertEqual(targetPitchEmpty.label, "--", "Target pitch should be empty (--) when scale is OFF")

        // Screenshot: Scale changed to Off
        let screenshot3 = app.screenshot()
        let attachment3 = XCTAttachment(screenshot: screenshot3)
        attachment3.name = "scale_03_changed_to_off"
        attachment3.lifetime = .keepAlways
        add(attachment3)

        // 6. Record with scale OFF
        let startButton = app.buttons["StartRecordingButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Start button should exist")
        startButton.tap()

        // Wait for countdown and short recording
        Thread.sleep(forTimeInterval: 5.0)

        let stopButton = app.buttons["StopRecordingButton"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 2), "Stop button should appear")
        stopButton.tap()

        // Wait for recording to be saved
        Thread.sleep(forTimeInterval: 2.0)

        // Screenshot: After recording with scale OFF
        let screenshot4 = app.screenshot()
        let attachment4 = XCTAttachment(screenshot: screenshot4)
        attachment4.name = "scale_04_recorded_without_scale"
        attachment4.lifetime = .keepAlways
        add(attachment4)

        // 7. Show settings panel again if it was hidden after recording
        if showSettingsButton.waitForExistence(timeout: 2) {
            showSettingsButton.tap()
            Thread.sleep(forTimeInterval: 2.0) // Wait for panel expansion
        }

        // 8. Change scale back to "5トーン" (5-tone)
        XCTAssertTrue(scaleTypePicker.waitForExistence(timeout: 5), "Scale type picker should exist after re-showing settings")
        XCTAssertTrue(fiveToneButton.exists, "5-tone button should still exist")
        fiveToneButton.tap()

        Thread.sleep(forTimeInterval: 0.5)

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

        // Wait for countdown and short recording
        Thread.sleep(forTimeInterval: 5.0)

        XCTAssertTrue(stopButton.waitForExistence(timeout: 2), "Stop button should appear for second recording")
        stopButton.tap()

        // Wait for recording to be saved
        Thread.sleep(forTimeInterval: 2.0)

        // Screenshot: After recording with scale ON
        let screenshot6 = app.screenshot()
        let attachment6 = XCTAttachment(screenshot: screenshot6)
        attachment6.name = "scale_06_recorded_with_scale"
        attachment6.lifetime = .keepAlways
        add(attachment6)

        // 10. Navigate to Recording List to verify both recordings were created
        app.navigationBars.buttons.element(boundBy: 0).tap()
        Thread.sleep(forTimeInterval: 0.5)

        let homeListButton = app.buttons["HomeListButton"]
        XCTAssertTrue(homeListButton.waitForExistence(timeout: 5), "Home list button should exist")
        homeListButton.tap()

        Thread.sleep(forTimeInterval: 2.0)

        // Screenshot: Recording list with both recordings
        let screenshot7 = app.screenshot()
        let attachment7 = XCTAttachment(screenshot: screenshot7)
        attachment7.name = "scale_07_recording_list"
        attachment7.lifetime = .keepAlways
        add(attachment7)

        // Verify at least 2 recordings exist
        let deleteButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "DeleteRecordingButton_"))
        let recordingCount = deleteButtons.count

        XCTAssertGreaterThanOrEqual(recordingCount, 2, "At least 2 recordings should exist (one with scale OFF, one with scale ON)")
    }
}
