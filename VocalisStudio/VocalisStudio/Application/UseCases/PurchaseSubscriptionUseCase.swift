//
//  PurchaseSubscriptionUseCase.swift
//  VocalisStudio
//
//  Use case for purchasing a subscription
//

import Foundation
import SubscriptionDomain

/// Error types for subscription purchase
public enum PurchaseError: Error, Equatable {
    case cannotPurchaseFreeTier
}

/// Use case that handles subscription purchase
public final class PurchaseSubscriptionUseCase {
    private let repository: SubscriptionRepositoryProtocol

    public init(repository: SubscriptionRepositoryProtocol) {
        self.repository = repository
    }

    /// Execute the use case to purchase a subscription
    /// - Parameter tier: Subscription tier to purchase
    /// - Throws: PurchaseError if tier is free, SubscriptionError from repository
    public func execute(tier: SubscriptionTier) async throws {
        FileLogger.shared.log(level: "INFO", category: "purchase", message: "[usecase] 🛒 PurchaseSubscriptionUseCase.execute() called with tier: \(tier)")

        // Cannot purchase free tier
        guard tier != .free else {
            FileLogger.shared.log(level: "ERROR", category: "purchase", message: "[usecase] ❌ Cannot purchase free tier")
            throw PurchaseError.cannotPurchaseFreeTier
        }

        FileLogger.shared.log(level: "INFO", category: "purchase", message: "[usecase] 🛒 Calling repository.purchaseProduct(productId: \(tier.productId))")
        // Purchase the product
        try await repository.purchaseProduct(productId: tier.productId)
        FileLogger.shared.log(level: "INFO", category: "purchase", message: "[usecase] ✅ repository.purchaseProduct() completed successfully")
    }
}
