//
//  StoreKitSubscriptionRepository.swift
//  VocalisStudio
//
//  StoreKit-based implementation of SubscriptionRepositoryProtocol
//

import Foundation
import StoreKit

/// StoreKit implementation of subscription repository
@available(iOS 15.0, *)
public final class StoreKitSubscriptionRepository: SubscriptionRepositoryProtocol {
    private let productService: StoreKitProductServiceProtocol
    private let purchaseService: StoreKitPurchaseServiceProtocol
    private let cohortStore: UserCohortStoreProtocol

    public init(
        productService: StoreKitProductServiceProtocol,
        purchaseService: StoreKitPurchaseServiceProtocol,
        cohortStore: UserCohortStoreProtocol
    ) {
        self.productService = productService
        self.purchaseService = purchaseService
        self.cohortStore = cohortStore
    }

    // MARK: - SubscriptionRepositoryProtocol

    public func getCurrentStatus() async throws -> SubscriptionStatus {
        // Get or determine user cohort
        let cohort = try await getUserCohort()

        // Get current entitlements
        let entitlements = await purchaseService.currentEntitlements()

        // Find active subscription if any
        guard let activeTransaction = entitlements.first else {
            // No active subscription - return free tier
            return SubscriptionStatus.defaultFree(cohort: cohort)
        }

        // Determine tier from product ID
        let tier = determineTier(from: activeTransaction.productID)

        // Check if subscription is active
        let expirationDate = activeTransaction.expirationDate
        let isActive = expirationDate.map { $0 > Date() } ?? true

        return SubscriptionStatus(
            tier: tier,
            cohort: cohort,
            isActive: isActive,
            expirationDate: expirationDate,
            purchaseDate: activeTransaction.purchaseDate,
            willAutoRenew: activeTransaction.isUpgraded == false
        )
    }

    public func purchaseProduct(productId: String) async throws {
        // Fetch product
        let products = try await productService.fetchProducts(productIds: [productId])

        guard let product = products.first else {
            throw SubscriptionError.productNotFound
        }

        // Purchase product
        let result = try await purchaseService.purchase(product)

        switch result {
        case .success(let verification):
            // Verify transaction
            guard case .verified = verification else {
                throw SubscriptionError.purchaseFailed("Transaction verification failed")
            }
            // Purchase successful

        case .pending:
            throw SubscriptionError.purchaseFailed("Purchase is pending")

        case .userCancelled:
            throw SubscriptionError.purchaseFailed("User cancelled")

        @unknown default:
            throw SubscriptionError.unknown
        }
    }

    public func restorePurchases() async throws {
        // Sync with App Store
        try await purchaseService.restore()

        // Check if we have any entitlements after restore
        let entitlements = await purchaseService.currentEntitlements()

        guard !entitlements.isEmpty else {
            throw SubscriptionError.noPurchasesToRestore
        }
    }

    public func getUserCohort() async throws -> UserCohort {
        // Check if cohort is already stored
        if let storedCohort = cohortStore.load() {
            return storedCohort
        }

        // Determine cohort based on current date (first installation)
        let cohort = UserCohort.determine(from: Date())

        // Save cohort for future use
        cohortStore.save(cohort: cohort)

        return cohort
    }

    // MARK: - Private Helpers

    private func determineTier(from productId: String) -> SubscriptionTier {
        switch productId {
        case SubscriptionTier.premium.productId:
            return .premium
        case SubscriptionTier.premiumPlus.productId:
            return .premiumPlus
        default:
            return .free
        }
    }
}
