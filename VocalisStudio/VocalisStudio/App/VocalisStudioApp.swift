import SwiftUI
import VocalisDomain
import OSLog

@available(iOS 15.0, macOS 11.0, *)
@main
public struct VocalisStudioApp: App {
    public init() {
        // Initialize file logging system (DEBUG builds only)
        #if DEBUG
        let logPath = FileLogger.shared.currentLogPath
        Logger.viewModel.info("File logging enabled")
        Logger.viewModel.info("Log file: \(logPath)")
        FileLogger.shared.log(level: "INFO", category: "system", message: "VocalisStudio started")
        #endif
    }

    public var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}