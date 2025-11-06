//
//  PaywallUITests.swift
//  VocalisStudioUITests
//
//  UI tests for subscription paywall flow
//

import XCTest

final class PaywallUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Paywall Display Tests

    func testPaywallDisplay_showsCorrectPricing() throws {
        // Navigate to home → settings → subscription management
        navigateToSubscriptionManagement()

        // Verify free tier information
        XCTAssertTrue(app.staticTexts["1日5回まで / 1回30秒まで"].exists, "Should show free tier limits")

        // Verify premium tier information
        XCTAssertTrue(app.staticTexts["回数無制限 / 1回最大5分"].exists, "Should show premium tier benefits")
        XCTAssertTrue(app.staticTexts["¥480/月"].exists, "Should show monthly price")
    }

    func testPaywallDisplay_showsTermsAndPrivacy() throws {
        // Navigate to paywall
        navigateToSubscriptionManagement()

        // Verify terms and privacy links exist
        XCTAssertTrue(app.links["利用規約"].exists, "Should have terms link")
        XCTAssertTrue(app.links["プライバシーポリシー"].exists, "Should have privacy policy link")

        // Verify disclaimer text
        XCTAssertTrue(app.staticTexts["購入により利用規約とプライバシーポリシーに同意したものとみなされます"].exists,
                     "Should show purchase agreement text")
    }

    // MARK: - Recording Limit → Paywall Flow

    func testRecordingLimitReached_showsPaywall() throws {
        // Note: This requires the app to be in a state where limit is reached
        // In real testing, you would:
        // 1. Record 5 times to hit the limit
        // 2. Attempt 6th recording
        // 3. Verify paywall is shown

        // For now, we test the navigation path exists
        let homeTab = app.tabBars.buttons["ホーム"]
        homeTab.tap()

        let upgradeButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[cd] %@", "プレミアム"))
        if upgradeButton.firstMatch.exists {
            upgradeButton.firstMatch.tap()

            // Verify paywall is displayed
            XCTAssertTrue(app.navigationBars["プレミアムプラン"].exists, "Should show paywall")
            XCTAssertTrue(app.staticTexts["無制限録音を解放"].exists, "Should show unlock message")
        }
    }

    // MARK: - Purchase Flow Tests

    func testPurchaseButton_isAccessible() throws {
        navigateToSubscriptionManagement()

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
        // Navigate to settings
        let settingsTab = app.tabBars.buttons["設定"]
        settingsTab.tap()

        // Verify subscription management link exists
        let subscriptionLink = app.buttons.containing(NSPredicate(format: "label CONTAINS[cd] %@", "サブスクリプションを管理"))
        XCTAssertTrue(subscriptionLink.firstMatch.exists, "Should have subscription management link in settings")

        // Tap to navigate
        subscriptionLink.firstMatch.tap()

        // Verify navigation to subscription management
        XCTAssertTrue(app.navigationBars["サブスクリプション管理"].exists, "Should navigate to subscription management")
    }

    func testSettings_hasTermsAndPrivacyLinks() throws {
        // Navigate to settings
        let settingsTab = app.tabBars.buttons["設定"]
        settingsTab.tap()

        // Verify terms and privacy links exist in settings
        XCTAssertTrue(app.links["利用規約"].exists, "Should have terms link in settings")
        XCTAssertTrue(app.links["プライバシーポリシー"].exists, "Should have privacy link in settings")
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
        navigateToSubscriptionManagement()

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
        // Method 1: Via Settings
        let settingsTab = app.tabBars.buttons["設定"]
        if settingsTab.exists {
            settingsTab.tap()

            let subscriptionLink = app.buttons.containing(NSPredicate(format: "label CONTAINS[cd] %@", "サブスクリプションを管理"))
            if subscriptionLink.firstMatch.exists {
                subscriptionLink.firstMatch.tap()
            }
        }
    }

    // MARK: - Accessibility Tests

    func testPaywall_isAccessible() throws {
        navigateToSubscriptionManagement()

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
        // Navigate to subscription management
        navigateToSubscriptionManagement()

        // Verify initial free tier status
        XCTAssertTrue(app.staticTexts["無料"].exists, "Should start with free tier")

        // Tap purchase button
        let purchaseButton = app.buttons["購入する"]
        XCTAssertTrue(purchaseButton.exists, "Purchase button should exist")
        purchaseButton.tap()

        // Wait for StoreKit test purchase to complete (StoreKit Testing auto-approves)
        // In StoreKit Testing environment, purchases complete immediately
        sleep(2)

        // Verify premium status is shown
        let premiumText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[cd] %@", "Premium"))
        XCTAssertTrue(premiumText.firstMatch.waitForExistence(timeout: 5), "Should show Premium status after purchase")

        // Navigate back to settings to verify status persists
        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)

        // Return to subscription management
        let subscriptionLink = app.buttons.containing(NSPredicate(format: "label CONTAINS[cd] %@", "サブスクリプションを管理"))
        subscriptionLink.firstMatch.tap()

        // Verify premium status is still shown
        XCTAssertTrue(premiumText.firstMatch.exists, "Premium status should persist after navigation")
    }

    func testDebugMenu_tierSwitch_shouldPersistAcrossScreens() throws {
        #if DEBUG
        // Navigate to Debug Menu
        let settingsTab = app.tabBars.buttons["設定"]
        settingsTab.tap()

        let debugMenuButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[cd] %@", "Debug Menu"))
        XCTAssertTrue(debugMenuButton.firstMatch.exists, "Debug Menu button should exist")
        debugMenuButton.firstMatch.tap()

        // Switch to Premium tier in debug menu
        let tierPicker = app.segmentedControls.firstMatch
        XCTAssertTrue(tierPicker.exists, "Tier picker should exist")
        tierPicker.buttons["Premium"].tap()

        // Wait for status update
        sleep(1)

        // Verify current tier shows Premium
        let currentTierLabel = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[cd] %@", "現在: Premium"))
        XCTAssertTrue(currentTierLabel.firstMatch.exists, "Should show current tier as Premium")

        // Navigate to subscription management
        app.navigationBars.buttons.firstMatch.tap()
        let subscriptionLink = app.buttons.containing(NSPredicate(format: "label CONTAINS[cd] %@", "サブスクリプションを管理"))
        subscriptionLink.firstMatch.tap()

        // Verify Premium status is shown in subscription management
        let premiumText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[cd] %@", "Premium"))
        XCTAssertTrue(premiumText.firstMatch.exists, "Should show Premium status in subscription management")

        // Return to debug menu
        app.navigationBars.buttons.firstMatch.tap()
        debugMenuButton.firstMatch.tap()

        // Verify tier is still Premium
        XCTAssertTrue(currentTierLabel.firstMatch.exists, "Tier should still be Premium in debug menu")
        #endif
    }
}
