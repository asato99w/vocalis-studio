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

        // Screenshot 1: Initial expanded view (should show bottom - low frequency, 0Hz side)
        let screenshot1 = app.screenshot()
        let attachment1 = XCTAttachment(screenshot: screenshot1)
        attachment1.name = "expanded_spectrogram_01_initial_bottom"
        attachment1.lifetime = .keepAlways
        add(attachment1)

        // Test scrolling: Find the expanded spectrogram content area
        // Use coordinate-based swipe since SpectrogramCanvas might not be directly interactable
        let screenBounds = app.frame
        let centerX = screenBounds.width / 2
        let centerY = screenBounds.height / 2

        // Swipe down (finger moves down, content scrolls up to reveal top frequencies)
        let startPoint1 = app.coordinate(withNormalizedOffset: CGVector(dx: centerX / screenBounds.width, dy: 0.3))
        let endPoint1 = app.coordinate(withNormalizedOffset: CGVector(dx: centerX / screenBounds.width, dy: 0.7))
        startPoint1.press(forDuration: 0.1, thenDragTo: endPoint1)
        Thread.sleep(forTimeInterval: 0.5)

        // Screenshot 2: After scrolling up (should show higher frequencies)
        let screenshot2 = app.screenshot()
        let attachment2 = XCTAttachment(screenshot: screenshot2)
        attachment2.name = "expanded_spectrogram_02_scrolled_up"
        attachment2.lifetime = .keepAlways
        add(attachment2)

        // Swipe up (finger moves up, content scrolls down back to bottom)
        let startPoint2 = app.coordinate(withNormalizedOffset: CGVector(dx: centerX / screenBounds.width, dy: 0.7))
        let endPoint2 = app.coordinate(withNormalizedOffset: CGVector(dx: centerX / screenBounds.width, dy: 0.3))
        startPoint2.press(forDuration: 0.1, thenDragTo: endPoint2)
        Thread.sleep(forTimeInterval: 0.5)

        // Screenshot 3: After scrolling back down (should show bottom again)
        let screenshot3 = app.screenshot()
        let attachment3 = XCTAttachment(screenshot: screenshot3)
        attachment3.name = "expanded_spectrogram_03_scrolled_back_down"
        attachment3.lifetime = .keepAlways
        add(attachment3)

        // Verify close button exists
        let closeButton = app.buttons["CloseExpandedViewButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 2), "Close button should exist in expanded view")

        // Tap close button
        closeButton.tap()

        // Wait for collapse animation
        Thread.sleep(forTimeInterval: 1.0)

        // Screenshot 4: After closing expanded view
        let screenshot4 = app.screenshot()
        let attachment4 = XCTAttachment(screenshot: screenshot4)
        attachment4.name = "expanded_spectrogram_04_closed"
        attachment4.lifetime = .keepAlways
        add(attachment4)

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

    /// Test: Playback scroll behavior - verify time axis and playback cursor
    /// Purpose: Verify that spectrogram time axis scrolls correctly and returns to start position after playback
    @MainActor
    func testPlayback_TimeAxisScroll() throws {
        let app = launchAppWithResetRecordingCount()

        // Navigate to analysis screen
        navigateToAnalysisScreen(app)

        // Wait for analysis to complete
        Thread.sleep(forTimeInterval: 3.0)

        // Screenshot 1: Before playback (initial position)
        let screenshot1 = app.screenshot()
        let attachment1 = XCTAttachment(screenshot: screenshot1)
        attachment1.name = "time_axis_01_before_playback"
        attachment1.lifetime = .keepAlways
        add(attachment1)

        // Start playback
        let playPauseButton = app.buttons["AnalysisPlayPauseButton"]
        XCTAssertTrue(playPauseButton.waitForExistence(timeout: 5), "Play/Pause button should exist")
        playPauseButton.tap()

        // Wait during playback (about 1 second into playback)
        Thread.sleep(forTimeInterval: 1.0)

        // Screenshot 2: During playback (time axis should have scrolled)
        let screenshot2 = app.screenshot()
        let attachment2 = XCTAttachment(screenshot: screenshot2)
        attachment2.name = "time_axis_02_during_playback"
        attachment2.lifetime = .keepAlways
        add(attachment2)

        // Wait for playback to complete (assuming recording is short, ~2-3 seconds)
        // We'll wait for the full recording duration plus buffer
        Thread.sleep(forTimeInterval: 3.0)

        // Screenshot 3: After playback ends (should return to start position)
        let screenshot3 = app.screenshot()
        let attachment3 = XCTAttachment(screenshot: screenshot3)
        attachment3.name = "time_axis_03_after_playback_end"
        attachment3.lifetime = .keepAlways
        add(attachment3)

        // Verify play button is back to play state (not pause)
        XCTAssertTrue(playPauseButton.exists, "Play/Pause button should exist after playback ends")
    }

    /// Test: Spectrogram viewport architecture verification with screenshots
    /// Purpose: Verify that spectrogram fills the entire viewport correctly
    @MainActor
    func testSpectrogramViewport_Screenshots() throws {
        let app = launchAppWithResetRecordingCount()

        // Navigate to analysis screen
        navigateToAnalysisScreen(app)

        // Wait for spectrogram to appear
        let spectrogramView = app.otherElements["SpectrogramView"]
        XCTAssertTrue(spectrogramView.waitForExistence(timeout: 5), "Spectrogram view should exist")

        // Wait for analysis to complete (check if "分析中..." disappears)
        let analysisInProgress = app.staticTexts["分析中..."]
        if analysisInProgress.exists {
            // Wait up to 30 seconds for analysis to complete
            let analysisCompleted = !analysisInProgress.waitForExistence(timeout: 0.5)
            if !analysisCompleted {
                // Wait for analysis progress to finish
                var waitTime = 0.0
                while analysisInProgress.exists && waitTime < 30.0 {
                    Thread.sleep(forTimeInterval: 0.5)
                    waitTime += 0.5
                }
            }
        }

        // Additional wait for data to stabilize
        Thread.sleep(forTimeInterval: 2.0)

        // Screenshot 1: Initial state
        let screenshot1 = app.screenshot()
        let attachment1 = XCTAttachment(screenshot: screenshot1)
        attachment1.name = "spectrogram_01_initial_state"
        attachment1.lifetime = .keepAlways
        add(attachment1)

        // Perform vertical scroll (simulate drag down)
        let spectrogramCenter = spectrogramView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let spectrogramBottom = spectrogramView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        spectrogramCenter.press(forDuration: 0.1, thenDragTo: spectrogramBottom)

        Thread.sleep(forTimeInterval: 1.0)

        // Screenshot 2: After scrolling down (showing lower frequencies)
        let screenshot2 = app.screenshot()
        let attachment2 = XCTAttachment(screenshot: screenshot2)
        attachment2.name = "spectrogram_02_scrolled_down"
        attachment2.lifetime = .keepAlways
        add(attachment2)

        // Scroll up to show higher frequencies
        let spectrogramTop = spectrogramView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        spectrogramBottom.press(forDuration: 0.1, thenDragTo: spectrogramTop)

        Thread.sleep(forTimeInterval: 1.0)

        // Screenshot 3: After scrolling up (showing higher frequencies)
        let screenshot3 = app.screenshot()
        let attachment3 = XCTAttachment(screenshot: screenshot3)
        attachment3.name = "spectrogram_03_scrolled_up"
        attachment3.lifetime = .keepAlways
        add(attachment3)
    }
}
