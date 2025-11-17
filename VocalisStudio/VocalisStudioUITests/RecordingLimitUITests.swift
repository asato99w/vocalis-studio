import XCTest

/// UI tests for recording limit and paywall functionality
final class RecordingLimitUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // Use standard UI test launch arguments for compatibility
        app.launchArguments = ["-UITestResetRecordingCount", "-UITestDisableAnimations"]

        // Set subscription tier to free (to test free tier recording limit)
        app.launchEnvironment["SUBSCRIPTION_TIER"] = "free"
        // COMMENTED OUT: Testing without DAILY_RECORDING_COUNT to reproduce debug environment behavior
        // app.launchEnvironment["DAILY_RECORDING_COUNT"] = "100"

        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Recording Limit Alert Tests

    /// Test that recording limit alert appears when user tries to record at limit
    func testRecordingLimitAlert_shouldAppear_whenAtLimit() throws {
        // Given: User navigates to Recording screen
        let homeRecordButton = app.buttons["HomeRecordButton"]
        XCTAssertTrue(homeRecordButton.waitForExistence(timeout: 5), "Home record button should exist")
        homeRecordButton.tap()

        // When: User taps Record button at limit
        let recordButton = app.buttons["StartRecordingButton"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5), "Record button should exist")
        recordButton.tap()

        // Then: Alert should appear with limit message
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Limit alert should appear")

        let alertMessage = alert.staticTexts.element(boundBy: 1)  // Second text is the message
        XCTAssertTrue(
            alertMessage.label.contains("上限に達しました"),
            "Alert should contain limit message, but got: \(alertMessage.label)"
        )

        // And: Recording should NOT start (button should remain as "StartRecordingButton")
        let stopButton = app.buttons["StopRecordingButton"]
        XCTAssertFalse(stopButton.exists, "Stop button should NOT exist - recording should not have started")
        XCTAssertTrue(recordButton.exists, "Start button should still exist")
    }

    /// Test that OK button dismisses the recording limit alert
    /// BUG: Currently fails because alert doesn't dismiss when OK is pressed
    func testRecordingLimitAlert_shouldDismiss_whenOKPressed() throws {
        // Given: Recording limit alert is displayed
        let homeRecordButton = app.buttons["HomeRecordButton"]
        XCTAssertTrue(homeRecordButton.waitForExistence(timeout: 5), "Home record button should exist")
        homeRecordButton.tap()

        let recordButton = app.buttons["StartRecordingButton"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5), "Record button should exist")
        recordButton.tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Alert should appear")

        // When: User taps OK button
        let okButton = alert.buttons["OK"]
        XCTAssertTrue(okButton.exists, "OK button should exist in alert")
        okButton.tap()

        // Wait a moment for dismiss action
        sleep(1)

        // Then: Alert should disappear
        // BUG: This assertion FAILS because alert remains visible
        XCTAssertFalse(
            alert.exists,
            "🐛 BUG: Alert should be dismissed after tapping OK, but it remains visible"
        )

        // And: Recording screen should still be accessible (not frozen)
        XCTAssertTrue(recordButton.isHittable, "Record button should still be accessible")
    }

    /// Test that alert can be dismissed and shown again on subsequent attempts
    func testRecordingLimitAlert_canBeShownMultipleTimes() throws {
        // Given: User has dismissed the alert once
        let homeRecordButton = app.buttons["HomeRecordButton"]
        homeRecordButton.tap()

        let recordButton = app.buttons["StartRecordingButton"]
        recordButton.tap()

        let alert = app.alerts.firstMatch
        alert.buttons["OK"].tap()
        XCTAssertFalse(alert.exists, "Alert should be dismissed")

        // When: User taps Record button again
        recordButton.tap()

        // Then: Alert should appear again
        XCTAssertTrue(
            alert.waitForExistence(timeout: 5),
            "Alert should be shown again on second attempt"
        )

        // And: Can be dismissed again
        alert.buttons["OK"].tap()
        XCTAssertFalse(alert.exists, "Alert should be dismissed second time")
    }

    /// Test that free users can record and stop multiple times within limit
    func testFreeUser_canRecordMultipleTimes_withinLimit() throws {
        // Given: Free user with 0 recordings (within 100 daily limit)
        app.terminate()
        // Set subscription tier to free (to test free tier recording limit)
        app.launchEnvironment["SUBSCRIPTION_TIER"] = "free"
        // COMMENTED OUT: Testing without DAILY_RECORDING_COUNT to reproduce debug environment behavior
        // app.launchEnvironment["DAILY_RECORDING_COUNT"] = "0"
        app.launch()

        // Navigate to Recording screen
        let homeRecordButton = app.buttons["HomeRecordButton"]
        XCTAssertTrue(homeRecordButton.waitForExistence(timeout: 5), "Home record button should exist")
        homeRecordButton.tap()

        let recordButton = app.buttons["StartRecordingButton"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5), "Record button should exist")

        // When: User records and stops 7 times
        for iteration in 1...7 {
            print("🔴 ITERATION \(iteration): Starting recording")

            // Tap record button
            recordButton.tap()

            // Wait for countdown to complete
            sleep(4)  // 3 second countdown + buffer

            // Verify recording started
            let stopButton = app.buttons["StopRecordingButton"]
            XCTAssertTrue(
                stopButton.waitForExistence(timeout: 5),
                "Iteration \(iteration): Stop button should appear after countdown"
            )

            // Record for 1 second
            sleep(1)

            // Stop recording
            print("🔴 ITERATION \(iteration): Stopping recording")
            stopButton.tap()

            // Wait for recording to stop and return to idle state
            XCTAssertTrue(
                recordButton.waitForExistence(timeout: 5),
                "Iteration \(iteration): Record button should reappear after stopping"
            )

            // Verify no limit alert appeared
            let alert = app.alerts.firstMatch
            XCTAssertFalse(
                alert.exists,
                "Iteration \(iteration): Free user within limit should NOT see recording limit alert"
            )

            print("✅ ITERATION \(iteration): Completed successfully")

            // Small delay between iterations
            sleep(1)
        }

        // Then: All 7 recordings completed successfully without any limit alerts
        print("✅ ALL ITERATIONS COMPLETED: Free user recorded 7 times within daily limit (100)")
    }
}
