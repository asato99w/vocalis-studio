//
//  SubscriptionViewModel.swift
//  VocalisStudio
//
//  ViewModel for subscription management
//

import Foundation
import SubscriptionDomain
import Combine
import SubscriptionDomain

@MainActor
public final class SubscriptionViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var currentStatus: SubscriptionStatus?
    @Published public private(set) var isLoading = false
    @Published public var errorMessage: String?

    // MARK: - Dependencies

    private let getStatusUseCase: GetSubscriptionStatusUseCaseProtocol
    private let purchaseUseCase: PurchaseSubscriptionUseCaseProtocol
    private let restoreUseCase: RestorePurchasesUseCaseProtocol

    // MARK: - Initialization

    public init(
        getStatusUseCase: GetSubscriptionStatusUseCaseProtocol,
        purchaseUseCase: PurchaseSubscriptionUseCaseProtocol,
        restoreUseCase: RestorePurchasesUseCaseProtocol
    ) {
        self.getStatusUseCase = getStatusUseCase
        self.purchaseUseCase = purchaseUseCase
        self.restoreUseCase = restoreUseCase
    }

    // MARK: - Public Methods

    /// Load current subscription status
    public func loadStatus() async {
        isLoading = true
        errorMessage = nil

        do {
            currentStatus = try await getStatusUseCase.execute()
        } catch {
            errorMessage = error.localizedDescription
            currentStatus = nil
        }

        isLoading = false
    }

    /// Purchase a subscription tier
    public func purchase(tier: SubscriptionTier) async {
        isLoading = true
        errorMessage = nil

        do {
            try await purchaseUseCase.execute(tier: tier)
            // Refresh status after successful purchase
            await loadStatus()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    /// Restore previous purchases
    public func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        do {
            try await restoreUseCase.execute()
            // Refresh status after successful restore
            await loadStatus()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    /// Check if user has access to a feature
    public func hasAccessTo(_ feature: Feature) -> Bool {
        guard let status = currentStatus else {
            return false
        }
        return status.hasAccessTo(feature)
    }

    /// Clear error message
    public func clearError() {
        errorMessage = nil
    }

    // MARK: - Debug Methods

    #if DEBUG
    /// Set debug subscription tier (for testing only)
    public func setDebugTier(_ tier: SubscriptionTier) {
        let status = SubscriptionStatus(
            tier: tier,
            cohort: .v2_0,
            isActive: tier != .free,
            expirationDate: tier != .free ? Date().addingTimeInterval(30 * 24 * 60 * 60) : nil,
            purchaseDate: tier != .free ? Date() : nil,
            willAutoRenew: tier != .free
        )
        currentStatus = status
    }
    #endif
}
