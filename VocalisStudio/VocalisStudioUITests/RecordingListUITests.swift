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

        // Wait for countdown and some recording time
        Thread.sleep(forTimeInterval: 4.0)

        let stopButton = app.buttons["StopRecordingButton"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 2), "Stop recording button should appear")
        stopButton.tap()

        // Wait for recording to finish and be saved (increased from 1.0 to 2.0 seconds)
        Thread.sleep(forTimeInterval: 2.0)

        // Verify recording was saved by checking Play Last Recording button appears
        let playButton = app.buttons["PlayLastRecordingButton"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 5), "Play last recording button should appear after recording")

        // 2. Navigate back to Home
        app.navigationBars.buttons.element(boundBy: 0).tap()
        Thread.sleep(forTimeInterval: 0.5)

        // 3. Navigate to Recording List screen
        let homeListButton = app.buttons["HomeListButton"]
        XCTAssertTrue(homeListButton.waitForExistence(timeout: 5), "Home list button should exist")
        homeListButton.tap()

        // 4. Verify recording appears in the list
        // Wait for list to load (increased from 1.0 to 2.0 seconds)
        Thread.sleep(forTimeInterval: 2.0)

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

        // Wait for analysis screen to load
        Thread.sleep(forTimeInterval: 1.0)

        // Screenshot: Analysis screen
        let screenshot2 = app.screenshot()
        let attachment2 = XCTAttachment(screenshot: screenshot2)
        attachment2.name = "list_nav_02_analysis_screen"
        attachment2.lifetime = .keepAlways
        add(attachment2)

        // 6. Navigate back to list using back button
        app.navigationBars.buttons.element(boundBy: 0).tap()
        Thread.sleep(forTimeInterval: 0.5)

        // Screenshot: Back to list
        let screenshot3 = app.screenshot()
        let attachment3 = XCTAttachment(screenshot: screenshot3)
        attachment3.name = "list_nav_03_back_to_list"
        attachment3.lifetime = .keepAlways
        add(attachment3)

        // Verify we're back at the list
        XCTAssertTrue(deleteButtons.firstMatch.waitForExistence(timeout: 3), "Should be back at recording list with delete button visible")
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

        // Wait for countdown and some recording time
        Thread.sleep(forTimeInterval: 4.0)

        let stopButton = app.buttons["StopRecordingButton"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 2), "Stop recording button should appear")
        stopButton.tap()

        // Wait for recording to finish and be saved
        Thread.sleep(forTimeInterval: 2.0)

        // Verify recording was saved by checking Play Last Recording button appears
        let playButton = app.buttons["PlayLastRecordingButton"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 5), "Play last recording button should appear after recording")

        // 2. Navigate back to Home
        app.navigationBars.buttons.element(boundBy: 0).tap()
        Thread.sleep(forTimeInterval: 0.5)

        // 3. Navigate to Recording List screen
        let homeListButton = app.buttons["HomeListButton"]
        XCTAssertTrue(homeListButton.waitForExistence(timeout: 5), "Home list button should exist")
        homeListButton.tap()

        // Wait for list to load (increased timeout)
        Thread.sleep(forTimeInterval: 2.0)

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

        // Wait for confirmation dialog to appear
        Thread.sleep(forTimeInterval: 0.5)

        // Screenshot: Confirmation dialog
        let screenshot2 = app.screenshot()
        let attachment2 = XCTAttachment(screenshot: screenshot2)
        attachment2.name = "delete_02_confirmation_dialog"
        attachment2.lifetime = .keepAlways
        add(attachment2)

        // 6. Confirm deletion by tapping the delete confirm button
        // Note: In SwiftUI confirmationDialog, buttons are matched by their text
        let deleteConfirmButton = app.buttons["DeleteConfirmButton"]
        XCTAssertTrue(deleteConfirmButton.waitForExistence(timeout: 3), "Delete confirm button should exist in confirmation dialog")
        deleteConfirmButton.tap()

        // Wait for deletion to complete
        Thread.sleep(forTimeInterval: 1.0)

        // Screenshot: After deletion
        let screenshot3 = app.screenshot()
        let attachment3 = XCTAttachment(screenshot: screenshot3)
        attachment3.name = "delete_03_after_delete"
        attachment3.lifetime = .keepAlways
        add(attachment3)

        // 7. Verify recording is deleted by checking if count decreased
        let finalCount = deleteButtons.count

        // Verify that exactly one recording was deleted
        XCTAssertEqual(finalCount, initialCount - 1, "Recording count should decrease by 1 after deletion (was \(initialCount), now \(finalCount))")
    }
}
