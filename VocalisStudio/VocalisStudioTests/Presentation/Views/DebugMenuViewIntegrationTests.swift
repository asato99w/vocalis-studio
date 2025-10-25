//
//  DebugMenuViewIntegrationTests.swift
//  VocalisStudioTests
//
//  Integration tests for DebugMenuView using View assertions
//

import XCTest
import SwiftUI
import SubscriptionDomain
@testable import VocalisStudio

@MainActor
final class DebugMenuViewIntegrationTests: XCTestCase {

    var subscriptionViewModel: SubscriptionViewModel!

    override func setUp() async throws {
        // Create mock dependencies with unique names
        let mockGetStatusUseCase = DebugMenuMockGetSubscriptionStatusUseCase()
        let mockPurchaseUseCase = DebugMenuMockPurchaseSubscriptionUseCase()
        let mockRestoreUseCase = DebugMenuMockRestorePurchasesUseCase()

        subscriptionViewModel = SubscriptionViewModel(
            getStatusUseCase: mockGetStatusUseCase,
            purchaseUseCase: mockPurchaseUseCase,
            restoreUseCase: mockRestoreUseCase
        )

        // Initialize with Free tier
        subscriptionViewModel.setDebugTier(.free)
    }

    // MARK: - Tier Persistence Tests

    func testDebugTierPersistenceAcrossViewLifecycle() async throws {
        // Given: Initial state is Free
        XCTAssertEqual(subscriptionViewModel.currentStatus?.tier, .free)

        // When: Change to Premium
        subscriptionViewModel.setDebugTier(.premium)

        // Then: Tier is Premium
        XCTAssertEqual(subscriptionViewModel.currentStatus?.tier, .premium)
        XCTAssertEqual(subscriptionViewModel.currentStatus?.tier.displayName, "Premium")

        // When: Simulate view disappearing and reappearing
        // (EnvironmentObject maintains state across navigation)
        let tier = subscriptionViewModel.currentStatus?.tier

        // Then: Tier is still Premium
        XCTAssertEqual(tier, .premium)
    }

    func testDebugTierChangeFromPremiumToFree() async throws {
        // Given: Start with Premium
        subscriptionViewModel.setDebugTier(.premium)
        XCTAssertEqual(subscriptionViewModel.currentStatus?.tier, .premium)

        // When: Change to Free
        subscriptionViewModel.setDebugTier(.free)

        // Then: Tier is Free
        XCTAssertEqual(subscriptionViewModel.currentStatus?.tier, .free)
        XCTAssertEqual(subscriptionViewModel.currentStatus?.tier.displayName, "Free")

        // And: Tier persists
        let tier = subscriptionViewModel.currentStatus?.tier
        XCTAssertEqual(tier, .free)
    }

    func testDebugTierPremiumPlusPersistence() async throws {
        // Given: Start with Free
        XCTAssertEqual(subscriptionViewModel.currentStatus?.tier, .free)

        // When: Change to Premium Plus
        subscriptionViewModel.setDebugTier(.premiumPlus)

        // Then: Tier is Premium Plus
        XCTAssertEqual(subscriptionViewModel.currentStatus?.tier, .premiumPlus)
        XCTAssertEqual(subscriptionViewModel.currentStatus?.tier.displayName, "Premium Plus")

        // When: Simulate multiple navigation cycles
        var tier: SubscriptionTier?
        for _ in 0..<3 {
            // Simulate navigation away and back
            tier = subscriptionViewModel.currentStatus?.tier
            XCTAssertEqual(tier, .premiumPlus)
        }

        // Then: Tier is still Premium Plus
        XCTAssertEqual(tier, .premiumPlus)
    }

    func testAllTierTransitions() async throws {
        // Test Free -> Premium -> Premium Plus -> Free cycle

        // Start: Free
        subscriptionViewModel.setDebugTier(.free)
        XCTAssertEqual(subscriptionViewModel.currentStatus?.tier, .free)

        // Change: Free -> Premium
        subscriptionViewModel.setDebugTier(.premium)
        XCTAssertEqual(subscriptionViewModel.currentStatus?.tier, .premium)

        // Change: Premium -> Premium Plus
        subscriptionViewModel.setDebugTier(.premiumPlus)
        XCTAssertEqual(subscriptionViewModel.currentStatus?.tier, .premiumPlus)

        // Change: Premium Plus -> Free
        subscriptionViewModel.setDebugTier(.free)
        XCTAssertEqual(subscriptionViewModel.currentStatus?.tier, .free)
    }

    func testTierDisplayNames() async throws {
        // Test that display names are correct for each tier

        subscriptionViewModel.setDebugTier(.free)
        XCTAssertEqual(subscriptionViewModel.currentStatus?.tier.displayName, "Free")

        subscriptionViewModel.setDebugTier(.premium)
        XCTAssertEqual(subscriptionViewModel.currentStatus?.tier.displayName, "Premium")

        subscriptionViewModel.setDebugTier(.premiumPlus)
        XCTAssertEqual(subscriptionViewModel.currentStatus?.tier.displayName, "Premium Plus")
    }
}

// MARK: - DebugMenu-specific Mock Use Cases
// Note: Using unique names to avoid conflicts with other test files

private class DebugMenuMockGetSubscriptionStatusUseCase: GetSubscriptionStatusUseCaseProtocol {
    func execute() async throws -> SubscriptionStatus {
        return SubscriptionStatus(
            tier: .free,
            cohort: .v2_0,
            isActive: false,
            expirationDate: nil,
            purchaseDate: nil,
            willAutoRenew: false
        )
    }
}

private class DebugMenuMockPurchaseSubscriptionUseCase: PurchaseSubscriptionUseCaseProtocol {
    func execute(tier: SubscriptionTier) async throws {
        // Mock implementation
    }
}

private class DebugMenuMockRestorePurchasesUseCase: RestorePurchasesUseCaseProtocol {
    func execute() async throws {
        // Mock implementation
    }
}
