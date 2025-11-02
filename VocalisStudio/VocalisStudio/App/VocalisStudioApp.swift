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

        // Reset recording count and delete all recordings for UI tests
        if CommandLine.arguments.contains("-UITestResetRecordingCount") {
            Logger.viewModel.info("UI Test mode detected: Resetting recording count and deleting all recordings")
            RecordingUsageTracker().resetForTesting()

            // Delete all existing recordings
            Task {
                do {
                    let allRecordings = try await DependencyContainer.shared.recordingRepository.findAll()
                    Logger.viewModel.info("Found \(allRecordings.count) recordings to delete")
                    for recording in allRecordings {
                        try await DependencyContainer.shared.recordingRepository.delete(recording.id)
                    }
                    Logger.viewModel.info("All recordings deleted successfully")
                } catch {
                    Logger.viewModel.error("Failed to delete recordings: \(error)")
                }
            }

            Logger.viewModel.info("Recording count reset complete")
        }
        #endif
    }

    public var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(DependencyContainer.shared.subscriptionViewModel)
        }
    }
}