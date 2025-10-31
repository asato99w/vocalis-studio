//
//  VocalisStudioUITests.swift
//  VocalisStudioUITests
//
//  Created by KAZU ASATO on 2025/09/28.
//
//  NOTE: These XCUITest-based tests are deprecated and replaced with ViewInspector-based tests
//  in VocalisStudioTests/Presentation/Views/Debug/DebugMenuViewTests.swift
//
//  ViewInspector advantages:
//  - Direct access to ViewModel state (no UI element searching)
//  - 10-100x faster execution (0.2-0.3s vs 2-5s)
//  - More reliable (no dependency on accessibility identifiers)
//  - Better testability (can verify internal state changes)
//

import XCTest

final class VocalisStudioUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it's important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    /// Helper to launch app with recording count reset for UI tests
    func launchAppWithResetRecordingCount() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetRecordingCount"]
        app.launch()
        return app
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    // MARK: - Debug Tier Persistence Tests

    @MainActor
    func testDebugTierPersistsAcrossNavigation() throws {
        let app = XCUIApplication()
        app.launch()

        // 1. Open debug menu
        let debugButton = app.buttons["Debug"]
        XCTAssertTrue(debugButton.waitForExistence(timeout: 5), "Debug button should exist")
        debugButton.tap()

        // 2. Wait for debug menu to appear
        let debugMenuTitle = app.navigationBars["Debug Menu"]
        XCTAssertTrue(debugMenuTitle.waitForExistence(timeout: 5), "Debug Menu should appear")

        // 3. Select Premium tier
        let premiumButton = app.buttons["Premium"]
        XCTAssertTrue(premiumButton.waitForExistence(timeout: 5), "Premium button should exist")
        premiumButton.tap()

        // 4. Verify Premium is selected by checking the label
        let selectedLabel = app.staticTexts["SelectedTierLabel"]
        XCTAssertTrue(selectedLabel.waitForExistence(timeout: 5), "Selected tier label should exist")
        XCTAssertTrue(selectedLabel.label.contains("Premium"), "Premium should be selected")

        // 5. Navigate back to home
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        backButton.tap()

        // 6. Wait for home screen
        XCTAssertTrue(debugButton.waitForExistence(timeout: 5), "Should return to home screen")

        // 7. Re-open debug menu
        debugButton.tap()

        // 8. Verify debug menu appears again
        XCTAssertTrue(debugMenuTitle.waitForExistence(timeout: 5), "Debug Menu should appear again")

        // 9. Verify Premium tier is still selected by checking the label
        let selectedLabelAgain = app.staticTexts["SelectedTierLabel"]
        XCTAssertTrue(selectedLabelAgain.waitForExistence(timeout: 5), "Selected tier label should exist again")
        XCTAssertTrue(selectedLabelAgain.label.contains("Premium"), "Premium tier should persist after navigation")
    }

    @MainActor
    func testDebugTierChangeFromPremiumToFree() throws {
        let app = XCUIApplication()
        app.launch()

        // 1. Open debug menu
        let debugButton = app.buttons["Debug"]
        debugButton.tap()

        // 2. Select Premium
        let premiumButton = app.buttons["Premium"]
        XCTAssertTrue(premiumButton.waitForExistence(timeout: 5))
        premiumButton.tap()

        // Verify Premium is selected
        let selectedLabel = app.staticTexts["SelectedTierLabel"]
        XCTAssertTrue(selectedLabel.waitForExistence(timeout: 5))
        XCTAssertTrue(selectedLabel.label.contains("Premium"))

        // 3. Navigate back
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // 4. Re-open debug menu
        debugButton.tap()

        // 5. Change to Free
        let freeButton = app.buttons["Free"]
        XCTAssertTrue(freeButton.waitForExistence(timeout: 5))
        freeButton.tap()

        // Verify Free is selected
        XCTAssertTrue(selectedLabel.waitForExistence(timeout: 5))
        XCTAssertTrue(selectedLabel.label.contains("Free"))

        // 6. Navigate back
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // 7. Re-open debug menu
        debugButton.tap()

        // 8. Verify Free is still selected
        XCTAssertTrue(selectedLabel.waitForExistence(timeout: 5))
        XCTAssertTrue(selectedLabel.label.contains("Free"), "Free tier should persist after navigation")
    }

    @MainActor
    func testDebugTierPremiumPlusPersistence() throws {
        let app = XCUIApplication()
        app.launch()

        // 1. Open debug menu
        let debugButton = app.buttons["Debug"]
        debugButton.tap()

        // 2. Select Premium Plus
        let premiumPlusButton = app.buttons["Premium Plus"]
        XCTAssertTrue(premiumPlusButton.waitForExistence(timeout: 5))
        premiumPlusButton.tap()

        // Verify Premium Plus is selected
        let selectedLabel = app.staticTexts["SelectedTierLabel"]
        XCTAssertTrue(selectedLabel.waitForExistence(timeout: 5))
        XCTAssertTrue(selectedLabel.label.contains("Premium Plus"))

        // 3. Navigate back and forth multiple times
        for _ in 0..<3 {
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(debugButton.waitForExistence(timeout: 5))
            debugButton.tap()
        }

        // 4. Verify Premium Plus is still selected after multiple navigations
        XCTAssertTrue(selectedLabel.waitForExistence(timeout: 5))
        XCTAssertTrue(selectedLabel.label.contains("Premium Plus"), "Premium Plus should persist after multiple navigations")
    }

    // MARK: - Recording Playback Tests

    @MainActor
    func testTargetPitchShouldDisappearAfterStoppingPlayback() throws {
        let app = launchAppWithResetRecordingCount()

        // 1. Navigate to Recording screen from Home
        let homeRecordButton = app.buttons["HomeRecordButton"]
        XCTAssertTrue(homeRecordButton.waitForExistence(timeout: 5), "Home record button should exist")
        homeRecordButton.tap()

        // 2. Wait for recording screen to load
        let startButton = app.buttons["StartRecordingButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Start recording button should exist")

        // Wait for view to fully initialize with settings
        Thread.sleep(forTimeInterval: 1.0)

        // 📸 Screenshot 1: Initial recording screen
        let screenshot1 = app.screenshot()
        let attachment1 = XCTAttachment(screenshot: screenshot1)
        attachment1.name = "01_initial_recording_screen"
        attachment1.lifetime = .keepAlways
        add(attachment1)

        // 3. Start recording
        startButton.tap()

        // 4. Wait for countdown (3 seconds) + some recording time (2 seconds)
        Thread.sleep(forTimeInterval: 5.0)

        // 📸 Screenshot 2: During recording
        let screenshot2 = app.screenshot()
        let attachment2 = XCTAttachment(screenshot: screenshot2)
        attachment2.name = "02_during_recording"
        attachment2.lifetime = .keepAlways
        add(attachment2)

        // 5. Stop recording
        let stopButton = app.buttons["StopRecordingButton"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5), "Stop recording button should appear during recording")
        stopButton.tap()

        // 6. Wait for recording to finish processing
        Thread.sleep(forTimeInterval: 1.0)

        // 📸 Screenshot 3: After recording stopped
        let screenshot3 = app.screenshot()
        let attachment3 = XCTAttachment(screenshot: screenshot3)
        attachment3.name = "03_after_recording_stopped"
        attachment3.lifetime = .keepAlways
        add(attachment3)

        // 7. Verify Play Last Recording button appears
        let playButton = app.buttons["PlayLastRecordingButton"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 5), "Play last recording button should appear after recording")

        // 8. Play the last recording
        playButton.tap()

        // 9. Wait for playback to start and scale to load
        // Reduced from 2.0 to 0.5 seconds to avoid playback finishing before we can stop it
        // (recordings are only ~2s long, so 2s wait + 2s waitForExistence can exceed playback duration)
        Thread.sleep(forTimeInterval: 0.5)

        // 📸 Screenshot 4: During playback (should show target pitch)
        let screenshot4 = app.screenshot()
        let attachment4 = XCTAttachment(screenshot: screenshot4)
        attachment4.name = "04_during_playback"
        attachment4.lifetime = .keepAlways
        add(attachment4)

        // 10. Verify target pitch is displayed during playback
        let targetPitchNoteName = app.staticTexts["TargetPitchNoteName"]
        XCTAssertTrue(targetPitchNoteName.waitForExistence(timeout: 5), "Target pitch should be displayed during playback")

        // 11. Stop playback (immediately tap without waitForExistence to avoid timing issue)
        let stopPlaybackButton = app.buttons["StopPlaybackButton"]
        // Verify button exists first
        XCTAssertTrue(stopPlaybackButton.waitForExistence(timeout: 2), "Stop playback button should appear")
        // Immediately tap without additional waiting to avoid playback finishing naturally
        // Note: Short recordings (~2s) can finish during waitForExistence, making button disappear before tap
        if stopPlaybackButton.exists {
            stopPlaybackButton.tap()
        } else {
            XCTFail("StopPlaybackButton disappeared between waitForExistence and tap - playback likely finished naturally")
        }

        // 12. Wait for playback to stop
        Thread.sleep(forTimeInterval: 0.5)

        // 📸 Screenshot 5: After playback stopped (BUG CHECK - should show '--')
        let screenshot5 = app.screenshot()
        let attachment5 = XCTAttachment(screenshot: screenshot5)
        attachment5.name = "05_after_playback_stopped_BUG_CHECK"
        attachment5.lifetime = .keepAlways
        add(attachment5)

        // 13. 🔴 BUG CHECK: Verify target pitch DISAPPEARS after stopping playback
        let targetPitchEmpty = app.staticTexts["TargetPitchEmpty"]
        XCTAssertTrue(
            targetPitchEmpty.waitForExistence(timeout: 2),
            "Target pitch should disappear (show '--') after stopping playback. BUG: Target pitch continues to be displayed."
        )

        // Alternative check: Target pitch note name should NOT exist
        XCTAssertFalse(
            targetPitchNoteName.exists,
            "Target pitch note name should not exist after stopping playback. BUG: Target pitch continues to be displayed."
        )
    }
}
