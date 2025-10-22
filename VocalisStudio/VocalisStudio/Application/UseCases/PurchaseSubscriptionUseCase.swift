//
//  PurchaseSubscriptionUseCase.swift
//  VocalisStudio
//
//  Use case for purchasing a subscription
//

import Foundation

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
        // Cannot purchase free tier
        guard tier != .free else {
            throw PurchaseError.cannotPurchaseFreeTier
        }

        // Purchase the product
        try await repository.purchaseProduct(productId: tier.productId)
    }
}
