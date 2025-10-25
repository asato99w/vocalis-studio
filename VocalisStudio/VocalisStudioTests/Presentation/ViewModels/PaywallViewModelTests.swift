//
//  PaywallViewModelTests.swift
//  VocalisStudioTests
//
//  Tests for PaywallViewModel
//

import XCTest
import Combine
import SubscriptionDomain
@testable import VocalisStudio

@MainActor
final class PaywallViewModelTests: XCTestCase {

    var viewModel: PaywallViewModel!
    var mockGetStatusUseCase: MockGetStatusUseCase!
    var mockPurchaseUseCase: MockPurchaseUseCase!
    var mockRestoreUseCase: MockRestoreUseCase!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockGetStatusUseCase = MockGetStatusUseCase()
        mockPurchaseUseCase = MockPurchaseUseCase()
        mockRestoreUseCase = MockRestoreUseCase()
        viewModel = PaywallViewModel(
            getStatusUseCase: mockGetStatusUseCase,
            purchaseUseCase: mockPurchaseUseCase,
            restoreUseCase: mockRestoreUseCase
        )
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        viewModel = nil
        mockGetStatusUseCase = nil
        mockPurchaseUseCase = nil
        mockRestoreUseCase = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialState() async {
        // Then: Initial state should be correct
        XCTAssertNil(viewModel.currentStatus)
        XCTAssertEqual(viewModel.selectedTier, .premium)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isPurchaseSuccessful)
    }

    // MARK: - Load Status Tests

    func testLoadStatusSuccess() async {
        // Given: Mock status
        let status = SubscriptionStatus.defaultFree(cohort: .v2_0)
        mockGetStatusUseCase.mockStatus = status

        // When: Load status
        await viewModel.loadStatus()

        // Then: Status should be updated
        XCTAssertEqual(viewModel.currentStatus?.tier, .free)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLoadStatusFailure() async {
        // Given: Mock error
        mockGetStatusUseCase.shouldThrowError = true

        // When: Load status
        await viewModel.loadStatus()

        // Then: Error should be set
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.currentStatus)
        XCTAssertFalse(viewModel.isLoading)
    }

    // MARK: - Select Tier Tests

    func testSelectTier() async {
        // When: Select Premium Plus
        viewModel.selectTier(.premiumPlus)

        // Then: Selected tier should be updated
        XCTAssertEqual(viewModel.selectedTier, .premiumPlus)
    }

    func testSelectFreeTierIgnored() async {
        // Given: Premium tier selected
        viewModel.selectTier(.premium)

        // When: Try to select free tier
        viewModel.selectTier(.free)

        // Then: Selection should not change
        XCTAssertEqual(viewModel.selectedTier, .premium)
    }

    // MARK: - Purchase Tests

    func testPurchaseSelectedTierSuccess() async {
        // Given: Premium tier selected
        viewModel.selectTier(.premium)
        mockPurchaseUseCase.shouldSucceed = true
        let premiumStatus = SubscriptionStatus(
            tier: .premium,
            cohort: .v2_0,
            isActive: true,
            expirationDate: Date().addingTimeInterval(30 * 24 * 60 * 60),
            purchaseDate: Date(),
            willAutoRenew: true
        )
        mockGetStatusUseCase.mockStatus = premiumStatus

        // When: Purchase selected tier
        await viewModel.purchaseSelectedTier()

        // Then: Purchase should succeed
        XCTAssertTrue(viewModel.isPurchaseSuccessful)
        XCTAssertEqual(viewModel.currentStatus?.tier, .premium)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testPurchaseSelectedTierFailure() async {
        // Given: Purchase will fail
        mockPurchaseUseCase.shouldSucceed = false

        // When: Purchase selected tier
        await viewModel.purchaseSelectedTier()

        // Then: Error should be set
        XCTAssertFalse(viewModel.isPurchaseSuccessful)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    // MARK: - Restore Purchases Tests

    func testRestorePurchasesSuccess() async {
        // Given: Restore will succeed
        mockRestoreUseCase.shouldSucceed = true
        let premiumStatus = SubscriptionStatus(
            tier: .premium,
            cohort: .v2_0,
            isActive: true,
            expirationDate: Date().addingTimeInterval(30 * 24 * 60 * 60),
            purchaseDate: Date(),
            willAutoRenew: true
        )
        mockGetStatusUseCase.mockStatus = premiumStatus

        // When: Restore purchases
        await viewModel.restorePurchases()

        // Then: Status should be refreshed
        XCTAssertEqual(viewModel.currentStatus?.tier, .premium)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testRestorePurchasesFailure() async {
        // Given: Restore will fail
        mockRestoreUseCase.shouldSucceed = false

        // When: Restore purchases
        await viewModel.restorePurchases()

        // Then: Error should be set
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    // MARK: - Computed Properties Tests

    func testAvailableTiers() async {
        // Then: Should return premium and premium plus
        XCTAssertEqual(viewModel.availableTiers.count, 2)
        XCTAssertTrue(viewModel.availableTiers.contains(.premium))
        XCTAssertTrue(viewModel.availableTiers.contains(.premiumPlus))
    }

    func testSelectedTierFeatures() async {
        // Given: Premium tier selected
        viewModel.selectTier(.premium)

        // Then: Should return premium features
        let features = viewModel.selectedTierFeatures
        XCTAssertTrue(features.allSatisfy { $0.minimumTier == .premium || $0.minimumTier == .free })
    }

    func testIsRecommended() async {
        // Then: Premium Plus should be recommended
        XCTAssertTrue(viewModel.isRecommended(.premiumPlus))
        XCTAssertFalse(viewModel.isRecommended(.premium))
        XCTAssertFalse(viewModel.isRecommended(.free))
    }

    func testFeaturesForTier() async {
        // When: Get features for Premium
        let premiumFeatures = viewModel.features(for: .premium)

        // Then: Should include free and premium features
        XCTAssertTrue(premiumFeatures.contains { $0.minimumTier == .free })
        XCTAssertTrue(premiumFeatures.contains { $0.minimumTier == .premium })
        XCTAssertFalse(premiumFeatures.contains { $0.minimumTier == .premiumPlus })
    }

    func testHasActiveSubscription() async {
        // Given: No subscription
        mockGetStatusUseCase.mockStatus = SubscriptionStatus.defaultFree(cohort: .v2_0)
        await viewModel.loadStatus()

        // Then: Should not have active subscription
        XCTAssertFalse(viewModel.hasActiveSubscription)

        // Given: Active premium subscription
        mockGetStatusUseCase.mockStatus = SubscriptionStatus(
            tier: .premium,
            cohort: .v2_0,
            isActive: true,
            expirationDate: Date().addingTimeInterval(30 * 24 * 60 * 60),
            purchaseDate: Date(),
            willAutoRenew: true
        )
        await viewModel.loadStatus()

        // Then: Should have active subscription
        XCTAssertTrue(viewModel.hasActiveSubscription)
    }

    // MARK: - Error Handling Tests

    func testClearError() async {
        // Given: Error message set
        viewModel.errorMessage = "Test error"

        // When: Clear error
        viewModel.clearError()

        // Then: Error should be nil
        XCTAssertNil(viewModel.errorMessage)
    }
}

// MARK: - Mock Use Cases

final class MockGetStatusUseCase: GetSubscriptionStatusUseCaseProtocol {
    var mockStatus: SubscriptionStatus?
    var shouldThrowError = false

    func execute() async throws -> SubscriptionStatus {
        if shouldThrowError {
            throw SubscriptionError.networkError
        }
        guard let status = mockStatus else {
            return SubscriptionStatus.defaultFree(cohort: .v2_0)
        }
        return status
    }
}

final class MockPurchaseUseCase: PurchaseSubscriptionUseCaseProtocol {
    var shouldSucceed = true

    func execute(tier: SubscriptionTier) async throws {
        if !shouldSucceed {
            throw SubscriptionError.purchaseFailed("Purchase failed")
        }
    }
}

final class MockRestoreUseCase: RestorePurchasesUseCaseProtocol {
    var shouldSucceed = true

    func execute() async throws {
        if !shouldSucceed {
            throw SubscriptionError.noPurchasesToRestore
        }
    }
}
