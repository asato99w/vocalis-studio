import SwiftUI
import VocalisDomain

/// Home screen - main entry point with navigation to all features
/// Design: "Precision in Silence" - calm, professional, studio-like atmosphere
public struct HomeView: View {
    @StateObject private var localization = LocalizationManager.shared
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background: Adaptive background color for light/dark mode
                ColorPalette.background
                    .ignoresSafeArea()

                VStack(spacing: 40) {
                    Spacer()

                    // App Logo and Title
                    VStack(spacing: 16) {
                        // Temporary: Use system icon with design system styling until app icon asset is added
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(ColorPalette.primary)
                            .background(
                                Circle()
                                    .fill(ColorPalette.secondary)
                                    .frame(width: 120, height: 120)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)

                        Text("app_name".localized)
                            .font(Typography.headingLarge)
                            .foregroundColor(ColorPalette.text)
                    }

                    Spacer()

                    // Menu Buttons
                    VStack(spacing: 20) {
                        NavigationLink(destination: RecordingView(
                            viewModel: DependencyContainer.shared.recordingViewModel
                        )) {
                            MenuButton(title: "home.record_button".localized, icon: "mic.fill")
                        }
                        .accessibilityIdentifier("HomeRecordButton")

                        NavigationLink(destination: RecordingListView(
                            viewModel: RecordingListViewModel(
                                recordingRepository: DependencyContainer.shared.recordingRepository,
                                audioPlayer: DependencyContainer.shared.audioPlayer
                            ),
                            audioPlayer: DependencyContainer.shared.audioPlayer,
                            analyzeRecordingUseCase: DependencyContainer.shared.analyzeRecordingUseCase
                        )) {
                            MenuButton(title: "home.list_button".localized, icon: "list.bullet")
                        }
                        .accessibilityIdentifier("HomeListButton")

                        NavigationLink(destination: SettingsView()) {
                            MenuButton(title: "home.settings_button".localized, icon: "gearshape")
                        }
                        .accessibilityIdentifier("HomeSettingsButton")
                    }
                    .padding(.horizontal, 40)

                    Spacer()

                    // Upgrade Banner for free users
                    if subscriptionViewModel.currentStatus?.tier == .free {
                        UpgradeBanner()
                            .padding(.horizontal, 40)
                    }

                    // Debug button (only in debug builds) - unobtrusive
                    #if DEBUG
                    NavigationLink(destination: DebugMenuView()) {
                        HStack(spacing: 4) {
                            Image(systemName: "ant.fill")
                                .font(.system(size: 10))
                            Text("Debug")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(ColorPalette.text.opacity(0.3))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ColorPalette.text.opacity(0.05))
                        .cornerRadius(6)
                    }
                    .padding(.bottom, 8)
                    #endif
                }
            }
            .navigationBarHidden(true)
            .task {
                await subscriptionViewModel.loadStatus()
            }
        }
    }
}

/// Upgrade banner component for free users
private struct UpgradeBanner: View {
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel
    @State private var showPaywall = false

    var body: some View {
        Button(action: {
            showPaywall = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.yellow)

                VStack(alignment: .leading, spacing: 4) {
                    Text("無制限録音を解放")
                        .font(Typography.body)
                        .fontWeight(.semibold)
                    Text("プレミアムで回数制限なし")
                        .font(.system(size: 12))
                        .foregroundColor(ColorPalette.text.opacity(0.7))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(ColorPalette.text.opacity(0.5))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ColorPalette.alertActive.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ColorPalette.alertActive.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPaywall) {
            PaywallView(viewModel: DependencyContainer.shared.paywallViewModel)
        }
    }
}

/// Custom menu button component
/// Design: Primary color with subtle shadow for professional look
struct MenuButton: View {
    let title: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(Typography.bodyLarge)
            Text(title)
                .font(Typography.bodyLarge)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(ColorPalette.primary)  // Use design system primary color
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Preview

#if DEBUG
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(DependencyContainer.shared.subscriptionViewModel)
    }
}
#endif
