//
//  VocalisStudioUITests.swift
//  VocalisStudioUITests
//
//  Created by KAZU ASATO on 2025/09/28.
//

import XCTest

final class VocalisStudioUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
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
}
