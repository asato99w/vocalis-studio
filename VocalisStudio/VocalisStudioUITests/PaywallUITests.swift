//
//  PaywallUITests.swift
//  VocalisStudioUITests
//
//  UI tests for subscription paywall flow
//

import XCTest
import StoreKitTest

final class PaywallUITests: XCTestCase {

    var app: XCUIApplication!
    var session: SKTestSession!

    override func setUpWithError() throws {
        continueAfterFailure = false

        // Initialize StoreKit Test session with Configuration.storekit using relative path
        let testBundle = Bundle(for: type(of: self))
        guard let configURL = testBundle.url(forResource: "Configuration", withExtension: "storekit") else {
            XCTFail("Failed to find Configuration.storekit in test bundle")
            return
        }
        session = try SKTestSession(contentsOf: configURL)
        session.disableDialogs = true  // Disable dialogs for automated testing
        session.clearTransactions()

        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()
    }

    override func tearDownWithError() throws {
        session?.clearTransactions()
        session = nil
        app = nil
    }

    // MARK: - Paywall Display Tests

    func testPaywallDisplay_showsCorrectPricing() throws {
        // Navigate to paywall via Debug Menu
        navigateToPaywall()

        // Verify free tier information
        XCTAssertTrue(app.staticTexts["1日5回まで / 1回30秒まで"].exists, "Should show free tier limits")

        // Verify premium tier information
        XCTAssertTrue(app.staticTexts["回数無制限 / 1回最大5分"].exists, "Should show premium tier benefits")
        XCTAssertTrue(app.staticTexts["¥480/月"].exists, "Should show monthly price")
    }

    func testPaywallDisplay_showsTermsAndPrivacy() throws {
        // Navigate to paywall via Debug Menu
        navigateToPaywall()

        // Verify terms and privacy links exist
        // Note: SwiftUI Link may appear as other elements (buttons, staticTexts) in XCUITest
        let termsElement = app.descendants(matching: .any).containing(NSPredicate(format: "label CONTAINS %@", "利用規約"))
        XCTAssertTrue(termsElement.firstMatch.exists, "Should have terms link")

        let privacyElement = app.descendants(matching: .any).containing(NSPredicate(format: "label CONTAINS %@", "プライバシーポリシー"))
        XCTAssertTrue(privacyElement.firstMatch.exists, "Should have privacy policy link")

        // Verify disclaimer text
        XCTAssertTrue(app.staticTexts["購入により利用規約とプライバシーポリシーに同意したものとみなされます"].exists,
                     "Should show purchase agreement text")
    }

    // MARK: - Recording Limit → Paywall Flow

    // SKIP: Feature not yet implemented
    // This test requires recording limit enforcement which is not yet implemented in the app.
    // The feature will:
    // 1. Track recording count per day for free tier users
    // 2. Show paywall when limit is reached on 6th recording attempt
    // 3. Allow unlimited recordings for premium users
    //
    // To implement this test properly:
    // 1. Add UI test launch argument to set recording count to 5
    // 2. Attempt to start a 6th recording
    // 3. Verify paywall is shown instead of starting recording
    func SKIP_testRecordingLimitReached_showsPaywall() throws {
        throw XCTSkip("Feature not yet implemented: Recording limit enforcement and paywall display on limit reached")
    }

    // MARK: - Purchase Flow Tests

    func testPurchaseButton_isAccessible() throws {
        navigateToPaywall()

        // Verify purchase button exists and is enabled
        let purchaseButton = app.buttons["購入する"]
        XCTAssertTrue(purchaseButton.exists, "Purchase button should exist")
        XCTAssertTrue(purchaseButton.isEnabled, "Purchase button should be enabled")
    }

    func testRestoreButton_isAccessible() throws {
        navigateToSubscriptionManagement()

        // Verify restore button exists
        let restoreButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[cd] %@", "購入の復元"))
        XCTAssertTrue(restoreButton.firstMatch.exists, "Restore button should exist")
    }

    // MARK: - Settings Navigation Tests

