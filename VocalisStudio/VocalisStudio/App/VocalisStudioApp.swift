import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
@main
public struct VocalisStudioApp: App {
    public init() {}

    public var body: some Scene {
        WindowGroup {
            RecordingView(
                viewModel: DependencyContainer.shared.recordingViewModel
            )
        }
    }
}