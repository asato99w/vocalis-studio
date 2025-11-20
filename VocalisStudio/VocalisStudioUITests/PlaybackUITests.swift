//
//  PlaybackUITests.swift
//  VocalisStudioUITests
//
//  UI tests for playback functionality
//

import XCTest

/// Playback UI tests
///
/// ⚠️ IMPORTANT: This test class contains pitch detection tests that require
/// speaker → microphone audio feedback loop in iOS Simulator. Due to AVAudioSession
/// limitations, these tests CANNOT run in parallel with other tests.
///
/// **Run these tests individually, not in parallel execution mode.**
///
/// Parallel execution issue:
/// - When 5 simulator clones run simultaneously, AVAudioSession conflicts occur
/// - Speaker output → Microphone input feedback loop fails
/// - Pitch detection tests fail even though the implementation is correct
///
/// Verified working:
/// - Single test execution: ✅ PASS
/// - Parallel execution (5 clones): ❌ FAIL (expected)
///
/// Usage:
/// ```bash
/// # Run this test class individually
/// xcodebuild test -only-testing:VocalisStudioUITests/PlaybackUITests
/// ```
final class PlaybackUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Test 4: Full playback completion (natural playback end)
    /// Expected: ~8 seconds execution time
    func testPlaybackFullCompletion() throws {
        let app = launchAppWithResetRecordingCount()

        // 1. Create a short recording first
        let homeRecordButton = app.buttons["HomeRecordButton"]
        XCTAssertTrue(homeRecordButton.waitForExistence(timeout: 5), "Home record button should exist")
        homeRecordButton.tap()

        let startButton = app.buttons["StartRecordingButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Start recording button should exist")
        startButton.tap()

        // Wait for recording to start by checking StopButton appearance
        let stopButton = app.buttons["StopRecordingButton"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 10), "Stop recording button should appear")

        // Continue recording for playback verification
        // 3 seconds needed to allow playback initialization (2s) + buffer for verification
        Thread.sleep(forTimeInterval: 3.0)

        stopButton.tap()

        // Wait for recording to finish and be saved by checking PlayButton appearance
        let playButton = app.buttons["PlayLastRecordingButton"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 5), "Play button should appear after save")

        // Screenshot: Before playback
        let screenshot1 = app.screenshot()
        let attachment1 = XCTAttachment(screenshot: screenshot1)
        attachment1.name = "playback_01_before_play"
        attachment1.lifetime = .keepAlways
        add(attachment1)

        // 3. Start playback
        playButton.tap()

        // Wait for playback to start and scale playback to initialize
        // Note: Playback with scale requires initialization time
        Thread.sleep(forTimeInterval: 2.0)

        // 4. Verify Stop Playback button appears (playback is in progress)
        let stopPlaybackButton = app.buttons["StopPlaybackButton"]
        XCTAssertTrue(stopPlaybackButton.waitForExistence(timeout: 2), "Stop playback button should appear during playback")

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
    func testTargetPitchShouldDisappearAfterStoppingPlayback() throws {
        let app = launchAppWithResetRecordingCount()

        // 1. Navigate to Recording screen from Home
        let homeRecordButton = app.buttons["HomeRecordButton"]
        XCTAssertTrue(homeRecordButton.waitForExistence(timeout: 5), "Home record button should exist")
        homeRecordButton.tap()

        // 2. Wait for recording screen to load
        let startButton = app.buttons["StartRecordingButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Start recording button should exist")

        // 📸 Screenshot 1: Initial recording screen
        let screenshot1 = app.screenshot()
        let attachment1 = XCTAttachment(screenshot: screenshot1)
        attachment1.name = "01_initial_recording_screen"
        attachment1.lifetime = .keepAlways
        add(attachment1)

        // 3. Start recording
        startButton.tap()

        // 4. Wait for recording to start by checking StopButton appearance
        let stopButton = app.buttons["StopRecordingButton"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 10), "Stop recording button should appear during recording")

        // Continue recording for playback verification
        // 3 seconds needed to allow playback initialization (2s) + buffer for verification
        Thread.sleep(forTimeInterval: 3.0)

        // 📸 Screenshot 2: During recording
        let screenshot2 = app.screenshot()
        let attachment2 = XCTAttachment(screenshot: screenshot2)
        attachment2.name = "02_during_recording"
        attachment2.lifetime = .keepAlways
        add(attachment2)

        // 5. Stop recording
        stopButton.tap()

        // 6. Wait for recording to finish processing by checking PlayButton appearance
        let playButton = app.buttons["PlayLastRecordingButton"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 5), "Play button should appear after save")

        // 📸 Screenshot 3: After recording stopped
        let screenshot3 = app.screenshot()
        let attachment3 = XCTAttachment(screenshot: screenshot3)
        attachment3.name = "03_after_recording_stopped"
        attachment3.lifetime = .keepAlways
        add(attachment3)

        // 8. Play the last recording
        playButton.tap()

        // 9. Wait for playback to start, scale to load, and target pitch monitoring to begin
        // Note: Playback with scale requires:
        // - Audio player initialization
        // - Muted scale playback startup
        // - Target pitch monitoring startup
        // Need enough time for these to complete, but not so long that playback finishes
        Thread.sleep(forTimeInterval: 2.0)

        // 📸 Screenshot 4: During playback (should show target pitch)
        let screenshot4 = app.screenshot()
        let attachment4 = XCTAttachment(screenshot: screenshot4)
        attachment4.name = "04_during_playback"
        attachment4.lifetime = .keepAlways
        add(attachment4)

        // 10. Verify target pitch is displayed during playback
        let targetPitchNoteName = app.staticTexts["TargetPitchNoteName"]
        XCTAssertTrue(targetPitchNoteName.waitForExistence(timeout: 3), "Target pitch should be displayed during playback")

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

        // 12. Wait for playback to stop by checking play button reappears
        XCTAssertTrue(playButton.waitForExistence(timeout: 3), "Play button should reappear after stopping playback")

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

    /// Phase 1 Test: Pitch detection during scale-enabled recording in iOS Simulator
    ///
    /// Test Environment Considerations:
    /// - iOS Simulator: AVAudioRecorder and AVAudioEngine compete for mic input
    /// - This causes reduced RMS values (~0.008) even when audio is present
    /// - Test uses lowered RMS threshold (0.005) configured in DependencyContainer
    /// - Production code uses default threshold (0.02) for real device conditions
    ///
    /// Test Objective:
    /// Verifies that pitch detection can work in simulator's constrained environment
    /// when appropriate threshold is configured. Does not check pitch accuracy.
    ///
    /// Expected: This test should FAIL (RED) if pitch detection is broken
    func testScaleRecordingShouldDetectPitch() throws {
        let app = launchAppWithResetRecordingCount()

        // 1. Navigate to Recording screen from Home
        let homeRecordButton = app.buttons["HomeRecordButton"]
        XCTAssertTrue(homeRecordButton.waitForExistence(timeout: 5), "Home record button should exist")
        homeRecordButton.tap()

        // 2. Wait for recording screen to load
        let startButton = app.buttons["StartRecordingButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Start recording button should exist")

        // 📸 Screenshot 1: Initial recording screen
        let screenshot1 = app.screenshot()
        let attachment1 = XCTAttachment(screenshot: screenshot1)
        attachment1.name = "pitch_detection_01_initial"
        attachment1.lifetime = .keepAlways
        add(attachment1)

        // 3. Start recording (scale is enabled by default)
        startButton.tap()

        // 4. Wait for recording to start
        let stopButton = app.buttons["StopRecordingButton"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 10), "Stop recording button should appear during recording")

        // 5. Wait for scale playback and pitch detection to stabilize
        // Note: This sleep will be optimized later using state-based waiting
        Thread.sleep(forTimeInterval: 3.0)

        // 📸 Screenshot 2: During recording with scale playback
        let screenshot2 = app.screenshot()
        let attachment2 = XCTAttachment(screenshot: screenshot2)
        attachment2.name = "pitch_detection_02_during_recording"
        attachment2.lifetime = .keepAlways
        add(attachment2)

        // 6. Verify that SOME pitch is detected
        // When scale is playing through speaker → microphone input → pitch detection should work
        let detectedPitchNoteName = app.staticTexts["DetectedPitchNoteName"]
        let detectedPitchEmpty = app.staticTexts["DetectedPitchEmpty"]

        XCTAssertTrue(
            detectedPitchNoteName.waitForExistence(timeout: 2),
            "🔴 RED: Detected pitch should show note name during scale playback. If this fails, pitch detection is broken."
        )

        XCTAssertFalse(
            detectedPitchEmpty.exists,
            "🔴 RED: Detected pitch should NOT show '--' or '...' when scale is playing. If this fails, pitch detection is not working."
        )

        // 7. Stop recording
        stopButton.tap()

        // Wait for recording to finish processing
        let playButton = app.buttons["PlayLastRecordingButton"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 5), "Play button should appear after save")

        // 📸 Screenshot 3: After recording stopped
        let screenshot3 = app.screenshot()
        let attachment3 = XCTAttachment(screenshot: screenshot3)
        attachment3.name = "pitch_detection_03_after_recording"
        attachment3.lifetime = .keepAlways
        add(attachment3)
    }
}
