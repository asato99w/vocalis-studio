import SwiftUI

/// Main tab view containing Recording and Settings tabs
struct MainTabView: View {
    private let dependencyContainer: DependencyContainer
    
    init(dependencyContainer: DependencyContainer) {
        self.dependencyContainer = dependencyContainer
    }
    
    var body: some View {
        TabView {
            // Recording Tab
            RecordingView(viewModel: dependencyContainer.recordingViewModel)
                .tabItem {
                    Image(systemName: "mic.fill")
                    Text("navigation.recording".localized)
                }
            
            // Settings Tab
            SettingsView(viewModel: dependencyContainer.settingsViewModel)
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("navigation.settings".localized)
                }
        }
        .accentColor(.blue)
    }
}