//
//  SubscriptionViewModelTests.swift
//  VocalisStudioTests
//
//  Tests for SubscriptionViewModel
//

import XCTest
import Combine
import SubscriptionDomain
@testable import VocalisStudio

@MainActor
final class SubscriptionViewModelTests: XCTestCase {

    var viewModel: SubscriptionViewModel!
    var mockGetStatusUseCase: MockGetSubscriptionStatusUseCase!
    var mockPurchaseUseCase: MockPurchaseSubscriptionUseCase!
    var mockRestoreUseCase: MockRestorePurchasesUseCase!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockGetStatusUseCase = MockGetSubscriptionStatusUseCase()
        mockPurchaseUseCase = MockPurchaseSubscriptionUseCase()
        mockRestoreUseCase = MockRestorePurchasesUseCase()
        viewModel = SubscriptionViewModel(
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

    // MARK: - Load Status Tests

    func testLoadStatusSuccessUpdatesCurrentStatus() async {
        // Given: Free tier status
        let expectedStatus = SubscriptionStatus.defaultFree(cohort: .v2_0)
        mockGetStatusUseCase.mockStatus = expectedStatus

        // When: Load status
        await viewModel.loadStatus()

        // Then: Current status should be updated
        XCTAssertEqual(viewModel.currentStatus?.tier, .free)
        XCTAssertEqual(viewModel.currentStatus?.cohort, .v2_0)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLoadStatusFailureSetsErrorMessage() async {
        // Given: Error scenario
        mockGetStatusUseCase.shouldThrowError = true

        // When: Load status
        await viewModel.loadStatus()

        // Then: Error message should be set
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.currentStatus)
    }

    func testLoadStatusSetsLoadingStateDuringExecution() async {
        // When: Start loading (don't await completion yet)
        let loadTask = Task {
            await viewModel.loadStatus()
        }

        // Then: Should be loading during execution
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        XCTAssertTrue(viewModel.isLoading, "Should be loading during execution")

        // Wait for completion
        await loadTask.value

        // Then: Should not be loading after completion
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after completion")
    }

    // MARK: - Purchase Tests

    func testPurchaseSuccessRefreshesStatus() async {
        // Given: Initial free tier
        mockGetStatusUseCase.mockStatus = SubscriptionStatus.defaultFree(cohort: .v2_0)
        await viewModel.loadStatus()

        // Given: Successful purchase
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

        // When: Purchase premium
        await viewModel.purchase(tier: .premium)

        // Then: Status should be refreshed to premium
        XCTAssertEqual(viewModel.currentStatus?.tier, .premium)
        XCTAssertTrue(viewModel.currentStatus?.isActive ?? false)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testPurchaseFailureSetsErrorMessage() async {
        // Given: Purchase will fail
        mockPurchaseUseCase.shouldSucceed = false

        // When: Attempt purchase
        await viewModel.purchase(tier: .premium)

        // Then: Error message should be set
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testPurchaseSetsLoadingStateDuringExecution() async {
        // When: Start purchase (don't await completion yet)
        let purchaseTask = Task {
            await viewModel.purchase(tier: .premium)
        }

        // Then: Should be loading during execution
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        XCTAssertTrue(viewModel.isLoading, "Should be loading during execution")

        // Wait for completion
        await purchaseTask.value

        // Then: Should not be loading after completion
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after completion")
    }

    // MARK: - Restore Tests

    func testRestoreSuccessRefreshesStatus() async {
        // Given: Initial free tier
        mockGetStatusUseCase.mockStatus = SubscriptionStatus.defaultFree(cohort: .v2_0)
        await viewModel.loadStatus()

        // Given: Successful restore
        mockRestoreUseCase.shouldSucceed = true
        let premiumStatus = SubscriptionStatus(
            tier: .premium,
            cohort: .v2_0,
            isActive: true,
            expirationDate: Date().addingTimeInterval(30 * 24 * 60 * 60),
            purchaseDate: Date().addingTimeInterval(-30 * 24 * 60 * 60),
            willAutoRenew: true
        )
        mockGetStatusUseCase.mockStatus = premiumStatus

        // When: Restore purchases
        await viewModel.restorePurchases()

        // Then: Status should be refreshed
        XCTAssertEqual(viewModel.currentStatus?.tier, .premium)
        XCTAssertTrue(viewModel.currentStatus?.isActive ?? false)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testRestoreFailureSetsErrorMessage() async {
        // Given: Restore will fail
        mockRestoreUseCase.shouldSucceed = false

        // When: Attempt restore
        await viewModel.restorePurchases()

        // Then: Error message should be set
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    // MARK: - Feature Access Tests

    func testHasAccessToFeatureReturnsTrueForAllowedFeature() async {
        // Given: Premium subscription
        let premiumStatus = SubscriptionStatus(
            tier: .premium,
            cohort: .v2_0,
            isActive: true,
            expirationDate: Date().addingTimeInterval(30 * 24 * 60 * 60),
            purchaseDate: Date(),
            willAutoRenew: true
        )
        mockGetStatusUseCase.mockStatus = premiumStatus
        await viewModel.loadStatus()

        // When: Check access to basic recording (free tier feature)
        let hasAccess = viewModel.hasAccessTo(.basicRecording)

        // Then: Should have access
        XCTAssertTrue(hasAccess)
    }

    func testHasAccessToFeatureReturnsFalseForRestrictedFeature() async {
        // Given: Free tier (v2.0 user)
        let freeStatus = SubscriptionStatus.defaultFree(cohort: .v2_0)
        mockGetStatusUseCase.mockStatus = freeStatus
        await viewModel.loadStatus()

        // When: Check access to pitch accuracy analysis (requires Premium)
        let hasAccess = viewModel.hasAccessTo(.pitchAccuracyAnalysis)

        // Then: Should not have access
        XCTAssertFalse(hasAccess)
    }

    func testHasAccessToFeatureReturnsTrueForGrandfatherUser() async {
        // Given: v1.0 user (grandfather privileges)
        let grandfatherStatus = SubscriptionStatus.defaultFree(cohort: .v1_0)
        mockGetStatusUseCase.mockStatus = grandfatherStatus
        await viewModel.loadStatus()

        // When: Check access to premium features
        let hasAccessToBasic = viewModel.hasAccessTo(.pitchAccuracyAnalysis)
        let hasAccessToAdvanced = viewModel.hasAccessTo(.professionalAnalysis)

        // Then: Should have access to all features
        XCTAssertTrue(hasAccessToBasic)
        XCTAssertTrue(hasAccessToAdvanced)
    }

    // MARK: - Error Handling Tests

    func testClearErrorMessageResetsError() async {
        // Given: Error message set
        viewModel.errorMessage = "Test error"

        // When: Clear error
        viewModel.clearError()

        // Then: Error should be nil
        XCTAssertNil(viewModel.errorMessage)
    }
}

// MARK: - Mock Use Cases

final class MockGetSubscriptionStatusUseCase: GetSubscriptionStatusUseCaseProtocol {
    var mockStatus: SubscriptionStatus?
    var shouldThrowError = false

    func execute() async throws -> SubscriptionStatus {
        if shouldThrowError {
            throw SubscriptionError.unknown
        }
        return mockStatus ?? SubscriptionStatus.defaultFree(cohort: .v2_0)
    }
}

final class MockPurchaseSubscriptionUseCase: PurchaseSubscriptionUseCaseProtocol {
    var shouldSucceed = true

    func execute(tier: SubscriptionTier) async throws {
        if !shouldSucceed {
            throw SubscriptionError.purchaseFailed("Mock purchase failed")
        }
    }
}

final class MockRestorePurchasesUseCase: RestorePurchasesUseCaseProtocol {
    var shouldSucceed = true

    func execute() async throws {
        if !shouldSucceed {
            throw SubscriptionError.noPurchasesToRestore
        }
    }
}
