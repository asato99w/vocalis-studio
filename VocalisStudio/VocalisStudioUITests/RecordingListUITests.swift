//
//  RecordingListUITests.swift
//  VocalisStudioUITests
//
//  UI tests for recording list (navigation, deletion)
//

import XCTest

final class RecordingListUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Test 2: Recording list navigation - create recording and navigate to list
    /// Expected: ~15 seconds execution time
    @MainActor
    func testRecordingListNavigation() throws {
        let app = launchAppWithResetRecordingCount()

        // 1. Create a recording first (same flow as testBasicRecordingFlow)
        let homeRecordButton = app.buttons["HomeRecordButton"]
        XCTAssertTrue(homeRecordButton.waitForExistence(timeout: 5), "Home record button should exist")
        homeRecordButton.tap()

        let startButton = app.buttons["StartRecordingButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Start recording button should exist")
        startButton.tap()

        // Wait for recording to start by checking StopButton appearance
        // No Thread.sleep needed - waitForExistence will wait for countdown + initialization
        let stopButton = app.buttons["StopRecordingButton"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 10), "Stop recording button should appear")

        // Continue recording for a moment to ensure valid audio data
        Thread.sleep(forTimeInterval: 1.0)

        stopButton.tap()

        // Wait for recording to finish and be saved by checking PlayButton appearance
        // No Thread.sleep needed - waitForExistence will wait for save completion
        let playButton = app.buttons["PlayLastRecordingButton"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 5), "Play last recording button should appear after recording")

        // 2. Navigate back to Home
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // 3. Navigate to Recording List screen
        let homeListButton = app.buttons["HomeListButton"]
        XCTAssertTrue(homeListButton.waitForExistence(timeout: 5), "Home list button should exist")
        homeListButton.tap()

        // 4. Verify recording appears in the list
        // Wait for list to load by checking for delete buttons

        // Screenshot: Recording list
        let screenshot1 = app.screenshot()
        let attachment1 = XCTAttachment(screenshot: screenshot1)
        attachment1.name = "list_nav_01_recording_list"
        attachment1.lifetime = .keepAlways
        add(attachment1)

        // Verify at least one recording exists in the list
        // Use prefix match for dynamic identifier that includes recording UUID
        let deleteButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "DeleteRecordingButton_"))
        XCTAssertTrue(deleteButtons.firstMatch.waitForExistence(timeout: 5), "At least one recording with delete button should exist in the list")

        // 5. Navigate to Analysis screen by tapping the analysis button
        let analysisLinks = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "AnalysisNavigationLink_"))
        XCTAssertTrue(analysisLinks.firstMatch.waitForExistence(timeout: 5), "Analysis navigation link should exist")
        analysisLinks.firstMatch.tap()

        // Wait for analysis screen to load by checking for analysis UI elements
        let analysisPlayButton = app.buttons["AnalysisPlayPauseButton"]
        XCTAssertTrue(analysisPlayButton.waitForExistence(timeout: 5), "Analysis play button should appear")

        // Screenshot: Analysis screen
        let screenshot2 = app.screenshot()
        let attachment2 = XCTAttachment(screenshot: screenshot2)
        attachment2.name = "list_nav_02_analysis_screen"
        attachment2.lifetime = .keepAlways
        add(attachment2)

        // 6. Navigate back to list using back button
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // Wait for list to reload by checking delete button visibility
        XCTAssertTrue(deleteButtons.firstMatch.waitForExistence(timeout: 3), "Delete button should reappear after navigation back")

        // Screenshot: Back to list
        let screenshot3 = app.screenshot()
        let attachment3 = XCTAttachment(screenshot: screenshot3)
        attachment3.name = "list_nav_03_back_to_list"
        attachment3.lifetime = .keepAlways
        add(attachment3)

        // Verify we're back at the list
        XCTAssertTrue(deleteButtons.firstMatch.waitForExistence(timeout: 3), "Should be back at recording list with delete button visible")
    }

    /// Test: Recording list shows scale name for scale recordings
    /// Expected: ~12 seconds execution time
    @MainActor
    func testRecordingListShowsScaleName() throws {
        let app = launchAppWithResetRecordingCount()

        // 1. Create a recording with scale (scale is enabled by default)
        let homeRecordButton = app.buttons["HomeRecordButton"]
        XCTAssertTrue(homeRecordButton.waitForExistence(timeout: 5), "Home record button should exist")
        homeRecordButton.tap()

        let startButton = app.buttons["StartRecordingButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Start recording button should exist")
        startButton.tap()

        // Wait for recording to start
        let stopButton = app.buttons["StopRecordingButton"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 10), "Stop recording button should appear")

        // Record for 1 second
        Thread.sleep(forTimeInterval: 1.0)

        stopButton.tap()

        // Wait for recording to finish
        let playButton = app.buttons["PlayLastRecordingButton"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 5), "Play button should appear after save")

        // 2. Navigate back to Home
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // 3. Navigate to Recording List
        let homeListButton = app.buttons["HomeListButton"]
        XCTAssertTrue(homeListButton.waitForExistence(timeout: 5), "Home list button should exist")
        homeListButton.tap()

        // Wait for list to load by checking for delete buttons
        let deleteButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "DeleteRecordingButton_"))
        XCTAssertTrue(deleteButtons.firstMatch.waitForExistence(timeout: 5), "Delete button should appear in list")

        // Screenshot: Recording list with scale name
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "scale_name_display"
        attachment.lifetime = .keepAlways
        add(attachment)

        // 4. Verify scale name is displayed (e.g., "C4 五声音階")
        // The scale name should contain the note name pattern and scale pattern name
        let scaleNameTexts = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "五声音階"))
        XCTAssertTrue(scaleNameTexts.firstMatch.waitForExistence(timeout: 3), "Scale name containing '五声音階' should be displayed in the recording list")
    }

    /// Test: Playback position slider appears during playback
    /// Expected: ~15 seconds execution time
    @MainActor
    func testPlaybackPositionSliderAppearsWhenPlaying() throws {
        let app = launchAppWithResetRecordingCount()

        // 1. Create a recording
        let homeRecordButton = app.buttons["HomeRecordButton"]
        XCTAssertTrue(homeRecordButton.waitForExistence(timeout: 5), "Home record button should exist")
        homeRecordButton.tap()

        let startButton = app.buttons["StartRecordingButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Start recording button should exist")
        startButton.tap()

        let stopButton = app.buttons["StopRecordingButton"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 10), "Stop recording button should appear")

        // Record for 3 seconds to have enough playback time
        Thread.sleep(forTimeInterval: 3.0)

        stopButton.tap()

        let playButton = app.buttons["PlayLastRecordingButton"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 5), "Play button should appear after save")

        // 2. Navigate to Recording List
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let homeListButton = app.buttons["HomeListButton"]
        XCTAssertTrue(homeListButton.waitForExistence(timeout: 5), "Home list button should exist")
        homeListButton.tap()

        // Wait for list to load by checking for delete buttons
        let deleteButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "DeleteRecordingButton_"))
        XCTAssertTrue(deleteButtons.firstMatch.waitForExistence(timeout: 5), "Delete button should appear in list")

        // Screenshot: List before playback
        let screenshot1 = app.screenshot()
        let attachment1 = XCTAttachment(screenshot: screenshot1)
        attachment1.name = "slider_01_before_playback"
        attachment1.lifetime = .keepAlways
        add(attachment1)

        // 3. Find and tap play button in the list
        let playCircleButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "play.circle.fill"))
        XCTAssertTrue(playCircleButtons.firstMatch.waitForExistence(timeout: 3), "Play button should exist in the list")
        playCircleButtons.firstMatch.tap()

        // Wait for playback to start by checking slider appearance
        let sliders = app.sliders
        XCTAssertTrue(sliders.firstMatch.waitForExistence(timeout: 5), "Position slider should appear when playback starts")

        // Screenshot: During playback (slider should be visible)
        let screenshot2 = app.screenshot()
        let attachment2 = XCTAttachment(screenshot: screenshot2)
        attachment2.name = "slider_02_during_playback"
        attachment2.lifetime = .keepAlways
        add(attachment2)

        // 4. Verify slider is visible during playback
        XCTAssertGreaterThan(sliders.count, 0, "Position slider should be visible during playback")

        // 5. Verify time display exists (format: "M:SS")
        // Time labels should show current position and total duration
        let timeLabels = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "[0-9]:[0-9]{2}"))
        XCTAssertGreaterThan(timeLabels.count, 0, "Time labels should be displayed during playback")

        // Wait for playback to finish naturally
        Thread.sleep(forTimeInterval: 3.0)

        // Screenshot: After playback (slider should disappear)
        let screenshot3 = app.screenshot()
        let attachment3 = XCTAttachment(screenshot: screenshot3)
        attachment3.name = "slider_03_after_playback"
        attachment3.lifetime = .keepAlways
        add(attachment3)
    }

    /// Test 3: Delete recording functionality
    /// Expected: ~15 seconds execution time
    @MainActor
    func testDeleteRecording() throws {
        let app = launchAppWithResetRecordingCount()

        // 1. Create a recording first
        let homeRecordButton = app.buttons["HomeRecordButton"]
        XCTAssertTrue(homeRecordButton.waitForExistence(timeout: 5), "Home record button should exist")
        homeRecordButton.tap()

        let startButton = app.buttons["StartRecordingButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Start recording button should exist")
        startButton.tap()

        // Wait for recording to start by checking StopButton appearance
        // No Thread.sleep needed - waitForExistence will wait for countdown + initialization
        let stopButton = app.buttons["StopRecordingButton"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 10), "Stop recording button should appear")

        // Continue recording for a moment to ensure valid audio data
        Thread.sleep(forTimeInterval: 1.0)

        stopButton.tap()

        // Wait for recording to finish and be saved by checking PlayButton appearance
        // No Thread.sleep needed - waitForExistence will wait for save completion
        let playButton = app.buttons["PlayLastRecordingButton"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 5), "Play last recording button should appear after recording")

        // 2. Navigate back to Home
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // 3. Navigate to Recording List screen
        let homeListButton = app.buttons["HomeListButton"]
        XCTAssertTrue(homeListButton.waitForExistence(timeout: 5), "Home list button should exist")
        homeListButton.tap()

        // Screenshot: Recording list before deletion
        let screenshot1 = app.screenshot()
        let attachment1 = XCTAttachment(screenshot: screenshot1)
        attachment1.name = "delete_01_before_delete"
        attachment1.lifetime = .keepAlways
        add(attachment1)

        // 4. Verify recording exists and count recordings before deletion
        let deleteButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "DeleteRecordingButton_"))
        XCTAssertTrue(deleteButtons.firstMatch.waitForExistence(timeout: 5), "Delete button should exist for the recording")
        let initialCount = deleteButtons.count

        // 5. Tap delete button (use firstMatch to handle multiple recordings)
        deleteButtons.firstMatch.tap()

        // Wait for confirmation dialog to appear by checking for confirm button
        let deleteConfirmButton = app.buttons["DeleteConfirmButton"]
        XCTAssertTrue(deleteConfirmButton.waitForExistence(timeout: 3), "Delete confirm button should exist in confirmation dialog")

        // Screenshot: Confirmation dialog
        let screenshot2 = app.screenshot()
        let attachment2 = XCTAttachment(screenshot: screenshot2)
        attachment2.name = "delete_02_confirmation_dialog"
        attachment2.lifetime = .keepAlways
        add(attachment2)

        // 6. Confirm deletion by tapping the delete confirm button
        deleteConfirmButton.tap()

        // Wait for deletion to complete by checking count change
        // Re-query the buttons after deletion to ensure fresh count
        let deleteButtonsAfterDeletion = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "DeleteRecordingButton_"))

        // Wait for the count to decrease (delete animation to complete)
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count < %d", initialCount),
            object: deleteButtonsAfterDeletion
        )
        let result = XCTWaiter.wait(for: [expectation], timeout: 5.0)
        XCTAssertEqual(result, .completed, "Recording count should decrease after deletion")

        // Screenshot: After deletion
        let screenshot3 = app.screenshot()
        let attachment3 = XCTAttachment(screenshot: screenshot3)
        attachment3.name = "delete_03_after_delete"
        attachment3.lifetime = .keepAlways
        add(attachment3)

        // 7. Verify recording is deleted by checking final count
        let finalCount = deleteButtonsAfterDeletion.count
        XCTAssertEqual(finalCount, initialCount - 1, "Recording count should decrease by 1 after deletion (was \(initialCount), now \(finalCount))")
    }
}
