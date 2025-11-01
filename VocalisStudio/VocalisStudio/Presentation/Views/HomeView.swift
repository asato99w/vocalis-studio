import SwiftUI
import VocalisDomain

/// Home screen - main entry point with navigation to all features
public struct HomeView: View {
    @StateObject private var localization = LocalizationManager.shared

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(red: 0.42, green: 0.36, blue: 0.90), Color(red: 0.58, green: 0.29, blue: 0.76)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 40) {
                    Spacer()

                    // App Logo and Title
                    VStack(spacing: 16) {
                        Image(systemName: "music.mic")
                            .font(.system(size: 80))
                            .foregroundColor(.white)

                        Text("app_name".localized)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
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

                    // Debug button (only in debug builds) - unobtrusive
                    #if DEBUG
                    NavigationLink(destination: DebugMenuView()) {
                        HStack(spacing: 4) {
                            Image(systemName: "ant.fill")
                                .font(.system(size: 10))
                            Text("Debug")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .padding(.bottom, 8)
                    #endif
                }
            }
            .navigationBarHidden(true)
        }
    }
}

/// Custom menu button component
struct MenuButton: View {
    let title: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white.opacity(0.2))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#if DEBUG
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
#endif
