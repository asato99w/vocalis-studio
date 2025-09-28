import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
@main
public struct VocalisStudioApp: App {
    private let dependencyContainer = DependencyContainer.shared
    
    public init() {}
    
    public var body: some Scene {
        WindowGroup {
            MainTabView(dependencyContainer: dependencyContainer)
        }
    }
}