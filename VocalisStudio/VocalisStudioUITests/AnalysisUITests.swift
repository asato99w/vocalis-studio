//
//  AnalysisUITests.swift
//  VocalisStudioUITests
//
//  UI tests for analysis screen functionality
//

import XCTest

final class AnalysisUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Test: Analysis view display and basic playback controls
    /// Expected: ~20 seconds execution time
    @MainActor
    func testAnalysisViewDisplay() throws {
        let app = launchAppWithResetRecordingCount()

        // 1. Create a recording first
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

        // 2. Navigate to Recording List
        app.navigationBars.buttons.element(boundBy: 0).tap()
        Thread.sleep(forTimeInterval: 0.5)

        let homeListButton = app.buttons["HomeListButton"]
        XCTAssertTrue(homeListButton.waitForExistence(timeout: 5), "Home list button should exist")
        homeListButton.tap()

        Thread.sleep(forTimeInterval: 2.0)

        // 3. Navigate to Analysis screen
        let analysisLinks = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "AnalysisNavigationLink_"))
        XCTAssertTrue(analysisLinks.firstMatch.waitForExistence(timeout: 5), "Analysis navigation link should exist")
        analysisLinks.firstMatch.tap()

        // Wait for analysis screen to load and analysis to start
        Thread.sleep(forTimeInterval: 2.0)

        // Screenshot: Analysis screen loading
        let screenshot1 = app.screenshot()
        let attachment1 = XCTAttachment(screenshot: screenshot1)
        attachment1.name = "analysis_01_initial_load"
        attachment1.lifetime = .keepAlways
        add(attachment1)

        // 4. Wait for analysis to complete (if loading indicator exists, wait for it to disappear)
        // Note: Analysis might be fast, so we give it time to complete
        Thread.sleep(forTimeInterval: 3.0)

        // Screenshot: Analysis screen after loading
        let screenshot2 = app.screenshot()
        let attachment2 = XCTAttachment(screenshot: screenshot2)
        attachment2.name = "analysis_02_after_loading"
        attachment2.lifetime = .keepAlways
        add(attachment2)

        // 5. Verify Recording Info Panel is displayed by checking its title text
        // Note: SwiftUI VStack accessibility identifiers may not work reliably, so we check for content instead
        let recordingInfoTitle = app.staticTexts["録音情報"]
        XCTAssertTrue(recordingInfoTitle.waitForExistence(timeout: 10), "Recording info panel title should be displayed")

        // 6. Verify Playback controls exist
        let playPauseButton = app.buttons["AnalysisPlayPauseButton"]
        XCTAssertTrue(playPauseButton.waitForExistence(timeout: 10), "Play/Pause button should exist")

        let seekBackButton = app.buttons["AnalysisSeekBackButton"]
        XCTAssertTrue(seekBackButton.waitForExistence(timeout: 3), "Seek back button should exist")

        let seekForwardButton = app.buttons["AnalysisSeekForwardButton"]
        XCTAssertTrue(seekForwardButton.waitForExistence(timeout: 3), "Seek forward button should exist")

        let progressSlider = app.sliders["AnalysisProgressSlider"]
        XCTAssertTrue(progressSlider.waitForExistence(timeout: 3), "Progress slider should exist")

        // 7. Test playback controls - Play
        playPauseButton.tap()

        // Wait a moment for playback to start
        Thread.sleep(forTimeInterval: 1.0)

        // Screenshot: During playback
        let screenshot3 = app.screenshot()
        let attachment3 = XCTAttachment(screenshot: screenshot3)
        attachment3.name = "analysis_03_during_playback"
        attachment3.lifetime = .keepAlways
        add(attachment3)

        // Verify button changed to pause state (still exists but may show different icon)
        XCTAssertTrue(playPauseButton.exists, "Play/Pause button should still exist during playback")

        // 8. Test playback controls - Pause
        playPauseButton.tap()

        Thread.sleep(forTimeInterval: 0.5)

        // Screenshot: After pause
        let screenshot4 = app.screenshot()
        let attachment4 = XCTAttachment(screenshot: screenshot4)
        attachment4.name = "analysis_04_after_pause"
        attachment4.lifetime = .keepAlways
        add(attachment4)

        // 9. Test seek controls
        seekBackButton.tap()
        Thread.sleep(forTimeInterval: 0.5)

        seekForwardButton.tap()
        Thread.sleep(forTimeInterval: 0.5)

        // Screenshot: After seek operations
        let screenshot5 = app.screenshot()
        let attachment5 = XCTAttachment(screenshot: screenshot5)
        attachment5.name = "analysis_05_after_seek"
        attachment5.lifetime = .keepAlways
        add(attachment5)

        // 10. Verify navigation back works
        app.navigationBars.buttons.element(boundBy: 0).tap()
        Thread.sleep(forTimeInterval: 0.5)

        // Should be back at Recording List
        let deleteButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "DeleteRecordingButton_"))
        XCTAssertTrue(deleteButtons.firstMatch.waitForExistence(timeout: 3), "Should be back at recording list")
    }
}
