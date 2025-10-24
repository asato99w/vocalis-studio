//
//  SubscriptionManagementView.swift
//  VocalisStudio
//
//  Subscription management screen for existing subscribers
//

import SwiftUI
import SubscriptionDomain

public struct SubscriptionManagementView: View {

    @StateObject private var viewModel: SubscriptionViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: SubscriptionViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        if let status = viewModel.currentStatus {
                            // Current Status Card
                            currentStatusCard(status: status)

                            // Features Access
                            featuresSection

                            // Management Actions
                            actionsSection
                        } else {
                            noSubscriptionView
                        }
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
            .navigationTitle("サブスクリプション管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
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
        }
        .task {
            await viewModel.loadStatus()
        }
    }

    // MARK: - Sections

    private func currentStatusCard(status: SubscriptionStatus) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(status.tier.displayName)
                        .font(.title2)
                        .fontWeight(.bold)

                    if status.tier != .free {
                        Text(status.isActive ? "有効" : "無効")
                            .font(.subheadline)
                            .foregroundColor(status.isActive ? .green : .secondary)
                    }
                }

                Spacer()

                Image(systemName: tierIcon(for: status.tier))
                    .font(.largeTitle)
                    .foregroundColor(tierColor(for: status.tier))
            }

            Divider()

            // Details
            VStack(alignment: .leading, spacing: 12) {
                if status.tier != .free {
                    DetailRow(
                        title: "購入日",
                        value: status.purchaseDate.map { formatDate($0) } ?? "—"
                    )

                    DetailRow(
                        title: "有効期限",
                        value: status.expirationDate.map { formatDate($0) } ?? "—"
                    )

                    DetailRow(
                        title: "自動更新",
                        value: status.willAutoRenew ? "ON" : "OFF"
                    )
                }

                DetailRow(
                    title: "コホート",
                    value: status.cohort.displayName
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 4)
        )
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("利用可能な機能")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Feature.allCases, id: \.self) { feature in
                    FeatureRow(
                        feature: feature,
                        hasAccess: viewModel.hasAccessTo(feature)
                    )
                }
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 16) {
            // Restore Button
            Button {
                Task {
                    await viewModel.restorePurchases()
                }
            } label: {
                Label("購入の復元", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accentColor, lineWidth: 1)
                    )
            }
            .disabled(viewModel.isLoading)

            // App Store Management
            Button {
                openAppStoreManagement()
            } label: {
                Label("App Storeで管理", systemImage: "bag")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(12)
            }
        }
    }

    private var noSubscriptionView: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("サブスクリプション情報が見つかりません")
                .font(.headline)

            Button {
                Task {
                    await viewModel.loadStatus()
                }
            } label: {
                Text("再読み込み")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(12)
            }
        }
        .padding()
    }

    // MARK: - Helper Methods

    private func tierIcon(for tier: SubscriptionTier) -> String {
        switch tier {
        case .free:
            return "person.circle"
        case .premium:
            return "star.circle.fill"
        case .premiumPlus:
            return "crown.fill"
        }
    }

    private func tierColor(for tier: SubscriptionTier) -> Color {
        switch tier {
        case .free:
            return .secondary
        case .premium:
            return .blue
        case .premiumPlus:
            return .yellow
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    private func openAppStoreManagement() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let feature: Feature
    let hasAccess: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: hasAccess ? "checkmark.circle.fill" : "lock.circle.fill")
                .foregroundColor(hasAccess ? .green : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.displayName)
                    .font(.subheadline)

                Text(feature.minimumTier.displayName + "以上")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .opacity(hasAccess ? 1.0 : 0.6)
    }
}

// MARK: - Preview

#Preview {
    SubscriptionManagementView(
        viewModel: SubscriptionViewModel(
            getStatusUseCase: PreviewGetStatusUseCase(),
            purchaseUseCase: PreviewPurchaseUseCase(),
            restoreUseCase: PreviewRestoreUseCase()
        )
    )
}

// MARK: - Preview Use Cases

private final class PreviewGetStatusUseCase: GetSubscriptionStatusUseCaseProtocol {
    func execute() async throws -> SubscriptionStatus {
        return SubscriptionStatus(
            tier: .premium,
            cohort: .v2_0,
            isActive: true,
            expirationDate: Date().addingTimeInterval(30 * 24 * 60 * 60),
            purchaseDate: Date(),
            willAutoRenew: true
        )
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
