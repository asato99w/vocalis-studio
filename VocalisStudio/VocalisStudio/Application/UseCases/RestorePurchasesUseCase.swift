//
//  RestorePurchasesUseCase.swift
//  VocalisStudio
//
//  Use case for restoring previous purchases
//

import Foundation

/// Use case that restores previous subscription purchases
public final class RestorePurchasesUseCase {
    private let repository: SubscriptionRepositoryProtocol

    public init(repository: SubscriptionRepositoryProtocol) {
        self.repository = repository
    }

    /// Execute the use case to restore previous purchases
    /// - Throws: SubscriptionError if restore fails or no purchases found
    public func execute() async throws {
        try await repository.restorePurchases()
    }
}
