//
//  PlaybackUITests.swift
//  VocalisStudioUITests
//
//  UI tests for playback functionality
//

import XCTest

final class PlaybackUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Test 4: Full playback completion (natural playback end)
    /// Expected: ~8 seconds execution time
    @MainActor
    func testPlaybackFullCompletion() throws {
        let app = launchAppWithResetRecordingCount()

        // 1. Create a short recording first
        let homeRecordButton = app.buttons["HomeRecordButton"]
        XCTAssertTrue(homeRecordButton.waitForExistence(timeout: 5), "Home record button should exist")
        homeRecordButton.tap()

        let startButton = app.buttons["StartRecordingButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Start recording button should exist")
        startButton.tap()

        // Wait for countdown and record for only 1 second (very short recording)
        Thread.sleep(forTimeInterval: 4.0)

        let stopButton = app.buttons["StopRecordingButton"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 2), "Stop recording button should appear")
        stopButton.tap()

        // Wait for recording to finish and be saved
        Thread.sleep(forTimeInterval: 2.0)

        // 2. Verify Play Last Recording button appears
        let playButton = app.buttons["PlayLastRecordingButton"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 5), "Play last recording button should appear after recording")

        // Screenshot: Before playback
        let screenshot1 = app.screenshot()
        let attachment1 = XCTAttachment(screenshot: screenshot1)
        attachment1.name = "playback_01_before_play"
        attachment1.lifetime = .keepAlways
        add(attachment1)

        // 3. Start playback
        playButton.tap()

        // Wait a moment for playback to start
        Thread.sleep(forTimeInterval: 0.5)

        // 4. Verify Stop Playback button appears (playback is in progress)
        let stopPlaybackButton = app.buttons["StopPlaybackButton"]
        XCTAssertTrue(stopPlaybackButton.waitForExistence(timeout: 3), "Stop playback button should appear during playback")

        // Screenshot: During playback
        let screenshot2 = app.screenshot()
        let attachment2 = XCTAttachment(screenshot: screenshot2)
        attachment2.name = "playback_02_during_playback"
        attachment2.lifetime = .keepAlways
        add(attachment2)

        // 5. Wait for playback to complete naturally (recording was ~1 second)
        // Give enough time for the short recording to finish playing
        Thread.sleep(forTimeInterval: 3.0)

        // 6. Verify Play button reappears after playback completion
        XCTAssertTrue(playButton.waitForExistence(timeout: 3), "Play last recording button should reappear after playback completes")

        // Screenshot: After playback completion
        let screenshot3 = app.screenshot()
        let attachment3 = XCTAttachment(screenshot: screenshot3)
        attachment3.name = "playback_03_after_completion"
        attachment3.lifetime = .keepAlways
        add(attachment3)
    }

    /// Test: Target pitch should disappear after stopping playback
    /// Verifies that target pitch indicator is cleared when playback is manually stopped
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
