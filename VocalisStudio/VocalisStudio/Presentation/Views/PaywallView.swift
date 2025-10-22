//
//  PaywallView.swift
//  VocalisStudio
//
//  Paywall screen for subscription tiers
//

import SwiftUI

public struct PaywallView: View {

    @StateObject private var viewModel: PaywallViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: PaywallViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection

                        // Tier Cards
                        ForEach(viewModel.availableTiers, id: \.self) { tier in
                            TierCard(
                                tier: tier,
                                isSelected: viewModel.selectedTier == tier,
                                isRecommended: viewModel.isRecommended(tier),
                                features: viewModel.features(for: tier),
                                onSelect: { viewModel.selectTier(tier) }
                            )
                        }

                        // Purchase Button
                        purchaseButton

                        // Restore Button
                        restoreButton

                        // Terms and Privacy
                        termsSection
                    }
                    .padding()
                }

                // Loading Overlay
                if viewModel.isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
            }
            .navigationTitle("プレミアムプラン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.hasActiveSubscription {
                        Button("閉じる") {
                            dismiss()
                        }
                    }
                }
            }
            .alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .alert("購入完了", isPresented: .constant(viewModel.isPurchaseSuccessful)) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("サブスクリプションの購入が完了しました。")
            }
        }
        .task {
            await viewModel.loadStatus()
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)

            Text("すべての機能を解放")
                .font(.title2)
                .fontWeight(.bold)

            Text("プレミアムプランで本格的なボイストレーニング")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }

    private var purchaseButton: some View {
        Button {
            Task {
                await viewModel.purchaseSelectedTier()
            }
        } label: {
            Text("購入する")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .cornerRadius(12)
        }
        .disabled(viewModel.isLoading)
    }

    private var restoreButton: some View {
        Button {
            Task {
                await viewModel.restorePurchases()
            }
        } label: {
            Text("購入の復元")
                .font(.subheadline)
                .foregroundColor(.accentColor)
        }
        .disabled(viewModel.isLoading)
    }

    private var termsSection: some View {
        VStack(spacing: 8) {
            Text("購入により利用規約とプライバシーポリシーに同意したものとみなされます")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button("利用規約") {
                    // Open terms URL
                }
                .font(.caption)

                Button("プライバシーポリシー") {
                    // Open privacy URL
                }
                .font(.caption)
            }
        }
        .padding(.top)
    }
}

// MARK: - Tier Card

private struct TierCard: View {
    let tier: SubscriptionTier
    let isSelected: Bool
    let isRecommended: Bool
    let features: [Feature]
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(tier.displayName)
                            .font(.title3)
                            .fontWeight(.bold)

                        if isRecommended {
                            Text("おすすめ")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange)
                                .cornerRadius(4)
                        }
                    }

                    Text(tier.priceDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }

            // Features
            VStack(alignment: .leading, spacing: 8) {
                ForEach(features, id: \.self) { feature in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .foregroundColor(.green)

                        Text(feature.displayName)
                            .font(.subheadline)

                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                )
                .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : Color.clear, radius: 8)
        )
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - SubscriptionTier Extensions

private extension SubscriptionTier {
    var priceDescription: String {
        switch self {
        case .free:
            return "無料"
        case .premium:
            return "¥480/月"
        case .premiumPlus:
            return "¥980/月"
        }
    }
}

// MARK: - Preview

#Preview {
    PaywallView(
        viewModel: PaywallViewModel(
            getStatusUseCase: PreviewGetStatusUseCase(),
            purchaseUseCase: PreviewPurchaseUseCase(),
            restoreUseCase: PreviewRestoreUseCase()
        )
    )
}

// MARK: - Preview Use Cases

private final class PreviewGetStatusUseCase: GetSubscriptionStatusUseCaseProtocol {
    func execute() async throws -> SubscriptionStatus {
        return SubscriptionStatus.defaultFree(cohort: .v2_0)
    }
}

private final class PreviewPurchaseUseCase: PurchaseSubscriptionUseCaseProtocol {
    func execute(tier: SubscriptionTier) async throws {
        // Preview mock
    }
}

private final class PreviewRestoreUseCase: RestorePurchasesUseCaseProtocol {
    func execute() async throws {
        // Preview mock
    }
}
