//
//  NavigationUITests.swift
//  VocalisStudioUITests
//
//  UI tests for navigation and multi-recording scenarios
//

import XCTest

final class NavigationUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Test: Multiple recordings creation and management
    /// Expected: ~20 seconds execution time
    @MainActor
    func testMultipleRecordings() throws {
        let app = launchAppWithResetRecordingCount()

        // 1. Create first recording
        let homeRecordButton = app.buttons["HomeRecordButton"]
        XCTAssertTrue(homeRecordButton.waitForExistence(timeout: 5), "Home record button should exist")
        homeRecordButton.tap()

        let startButton = app.buttons["StartRecordingButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Start recording button should exist")
        startButton.tap()

        // Wait for countdown and short recording (~2 seconds)
        Thread.sleep(forTimeInterval: 5.0)

        let stopButton = app.buttons["StopRecordingButton"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 2), "Stop recording button should appear")
        stopButton.tap()

        // Wait for recording to be saved
        Thread.sleep(forTimeInterval: 2.0)

        // 2. Navigate back to Home and create second recording
        app.navigationBars.buttons.element(boundBy: 0).tap()
        Thread.sleep(forTimeInterval: 0.5)

        homeRecordButton.tap()
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Start recording button should exist for second recording")
        startButton.tap()

        // Wait for countdown and short recording (~2 seconds)
        Thread.sleep(forTimeInterval: 5.0)

        XCTAssertTrue(stopButton.waitForExistence(timeout: 2), "Stop recording button should appear for second recording")
        stopButton.tap()

        // Wait for second recording to be saved
        Thread.sleep(forTimeInterval: 2.0)

        // 3. Navigate to Recording List
        app.navigationBars.buttons.element(boundBy: 0).tap()
        Thread.sleep(forTimeInterval: 0.5)

        let homeListButton = app.buttons["HomeListButton"]
        XCTAssertTrue(homeListButton.waitForExistence(timeout: 5), "Home list button should exist")
        homeListButton.tap()

        Thread.sleep(forTimeInterval: 2.0)

        // Screenshot: Recording list with multiple recordings
        let screenshot1 = app.screenshot()
        let attachment1 = XCTAttachment(screenshot: screenshot1)
        attachment1.name = "multiple_01_recording_list"
        attachment1.lifetime = .keepAlways
        add(attachment1)

        // 4. Verify both recordings are displayed
        let deleteButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "DeleteRecordingButton_"))
        let recordingCount = deleteButtons.count

        XCTAssertGreaterThanOrEqual(recordingCount, 2, "At least 2 recordings should be displayed in the list (found \(recordingCount))")

        // 5. Verify recordings are ordered correctly (most recent first)
        // Note: We can't easily verify the exact order in UI tests without specific timestamps,
        // but we can verify that multiple recordings are present and accessible
    }

    /// Test: Full navigation flow through the app
    /// Expected: ~15 seconds execution time
    @MainActor
    func testFullNavigationFlow() throws {
        let app = launchAppWithResetRecordingCount()

        // Screenshot: Home screen
        let screenshot1 = app.screenshot()
        let attachment1 = XCTAttachment(screenshot: screenshot1)
        attachment1.name = "nav_01_home_screen"
        attachment1.lifetime = .keepAlways
        add(attachment1)

        // 1. Home -> Recording screen
        let homeRecordButton = app.buttons["HomeRecordButton"]
        XCTAssertTrue(homeRecordButton.waitForExistence(timeout: 5), "Home record button should exist on Home screen")
        homeRecordButton.tap()

        Thread.sleep(forTimeInterval: 1.0)

        // Screenshot: Recording screen
        let screenshot2 = app.screenshot()
        let attachment2 = XCTAttachment(screenshot: screenshot2)
        attachment2.name = "nav_02_recording_screen"
        attachment2.lifetime = .keepAlways
        add(attachment2)

        // Verify Recording screen elements
        let startButton = app.buttons["StartRecordingButton"]
        XCTAssertTrue(startButton.exists, "Start recording button should exist on Recording screen")

        // 2. Recording -> back to Home
        app.navigationBars.buttons.element(boundBy: 0).tap()
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertTrue(homeRecordButton.exists, "Should be back at Home screen")

        // 3. Home -> Recording List screen
        let homeListButton = app.buttons["HomeListButton"]
        XCTAssertTrue(homeListButton.waitForExistence(timeout: 5), "Home list button should exist")
        homeListButton.tap()

        Thread.sleep(forTimeInterval: 1.0)

        // Screenshot: Recording List screen
        let screenshot3 = app.screenshot()
        let attachment3 = XCTAttachment(screenshot: screenshot3)
        attachment3.name = "nav_03_recording_list_screen"
        attachment3.lifetime = .keepAlways
        add(attachment3)

        // Verify Recording List screen (may show empty state)
        // Check navigation title or other unique elements
        XCTAssertTrue(app.navigationBars.staticTexts.element(matching: NSPredicate(format: "label CONTAINS[c] %@", "録音")).exists,
                     "Recording List navigation title should be visible")

        // 4. Recording List -> back to Home
        app.navigationBars.buttons.element(boundBy: 0).tap()
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertTrue(homeRecordButton.exists, "Should be back at Home screen from Recording List")

        // 5. Home -> Settings screen
        let homeSettingsButton = app.buttons["HomeSettingsButton"]
        XCTAssertTrue(homeSettingsButton.waitForExistence(timeout: 5), "Home settings button should exist")
        homeSettingsButton.tap()

        Thread.sleep(forTimeInterval: 1.0)

        // Screenshot: Settings screen
        let screenshot4 = app.screenshot()
        let attachment4 = XCTAttachment(screenshot: screenshot4)
        attachment4.name = "nav_04_settings_screen"
        attachment4.lifetime = .keepAlways
        add(attachment4)

        // Verify Settings screen elements
        XCTAssertTrue(app.navigationBars.staticTexts.element(matching: NSPredicate(format: "label CONTAINS[c] %@", "設定")).exists ||
                     app.navigationBars.staticTexts.element(matching: NSPredicate(format: "label CONTAINS[c] %@", "Settings")).exists,
                     "Settings navigation title should be visible")

        // 6. Settings -> back to Home
        app.navigationBars.buttons.element(boundBy: 0).tap()
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertTrue(homeRecordButton.exists, "Should be back at Home screen from Settings")

        // Screenshot: Back to Home
        let screenshot5 = app.screenshot()
        let attachment5 = XCTAttachment(screenshot: screenshot5)
        attachment5.name = "nav_05_back_to_home"
        attachment5.lifetime = .keepAlways
        add(attachment5)
    }
}
