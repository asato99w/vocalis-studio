//
//  DebugMenuViewSnapshotTests.swift
//  VocalisStudioTests
//
//  Snapshot tests for DebugMenuView using swift-snapshot-testing
//

import XCTest
import SwiftUI
import SnapshotTesting
import VocalisDomain
@testable import VocalisStudio

// MARK: - Test Class

@MainActor
final class DebugMenuViewSnapshotTests: XCTestCase {

    var subscriptionViewModel: SubscriptionViewModel!

    override func setUp() async throws {
        // Create subscription view model with mock dependencies
        let mockGetStatusUseCase = SnapshotMockGetSubscriptionStatusUseCase()
        let mockPurchaseUseCase = SnapshotMockPurchaseSubscriptionUseCase()
        let mockRestoreUseCase = SnapshotMockRestorePurchasesUseCase()

        subscriptionViewModel = SubscriptionViewModel(
            getStatusUseCase: mockGetStatusUseCase,
            purchaseUseCase: mockPurchaseUseCase,
            restoreUseCase: mockRestoreUseCase
        )
    }

    // MARK: - Snapshot Tests

    func testDebugMenuView_FreeTier_Snapshot() async throws {
        // Given: Free tier selected
        subscriptionViewModel.setDebugTier(.free)
        try await Task.sleep(nanoseconds: 100_000_000)

        // When: Create DebugMenuView with EnvironmentObject
        let view = DebugMenuView()
            .environmentObject(subscriptionViewModel)

        // Then: Assert snapshot matches
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)))
    }

    func testDebugMenuView_PremiumTier_Snapshot() async throws {
        // Given: Premium tier selected
        subscriptionViewModel.setDebugTier(.premium)
        try await Task.sleep(nanoseconds: 100_000_000)

        // When: Create DebugMenuView with EnvironmentObject
        let view = DebugMenuView()
            .environmentObject(subscriptionViewModel)

        // Then: Assert snapshot matches
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)))
    }

    func testDebugMenuView_PremiumPlusTier_Snapshot() async throws {
        // Given: Premium Plus tier selected
        subscriptionViewModel.setDebugTier(.premiumPlus)
        try await Task.sleep(nanoseconds: 100_000_000)

        // When: Create DebugMenuView with EnvironmentObject
        let view = DebugMenuView()
            .environmentObject(subscriptionViewModel)

        // Then: Assert snapshot matches
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)))
    }

    func testDebugMenuView_DarkMode_Snapshot() async throws {
        // Given: Free tier with dark mode
        subscriptionViewModel.setDebugTier(.free)
        try await Task.sleep(nanoseconds: 100_000_000)

        // When: Create DebugMenuView with dark mode and EnvironmentObject
        let view = DebugMenuView()
            .environmentObject(subscriptionViewModel)
            .preferredColorScheme(.dark)

        // Then: Assert snapshot matches
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)))
    }

    func testDebugMenuView_LightMode_Snapshot() async throws {
        // Given: Premium tier with light mode
        subscriptionViewModel.setDebugTier(.premium)
        try await Task.sleep(nanoseconds: 100_000_000)

        // When: Create DebugMenuView with light mode and EnvironmentObject
        let view = DebugMenuView()
            .environmentObject(subscriptionViewModel)
            .preferredColorScheme(.light)

        // Then: Assert snapshot matches
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)))
    }
}

// MARK: - Snapshot-specific Mock Use Cases

private class SnapshotMockGetSubscriptionStatusUseCase: GetSubscriptionStatusUseCaseProtocol {
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

private class SnapshotMockPurchaseSubscriptionUseCase: PurchaseSubscriptionUseCaseProtocol {
    func execute(tier: SubscriptionTier) async throws {
        // Mock implementation
    }
}

private class SnapshotMockRestorePurchasesUseCase: RestorePurchasesUseCaseProtocol {
    func execute() async throws {
        // Mock implementation
    }
}
