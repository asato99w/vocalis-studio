import Foundation
import VocalisDomain

/// Coordinates scale playback operations with centralized state management
/// Provides single observation point for debugging scale-related issues
@MainActor
public class ScalePlaybackCoordinator {
    private let scalePlayer: ScalePlayerProtocol
    private(set) var currentSettings: ScaleSettings?

    public init(scalePlayer: ScalePlayerProtocol) {
        self.scalePlayer = scalePlayer
    }

    /// Start muted playback for target pitch monitoring
    /// - Parameter settings: Scale configuration
    public func startMutedPlayback(settings: ScaleSettings) async throws {
        // Stop any existing playback first to avoid conflicts
        await scalePlayer.stop()

        currentSettings = settings
        let scaleElements = settings.generateScaleWithKeyChange()
        try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)
        try await scalePlayer.play(muted: true)
    }

    /// Stop scale playback and clear state
    public func stopPlayback() async {
        await scalePlayer.stop()
        currentSettings = nil
    }

    /// Current scale element being played
    public var currentScaleElement: ScaleElement? {
        scalePlayer.currentScaleElement
    }
}