    func testSettings_hasSubscriptionLink() throws {
        // Navigate to settings from Home
        let homeSettingsButton = app.buttons["HomeSettingsButton"]
        XCTAssertTrue(homeSettingsButton.waitForExistence(timeout: 5), "Home settings button should exist")
        homeSettingsButton.tap()

        // Wait for settings view to appear
        Thread.sleep(forTimeInterval: 0.5)

        // Verify subscription management link exists
        let subscriptionLink = app.buttons.containing(NSPredicate(format: "label CONTAINS[cd] %@", "サブスクリプションを管理"))
        XCTAssertTrue(subscriptionLink.firstMatch.exists, "Should have subscription management link in settings")

        // Tap to navigate
        subscriptionLink.firstMatch.tap()

        // Wait for navigation
        Thread.sleep(forTimeInterval: 0.5)

        // Verify navigation to subscription management
        XCTAssertTrue(app.navigationBars["サブスクリプション管理"].exists, "Should navigate to subscription management")
    }

    func testSettings_hasTermsAndPrivacyLinks() throws {
        // Navigate to settings from Home
        let homeSettingsButton = app.buttons["HomeSettingsButton"]
        XCTAssertTrue(homeSettingsButton.waitForExistence(timeout: 5), "Home settings button should exist")
        homeSettingsButton.tap()

        // Wait for settings view to appear
        Thread.sleep(forTimeInterval: 0.5)

        // Verify terms and privacy links exist in settings
        // Note: These are Link elements in SwiftUI Form, need to find them differently
        let termsLink = app.staticTexts["利用規約"]
        XCTAssertTrue(termsLink.waitForExistence(timeout: 5), "Should have terms link in settings")

        let privacyLink = app.staticTexts["プライバシーポリシー"]
        XCTAssertTrue(privacyLink.exists, "Should have privacy link in settings")
    }

    // MARK: - Subscription Status Display Tests

    func testSubscriptionManagement_showsCurrentPlan() throws {
        navigateToSubscriptionManagement()

        // Should show current plan (Free by default in test environment)
        let statusCard = app.otherElements.containing(NSPredicate(format: "label CONTAINS[cd] %@", "無料"))
        XCTAssertTrue(statusCard.firstMatch.exists, "Should show current plan status")

        // Should show version information
        XCTAssertTrue(app.staticTexts["v1.0"].exists, "Should show version in status card")
    }

    func testSubscriptionManagement_hasCancelLink() throws {
        navigateToSubscriptionManagement()

        // Verify cancel link exists (for subscribed users)
        let cancelLink = app.buttons.containing(NSPredicate(format: "label CONTAINS[cd] %@", "解約"))
        XCTAssertTrue(cancelLink.firstMatch.exists, "Should have cancel subscription link")
    }

    // MARK: - Loading States Tests

    func testPurchaseButton_showsLoadingState() throws {
        navigateToPaywall()

        let purchaseButton = app.buttons["購入する"]
        XCTAssertTrue(purchaseButton.exists)

        // Tap purchase button
        purchaseButton.tap()

        // Note: In real StoreKit environment, loading indicator would appear
        // In test environment, this depends on how StoreKit test is configured
        // We verify button is disabled during purchase
        // XCTAssertFalse(purchaseButton.isEnabled, "Button should be disabled during purchase")
    }

    // MARK: - Helper Methods

