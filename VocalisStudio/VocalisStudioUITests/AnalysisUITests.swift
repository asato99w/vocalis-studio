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

        // Wait for recording to start by checking StopButton appearance
        let stopButton = app.buttons["StopRecordingButton"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 10), "Stop recording button should appear")

        // Continue recording for a moment to ensure valid audio data
        Thread.sleep(forTimeInterval: 1.0)

        stopButton.tap()

        // Wait for recording to be saved by checking PlayButton appearance
        let playButton = app.buttons["PlayLastRecordingButton"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 5), "Play button should appear after save")

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

    /// Test: Spectrogram expanded view display and close
    /// Expected: ~15 seconds execution time
    @MainActor
    func testSpectrogramExpandDisplay() throws {
        let app = launchAppWithResetRecordingCount()

        // Navigate to analysis screen (same setup as testAnalysisViewDisplay)
        navigateToAnalysisScreen(app)

        // Wait for analysis to complete
        Thread.sleep(forTimeInterval: 3.0)

        // Find and tap on spectrogram view
        let spectrogramView = app.otherElements["SpectrogramView"]
        XCTAssertTrue(spectrogramView.waitForExistence(timeout: 5), "Spectrogram view should exist")

        // Tap on the spectrogram view to expand
        spectrogramView.tap()

        // Wait for expansion animation
        Thread.sleep(forTimeInterval: 1.0)

        // Screenshot: Expanded spectrogram view
        let screenshot1 = app.screenshot()
        let attachment1 = XCTAttachment(screenshot: screenshot1)
        attachment1.name = "expanded_spectrogram_01"
        attachment1.lifetime = .keepAlways
        add(attachment1)

        // Verify close button exists
        let closeButton = app.buttons["CloseExpandedViewButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 2), "Close button should exist in expanded view")

        // Tap close button
        closeButton.tap()

        // Wait for collapse animation
        Thread.sleep(forTimeInterval: 1.0)

        // Screenshot: After closing expanded view
        let screenshot2 = app.screenshot()
        let attachment2 = XCTAttachment(screenshot: screenshot2)
        attachment2.name = "expanded_spectrogram_02_closed"
        attachment2.lifetime = .keepAlways
        add(attachment2)

        // Verify we're back to normal view (spectrogram view should still exist)
        XCTAssertTrue(spectrogramView.exists, "Should be back to normal view")
    }

    /// Test: Pitch graph expanded view display and close
    /// Expected: ~15 seconds execution time
    @MainActor
    func testPitchGraphExpandDisplay() throws {
        let app = launchAppWithResetRecordingCount()

        // Navigate to analysis screen
        navigateToAnalysisScreen(app)

        // Wait for analysis to complete
        Thread.sleep(forTimeInterval: 3.0)

        // Find and tap on pitch analysis view
        let pitchAnalysisView = app.otherElements["PitchAnalysisView"]
        XCTAssertTrue(pitchAnalysisView.waitForExistence(timeout: 5), "Pitch analysis view should exist")

        // Tap on the pitch analysis view to expand
        pitchAnalysisView.tap()

        // Wait for expansion animation
        Thread.sleep(forTimeInterval: 1.0)

        // Screenshot: Expanded pitch graph view
        let screenshot1 = app.screenshot()
        let attachment1 = XCTAttachment(screenshot: screenshot1)
        attachment1.name = "expanded_pitch_graph_01"
        attachment1.lifetime = .keepAlways
        add(attachment1)

        // Verify close button exists
        let closeButton = app.buttons["CloseExpandedViewButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 2), "Close button should exist in expanded view")

        // Tap close button
        closeButton.tap()

        // Wait for collapse animation
        Thread.sleep(forTimeInterval: 1.0)

        // Screenshot: After closing expanded view
        let screenshot2 = app.screenshot()
        let attachment2 = XCTAttachment(screenshot: screenshot2)
        attachment2.name = "expanded_pitch_graph_02_closed"
        attachment2.lifetime = .keepAlways
        add(attachment2)

        // Verify we're back to normal view
        XCTAssertTrue(pitchAnalysisView.exists, "Should be back to normal view")
    }

    /// Test: Playback control in expanded view
    /// Expected: ~15 seconds execution time
    @MainActor
    func testExpandedViewPlaybackControl() throws {
        let app = launchAppWithResetRecordingCount()

        // Navigate to analysis screen
        navigateToAnalysisScreen(app)

        // Wait for analysis to complete
        Thread.sleep(forTimeInterval: 3.0)

        // Expand pitch analysis view
        let pitchAnalysisView = app.otherElements["PitchAnalysisView"]
        XCTAssertTrue(pitchAnalysisView.waitForExistence(timeout: 5), "Pitch analysis view should exist")
        pitchAnalysisView.tap()

        // Wait for expansion animation
        Thread.sleep(forTimeInterval: 1.0)

        // Find and tap play button in compact control
        let playButton = app.buttons["ExpandedAnalysisPlayPauseButton"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 2), "Play button should exist in expanded view")

        playButton.tap()

        // Wait for playback to start
        Thread.sleep(forTimeInterval: 1.0)

        // Screenshot: Playback in expanded view
        let screenshot1 = app.screenshot()
        let attachment1 = XCTAttachment(screenshot: screenshot1)
        attachment1.name = "expanded_playback_01_playing"
        attachment1.lifetime = .keepAlways
        add(attachment1)

        // Verify button still exists (state changed to pause)
        XCTAssertTrue(playButton.exists, "Play/Pause button should still exist during playback")

        // Tap to pause
        playButton.tap()
        Thread.sleep(forTimeInterval: 0.5)

        // Screenshot: Paused in expanded view
        let screenshot2 = app.screenshot()
        let attachment2 = XCTAttachment(screenshot: screenshot2)
        attachment2.name = "expanded_playback_02_paused"
        attachment2.lifetime = .keepAlways
        add(attachment2)

        // Close expanded view
        let closeButton = app.buttons["CloseExpandedViewButton"]
        XCTAssertTrue(closeButton.exists, "Close button should exist")
        closeButton.tap()
        Thread.sleep(forTimeInterval: 1.0)
    }

    // MARK: - Helper Methods

    /// Navigate to analysis screen by creating a recording and navigating to it
    private func navigateToAnalysisScreen(_ app: XCUIApplication) {
        // 1. Create a recording
        let homeRecordButton = app.buttons["HomeRecordButton"]
        XCTAssertTrue(homeRecordButton.waitForExistence(timeout: 5), "Home record button should exist")
        homeRecordButton.tap()

        let startButton = app.buttons["StartRecordingButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Start recording button should exist")
        startButton.tap()

        let stopButton = app.buttons["StopRecordingButton"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 10), "Stop recording button should appear")

        Thread.sleep(forTimeInterval: 1.0)
        stopButton.tap()

        let playButton = app.buttons["PlayLastRecordingButton"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 5), "Play button should appear after save")

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

        Thread.sleep(forTimeInterval: 2.0)
    }
}
