import SwiftUI

/// Settings screen - language selection and app information
public struct SettingsView: View {
    @StateObject private var localization = LocalizationManager.shared
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel

    public init() {}

    public var body: some View {
        Form {
            // Subscription Section
            Section("サブスクリプション") {
                HStack {
                    Label("現在のプラン", systemImage: "crown.fill")
                    Spacer()
                    Text(subscriptionViewModel.currentStatus?.tier == .premium ? "プレミアム" : "無料")
                        .foregroundColor(subscriptionViewModel.currentStatus?.tier == .premium ? .green : ColorPalette.text.opacity(0.6))
                }

                NavigationLink {
                    SubscriptionManagementView(viewModel: subscriptionViewModel)
                } label: {
                    Label("サブスクリプションを管理", systemImage: "gear")
                }
            }

            // Audio Settings Section
            Section("オーディオ設定") {
                NavigationLink {
                    AudioSettingsView(
                        viewModel: DependencyContainer.shared.makeAudioSettingsViewModel()
                    )
                } label: {
                    Label("音量・検出設定", systemImage: "speaker.wave.2")
                }
            }

            Section("settings.language_section".localized) {
                Picker("settings.language_label".localized, selection: $localization.currentLanguage) {
                    Text("settings.language_japanese".localized).tag("ja")
                    Text("settings.language_english".localized).tag("en")
                }
                .pickerStyle(.inline)
            }

            Section("settings.info_section".localized) {
                HStack {
                    Text("settings.version_label".localized)
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(ColorPalette.text.opacity(0.6))
                }
            }
        }
        .navigationTitle("settings.title".localized)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await subscriptionViewModel.loadStatus()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SettingsView()
                .environmentObject(DependencyContainer.shared.subscriptionViewModel)
        }
    }
}
#endif
