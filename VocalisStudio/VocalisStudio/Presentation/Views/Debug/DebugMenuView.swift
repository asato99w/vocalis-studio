import SwiftUI
import SubscriptionDomain
import VocalisDomain

#if DEBUG
/// Debug menu for development and testing
struct DebugMenuView: View {
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel
    @State private var showingResetAlert = false

    var body: some View {
        List {
            Section(header: Text("Test Screens")) {
                NavigationLink(destination: PaywallView(
                    viewModel: DependencyContainer.shared.paywallViewModel
                )) {
                    Label("プレミアムプラン (Paywall)", systemImage: "star.circle.fill")
                }

                NavigationLink(destination: SubscriptionManagementView(
                    viewModel: DependencyContainer.shared.subscriptionViewModel
                )) {
                    Label("サブスクリプション管理", systemImage: "creditcard.fill")
                }
            }

            Section(header: Text("Subscription Debug")) {
                debugTierPicker
                resetUsageButton
            }

            Section(header: Text("Current Status")) {
                currentStatusInfo
            }
        }
        .navigationTitle("Debug Menu")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Always reload subscription status to get the latest state
            await subscriptionViewModel.loadStatus()
        }
        .alert("Reset Usage", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetUsage()
            }
        } message: {
            Text("録音回数がリセットされます。よろしいですか?")
        }
    }
    // MARK: - Debug Tier Picker

    private var debugTierPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Tier Switch")
                .font(.subheadline)
                .foregroundColor(ColorPalette.text.opacity(0.6))

            if let currentTier = subscriptionViewModel.currentStatus?.tier {
                Picker("Tier", selection: Binding(
                    get: { currentTier },
                    set: { newTier in
                        Task {
                            await switchTier(to: newTier)
                        }
                    }
                )) {
                    Text("Free").tag(SubscriptionTier.free)
                    Text("Premium").tag(SubscriptionTier.premium)
                    Text("Premium Plus").tag(SubscriptionTier.premiumPlus)
                }
                .pickerStyle(.segmented)

                Text("現在: \(currentTier.displayName)")
                    .font(.caption)
                    .foregroundColor(ColorPalette.text.opacity(0.6))
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var resetUsageButton: some View {
        Button(action: {
            showingResetAlert = true
        }) {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                Text("録音回数をリセット")
                Spacer()
            }
        }
        .foregroundColor(Color.orange)
    }

    // MARK: - Current Status Info

    private var currentStatusInfo: some View {
        Group {
            if let status = subscriptionViewModel.currentStatus {
                HStack {
                    Text("Current Tier")
                    Spacer()
                    Text(status.tier.displayName)
                        .foregroundColor(ColorPalette.text.opacity(0.6))
                }

                HStack {
                    Text("Cohort")
                    Spacer()
                    Text(status.cohort.rawValue)
                        .foregroundColor(ColorPalette.text.opacity(0.6))
                }
            } else {
                Text("Loading...")
                    .foregroundColor(ColorPalette.text.opacity(0.6))
            }
        }
    }

    // MARK: - Actions

    private func switchTier(to tier: SubscriptionTier) async {
        subscriptionViewModel.setDebugTier(tier)
    }

    private func resetUsage() {
        let tracker = RecordingUsageTracker()
        tracker.resetForTesting()
    }
}
#endif

#if DEBUG
struct DebugMenuView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            DebugMenuView()
                .environmentObject(DependencyContainer.shared.subscriptionViewModel)
        }
    }
}
#endif
