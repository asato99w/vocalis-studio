//
//  PurchaseSubscriptionUseCaseProtocol.swift
//  VocalisStudio
//
//  Protocol for purchase subscription use case
//

import Foundation

public protocol PurchaseSubscriptionUseCaseProtocol {
    func execute(tier: SubscriptionTier) async throws
}

extension PurchaseSubscriptionUseCase: PurchaseSubscriptionUseCaseProtocol {}