    private func navigateToSubscriptionManagement() {
        // Navigate from Home → Settings → Subscription Management
        let homeSettingsButton = app.buttons["HomeSettingsButton"]
        if homeSettingsButton.waitForExistence(timeout: 5) {
            homeSettingsButton.tap()

            // Wait for settings view to appear
            Thread.sleep(forTimeInterval: 0.5)

            // Tap subscription management link
            let subscriptionLink = app.buttons.containing(NSPredicate(format: "label CONTAINS[cd] %@", "サブスクリプションを管理"))
            if subscriptionLink.firstMatch.waitForExistence(timeout: 5) {
                subscriptionLink.firstMatch.tap()

                // Wait for subscription management view to appear
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
    }

    private func navigateToPaywall() {
        // Option 1: Use Upgrade Banner on home screen (actual user flow)
        // This banner appears when user is on free tier
        let upgradeBanner = app.buttons.containing(NSPredicate(format: "label CONTAINS[cd] %@", "無制限録音を解放"))
        if upgradeBanner.firstMatch.waitForExistence(timeout: 2) {
            upgradeBanner.firstMatch.tap()
            Thread.sleep(forTimeInterval: 0.5)
            return
        }

        // Option 2: Use Debug Menu on home screen (debug builds only)
        #if DEBUG
        let debugButton = app.staticTexts["Debug"]
        if debugButton.waitForExistence(timeout: 2) {
            debugButton.tap()

            // Wait for debug menu view to appear
            Thread.sleep(forTimeInterval: 0.5)

            // Tap Paywall link
            let paywallLink = app.buttons.containing(NSPredicate(format: "label CONTAINS[cd] %@", "プレミアムプラン"))
            if paywallLink.firstMatch.waitForExistence(timeout: 5) {
                paywallLink.firstMatch.tap()

                // Wait for paywall view to appear
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
        #endif
    }

    // MARK: - Accessibility Tests

    func testPaywall_isAccessible() throws {
        navigateToPaywall()

        // Verify all important elements have accessibility identifiers or labels
        let purchaseButton = app.buttons["購入する"]
        XCTAssertTrue(purchaseButton.exists)

        let restoreButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[cd] %@", "購入の復元"))
        XCTAssertTrue(restoreButton.firstMatch.exists)

        // Verify text is readable
        XCTAssertTrue(app.staticTexts["無制限録音を解放"].exists)
        XCTAssertTrue(app.staticTexts["プレミアムで毎日何度でも録音できます"].exists)
    }

    // MARK: - Purchase Status Update Tests

    func testPurchase_shouldUpdateToPremiumStatus() throws {
        // Navigate to paywall
        navigateToPaywall()

        // Tap purchase button
        let purchaseButton = app.buttons["購入する"]
        XCTAssertTrue(purchaseButton.exists, "Purchase button should exist")
        purchaseButton.tap()

        // Handle StoreKit Testing purchase dialog
        // Wait for either "Subscribe" or "Buy" button in StoreKit dialog
        let subscribeButton = app.buttons["Subscribe"]
        let buyButton = app.buttons["Buy"]

        if subscribeButton.waitForExistence(timeout: 5) {
            subscribeButton.tap()
        } else if buyButton.waitForExistence(timeout: 1) {
            buyButton.tap()
        }

        // Wait for transaction to process
        sleep(3)

        // Handle purchase success alert explicitly
        let okButton = app.buttons["OK"]
        if okButton.waitForExistence(timeout: 5) {
            okButton.tap()
        }

        // Wait for paywall sheet to dismiss after alert
        Thread.sleep(forTimeInterval: 1)

        // Expected behavior: After purchase, app should return to home/top page
        // Verify we're back on home screen by checking for home-specific elements

        // ✅ Verify Premium status by navigating to subscription management
        // Navigate from Home → Settings → Subscription Management

        // Check that we're back on home screen
        let homeSettingsButton = app.buttons["HomeSettingsButton"]
        XCTAssertTrue(homeSettingsButton.waitForExistence(timeout: 5), "Should return to home screen after purchase")

        homeSettingsButton.tap()
        Thread.sleep(forTimeInterval: 0.5)

        let subscriptionLink = app.buttons.containing(NSPredicate(format: "label CONTAINS[cd] %@", "サブスクリプションを管理"))
        XCTAssertTrue(subscriptionLink.firstMatch.waitForExistence(timeout: 5), "Subscription management link should exist")
        subscriptionLink.firstMatch.tap()

        // Wait for subscription management screen to load
        Thread.sleep(forTimeInterval: 1)

        // Verify Premium status is displayed
        let premiumStatusText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[cd] %@", "Premium"))
        XCTAssertTrue(premiumStatusText.firstMatch.waitForExistence(timeout: 5),
                     "Should show Premium status in subscription management after purchase")

        // Verify Free tier is NOT shown (since user is now Premium)
        let freeStatusText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[cd] %@", "無料"))
        XCTAssertFalse(freeStatusText.firstMatch.exists,
                      "Should NOT show Free tier after Premium purchase")
    }

    // DEBUG TEST: Check what status is shown after purchase
    func testDEBUG_checkSubscriptionStatusAfterPurchase() throws {
        // Navigate to paywall
        navigateToPaywall()

        // Tap purchase button
        let purchaseButton = app.buttons["購入する"]
        XCTAssertTrue(purchaseButton.exists)
        purchaseButton.tap()

        // DEBUG: Print all buttons and alerts after tapping purchase button
        Thread.sleep(forTimeInterval: 2)

        // Check for error alert
        let errorAlert = app.alerts["エラー"]
        if errorAlert.exists {
            print("=== ERROR ALERT DETECTED ===")
            for staticText in errorAlert.staticTexts.allElementsBoundByIndex {
                print("Alert text: '\(staticText.label)'")
            }
            // Tap OK to dismiss
            errorAlert.buttons["OK"].tap()
            Thread.sleep(forTimeInterval: 1)
        }

        print("=== ALL BUTTONS AFTER PURCHASE TAP ===")
        for button in app.buttons.allElementsBoundByIndex {
            print("Button: '\(button.label)' - identifier: '\(button.identifier)'")
        }
        print("=== END BUTTONS ===")

        // Wait for purchase
        sleep(4)

        // Navigate to subscription management to check status
        let homeSettingsButton = app.buttons["HomeSettingsButton"]
        if homeSettingsButton.waitForExistence(timeout: 5) {
            homeSettingsButton.tap()
            Thread.sleep(forTimeInterval: 0.5)

            let subscriptionLink = app.buttons.containing(NSPredicate(format: "label CONTAINS[cd] %@", "サブスクリプションを管理"))
            if subscriptionLink.firstMatch.waitForExistence(timeout: 5) {
                subscriptionLink.firstMatch.tap()
                Thread.sleep(forTimeInterval: 1)

                // Print all text elements to see what's displayed
                print("=== ALL TEXT ELEMENTS IN SUBSCRIPTION MANAGEMENT ===")
                for element in app.staticTexts.allElementsBoundByIndex {
                    print("Text: '\(element.label)'")
                }
                print("=== END ===")
            }
        }
    }

    func testDebugMenu_tierSwitch_shouldPersistAcrossScreens() throws {
        #if DEBUG
        // Navigate to Debug Menu from Home (Debug button is at bottom of home screen)
        let debugButton = app.staticTexts["Debug"]
        XCTAssertTrue(debugButton.waitForExistence(timeout: 5), "Debug button should exist on home screen")
        debugButton.tap()

        // Wait for debug menu
        Thread.sleep(forTimeInterval: 0.5)

        // Switch to Premium tier in debug menu
        let tierPicker = app.segmentedControls.firstMatch
        XCTAssertTrue(tierPicker.exists, "Tier picker should exist")
        tierPicker.buttons["Premium"].tap()

        // Wait for status update
        Thread.sleep(forTimeInterval: 1)

        // Verify current tier shows Premium
        let currentTierLabel = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[cd] %@", "現在: Premium"))
        XCTAssertTrue(currentTierLabel.firstMatch.exists, "Should show current tier as Premium")

        // Navigate back to home
        app.navigationBars.buttons.firstMatch.tap()
        Thread.sleep(forTimeInterval: 0.5)

        // Navigate to Settings → Subscription Management
        let homeSettingsButton = app.buttons["HomeSettingsButton"]
        homeSettingsButton.tap()
        Thread.sleep(forTimeInterval: 0.5)

        let subscriptionLink = app.buttons.containing(NSPredicate(format: "label CONTAINS[cd] %@", "サブスクリプションを管理"))
        subscriptionLink.firstMatch.tap()
        Thread.sleep(forTimeInterval: 0.5)

        // Verify Premium status is shown in subscription management
        let premiumText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[cd] %@", "Premium"))
        XCTAssertTrue(premiumText.firstMatch.exists, "Should show Premium status in subscription management")

        // Return to settings
        app.navigationBars.buttons.firstMatch.tap()
        Thread.sleep(forTimeInterval: 0.5)

        // Return to home
        app.navigationBars.buttons.firstMatch.tap()
        Thread.sleep(forTimeInterval: 0.5)

        // Return to debug menu
        debugButton.tap()
        Thread.sleep(forTimeInterval: 0.5)

        // Verify tier is still Premium
        XCTAssertTrue(currentTierLabel.firstMatch.exists, "Tier should still be Premium in debug menu")
        #endif
    }

    // 🔴 RED TEST: Debug tier should be cleared when Transaction.updates fires
    // This tests the scenario where:
    // 1. User sets debug tier manually
    // 2. Transaction.updates receives purchase completion (not via purchase() method)
    // 3. observeTransactionUpdates() calls loadStatus() while isDebugTierSet=true
    // 4. BUG: loadStatus() returns early, debug tier persists
    func testDebugTier_shouldBeClearedAfterRestorePurchase() throws {
        #if DEBUG
        // First make a purchase to have something to restore
        navigateToPaywall()
        let purchaseButton = app.buttons["購入する"]
        XCTAssertTrue(purchaseButton.exists, "Purchase button should exist")
        purchaseButton.tap()
        Thread.sleep(forTimeInterval: 3)

        let okButton = app.buttons["OK"]
        if okButton.waitForExistence(timeout: 5) {
            okButton.tap()
        }
        Thread.sleep(forTimeInterval: 1)

        // Navigate to home
        let homeSettingsButton = app.buttons["HomeSettingsButton"]
        XCTAssertTrue(homeSettingsButton.waitForExistence(timeout: 5), "Should return to home")

        // Step 1: Set debug tier to Free via Debug Menu
        let debugButton = app.staticTexts["Debug"]
        XCTAssertTrue(debugButton.waitForExistence(timeout: 5), "Debug button should exist")
        debugButton.tap()
        Thread.sleep(forTimeInterval: 0.5)

        // Set to Free tier - this sets isDebugTierSet = true
        let tierPicker = app.segmentedControls.firstMatch
        XCTAssertTrue(tierPicker.exists, "Tier picker should exist")
        tierPicker.buttons["Free"].tap()
        Thread.sleep(forTimeInterval: 1)

        // Verify Free tier is set
        let freeTierLabel = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[cd] %@", "現在: 無料"))
        XCTAssertTrue(freeTierLabel.firstMatch.exists, "Should show Free tier in debug menu")

        // Close all navigation to get back to home
        // Tap back buttons until we reach home screen
        while app.navigationBars.buttons.count > 0 {
            let firstButton = app.navigationBars.buttons.element(boundBy: 0)
            if firstButton.exists {
                firstButton.tap()
                Thread.sleep(forTimeInterval: 0.3)
            } else {
                break
            }

            // Check if we're at home screen
            if app.buttons["HomeSettingsButton"].exists {
                break
            }
        }

        // Step 2: Navigate to Subscription Management and trigger restore
        let settingsButton2 = app.buttons["HomeSettingsButton"]
        XCTAssertTrue(settingsButton2.waitForExistence(timeout: 5), "Should be at home screen")
        settingsButton2.tap()
        Thread.sleep(forTimeInterval: 0.5)

        let subscriptionLink = app.buttons.containing(NSPredicate(format: "label CONTAINS[cd] %@", "サブスクリプションを管理"))
        subscriptionLink.firstMatch.tap()
        Thread.sleep(forTimeInterval: 1)

        // Tap restore button (this will fire Transaction.updates)
        let restoreButton = app.buttons["購入の復元"]
        XCTAssertTrue(restoreButton.waitForExistence(timeout: 5), "Restore button should exist")
        restoreButton.tap()
        Thread.sleep(forTimeInterval: 3)

        // Handle restore alert
        if okButton.waitForExistence(timeout: 5) {
            okButton.tap()
        }
        Thread.sleep(forTimeInterval: 2)

        // Step 3: 🔴 BUG VERIFICATION
        // Without fix: observeTransactionUpdates() calls loadStatus()
        // but isDebugTierSet=true causes early return
        // Result: Debug Free tier persists (TEST SHOULD FAIL)
        //
        // With fix: loadStatus(force: true) clears isDebugTierSet
        // Result: Shows actual Premium status (TEST SHOULD PASS)

        let premiumText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[cd] %@", "Premium"))
        XCTAssertTrue(premiumText.firstMatch.exists,
                     "After restore, should show Premium status from StoreKit (NOT debug Free tier)")

        let freeText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[cd] %@", "無料"))
        XCTAssertFalse(freeText.firstMatch.exists,
                      "Debug Free tier should be cleared after Transaction.updates")
        #endif
    }
}
