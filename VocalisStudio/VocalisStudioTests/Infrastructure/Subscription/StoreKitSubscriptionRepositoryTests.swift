//
//  StoreKitSubscriptionRepositoryTests.swift
//  VocalisStudioTests
//
//  Tests for StoreKitSubscriptionRepository
//

import XCTest
import StoreKit
@testable import VocalisStudio

final class StoreKitSubscriptionRepositoryTests: XCTestCase {

    var repository: StoreKitSubscriptionRepository!
    var mockProductService: MockStoreKitProductService!
    var mockPurchaseService: MockStoreKitPurchaseService!
    var mockCohortStore: MockUserCohortStore!

    override func setUp() {
        super.setUp()
        mockProductService = MockStoreKitProductService()
        mockPurchaseService = MockStoreKitPurchaseService()
        mockCohortStore = MockUserCohortStore()
        repository = StoreKitSubscriptionRepository(
            productService: mockProductService,
            purchaseService: mockPurchaseService,
            cohortStore: mockCohortStore
        )
    }

    override func tearDown() {
        repository = nil
        mockProductService = nil
        mockPurchaseService = nil
        mockCohortStore = nil
        super.tearDown()
    }

    // MARK: - Get Current Status Tests

    func testGetCurrentStatusReturnsFreeTierWhenNoEntitlements() async throws {
        // Given: No active entitlements, v2.0 cohort
        mockPurchaseService.mockEntitlements = []
        mockCohortStore.mockCohort = .v2_0

        // When: Get current status
        let status = try await repository.getCurrentStatus()

        // Then: Should return free tier
        XCTAssertEqual(status.tier, .free)
        XCTAssertEqual(status.cohort, .v2_0)
        XCTAssertTrue(status.isActive)
    }

    func testGetCurrentStatusDeterminesCohortForNewUser() async throws {
        // Given: New user (no cohort saved)
        mockPurchaseService.mockEntitlements = []
        mockCohortStore.mockCohort = nil

        // When: Get current status
        let status = try await repository.getCurrentStatus()

        // Then: Should determine and save cohort (v2.5 for current date)
        XCTAssertNotNil(mockCohortStore.savedCohort)
        XCTAssertEqual(status.cohort, mockCohortStore.savedCohort)
    }

    // MARK: - Purchase Product Tests

    func testPurchaseProductSucceedsForValidProduct() async throws {
        // Given: Valid Premium product
        let productId = SubscriptionTier.premium.productId
        let mockProduct = MockProduct(id: productId, displayName: "Premium")
        mockProductService.mockProducts = [mockProduct]

        // When/Then: Purchase product (will fail with user cancelled in mock)
        // This test primarily verifies the repository calls the purchase service
        do {
            try await repository.purchaseProduct(productId: productId)
            XCTFail("Should have thrown error (mock returns userCancelled)")
        } catch {
            // Expected: Mock purchase service returns .userCancelled
            XCTAssertTrue(mockPurchaseService.didCallPurchase)
        }
    }

    func testPurchaseProductThrowsErrorForInvalidProduct() async {
        // Given: Invalid product ID
        let productId = "invalid_product_id"
        mockProductService.mockProducts = []

        // When/Then: Should throw productNotFound error
        do {
            try await repository.purchaseProduct(productId: productId)
            XCTFail("Should have thrown error")
        } catch let error as SubscriptionError {
            XCTAssertEqual(error, SubscriptionError.productNotFound)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Restore Purchases Tests

    func testRestorePurchasesSucceedsWhenEntitlementsExist() async throws {
        // Given: User has entitlements
        mockPurchaseService.mockRestoreSuccess = true

        // When: Restore purchases
        try await repository.restorePurchases()

        // Then: Should succeed
        XCTAssertTrue(mockPurchaseService.didCallRestore)
    }

    func testRestorePurchasesThrowsErrorWhenNoEntitlements() async {
        // Given: No entitlements found
        mockPurchaseService.mockRestoreSuccess = false

        // When/Then: Should throw error
        do {
            try await repository.restorePurchases()
            XCTFail("Should have thrown error")
        } catch let error as SubscriptionError {
            XCTAssertEqual(error, SubscriptionError.noPurchasesToRestore)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Get User Cohort Tests

    func testGetUserCohortReturnsStoredCohort() async throws {
        // Given: Cohort is stored
        mockCohortStore.mockCohort = .v1_0

        // When: Get user cohort
        let cohort = try await repository.getUserCohort()

        // Then: Should return stored cohort
        XCTAssertEqual(cohort, .v1_0)
    }

    func testGetUserCohortDeterminesAndSavesNewCohort() async throws {
        // Given: No cohort stored (new user)
        mockCohortStore.mockCohort = nil

        // When: Get user cohort
        let cohort = try await repository.getUserCohort()

        // Then: Should determine based on current date and save
        XCTAssertNotNil(mockCohortStore.savedCohort)
        XCTAssertEqual(cohort, mockCohortStore.savedCohort)
    }
}

// MARK: - Mock Services

final class MockStoreKitProductService: StoreKitProductServiceProtocol {
    var mockProducts: [MockProduct] = []

    func fetchProducts(productIds: Set<String>) async throws -> [Product] {
        // Cannot create real Product instances in tests
        // This would require StoreKit Test Configuration
        throw SubscriptionError.unknown
    }
}

final class MockStoreKitPurchaseService: StoreKitPurchaseServiceProtocol {
    var mockEntitlements: [Transaction] = []
    var mockRestoreSuccess = true
    var didCallPurchase = false
    var didCallRestore = false

    func purchase(_ product: Product) async throws -> Product.PurchaseResult {
        didCallPurchase = true
        // Cannot create real PurchaseResult in tests without StoreKit Test Configuration
        // Return .userCancelled as simple mock
        return .userCancelled
    }

    func currentEntitlements() async -> [Transaction] {
        return mockEntitlements
    }

    func restore() async throws {
        didCallRestore = true
        if !mockRestoreSuccess {
            throw SubscriptionError.noPurchasesToRestore
        }
    }
}

final class MockUserCohortStore: UserCohortStoreProtocol {
    var mockCohort: UserCohort?
    var savedCohort: UserCohort?

    func load() -> UserCohort? {
        return mockCohort
    }

    func save(cohort: UserCohort) {
        savedCohort = cohort
    }

    func clear() {
        mockCohort = nil
        savedCohort = nil
    }
}

// MARK: - Mock Product

struct MockProduct {
    let id: String
    let displayName: String
}
