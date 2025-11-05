import XCTest

/// UI tests for recording limit and paywall functionality
final class RecordingLimitUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // Use standard UI test launch arguments for compatibility
        app.launchArguments = ["-UITestResetRecordingCount", "-UITestDisableAnimations"]

        // Set free tier with limit reached
        app.launchEnvironment["SUBSCRIPTION_TIER"] = "free"
        app.launchEnvironment["DAILY_RECORDING_COUNT"] = "5"  // At limit for free tier

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

    /// Test that user can interact with UI after dismissing limit alert
    func testRecordingScreen_shouldBeInteractive_afterDismissingLimitAlert() throws {
        // Given: User has dismissed the recording limit alert
        let homeRecordButton = app.buttons["HomeRecordButton"]
        homeRecordButton.tap()

        let recordButton = app.buttons["StartRecordingButton"]
        recordButton.tap()

        let alert = app.alerts.firstMatch
        alert.buttons["OK"].tap()

        // Wait for alert to fully dismiss
        XCTAssertFalse(alert.exists, "Alert should be fully dismissed")

        // When: User tries to navigate to other tabs
        let analysisTab = app.tabBars.buttons["analysis.title"]
        XCTAssertTrue(analysisTab.exists, "Analysis tab should be accessible")
        analysisTab.tap()

        // Then: Navigation should work normally
        let analysisView = app.staticTexts["analysis.title"]
        XCTAssertTrue(
            analysisView.waitForExistence(timeout: 5),
            "Should navigate to Analysis screen successfully"
        )
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
}
