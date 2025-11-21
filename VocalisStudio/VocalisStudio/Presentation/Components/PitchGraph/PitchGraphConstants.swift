import SwiftUI

/// Pitch graph visualization constants
/// Centralizes all hard-coded values for pitch graph rendering and coordinate system
public struct PitchGraphConstants {
    // MARK: - Frequency Range

    /// Minimum frequency for pitch graph (Hz)
    /// Start from 0Hz for visual reference
    public static let minFrequency: Double = 0.0

    /// Maximum frequency for pitch graph (Hz)
    /// Vocal analysis: 1000Hz (female high range + margin)
    public static let maxFrequency: Double = 1000.0

    // MARK: - Display Density

    /// Pixels per 100Hz for frequency axis
    /// Higher zoom for detailed pitch analysis (120pt/100Hz = 1200pt/kHz)
    public static let pixelsPerHundredHz: CGFloat = 120.0

    /// Pixels per second for time axis
    /// Matches spectrogram time axis density
    public static let pixelsPerSecond: CGFloat = 300.0

    // MARK: - Canvas Limits

    /// Maximum canvas height to prevent memory issues
    public static let maxCanvasHeight: CGFloat = 5000.0

    /// Minimum canvas width
    public static let minCanvasWidth: CGFloat = 100.0

    // MARK: - Labels

    /// Frequency label interval in Hz
    public static let frequencyLabelInterval: Double = 100.0

    /// Time label interval in seconds
    public static let timeLabelInterval: Double = 0.5

    // MARK: - Margins

    /// Left margin for Y-axis labels
    public static let leftMargin: CGFloat = 50.0

    /// Bottom margin for X-axis labels
    public static let bottomMargin: CGFloat = 30.0

    /// Top margin
    public static let topMargin: CGFloat = 10.0

    /// Right margin
    public static let rightMargin: CGFloat = 10.0

    // MARK: - Visual Elements

    /// Pitch dot minimum radius
    public static let minDotRadius: CGFloat = 2.0

    /// Pitch dot maximum radius
    public static let maxDotRadius: CGFloat = 4.0

    /// Line width for pitch graph
    public static let pitchLineWidth: CGFloat = 1.5

    /// Target scale line width
    public static let targetLineWidth: CGFloat = 1.0

    /// Playback position line width
    public static let playbackLineWidth: CGFloat = 2.0

    // MARK: - Colors

    /// Pitch line color
    public static let pitchLineColor = Color.cyan

    /// Target scale line color
    public static let targetLineColor = Color.gray.opacity(0.3)

    /// Playback position line color
    public static let playbackLineColor = Color.white

    /// Frequency label color
    public static let frequencyLabelColor = Color.gray

    /// Time label color
    public static let timeLabelColor = Color.gray

    // MARK: - Calculated Properties

    /// Calculate canvas height based on frequency range
    /// Returns: Canvas height in points
    public static var calculatedCanvasHeight: CGFloat {
        let freqRange = maxFrequency - minFrequency
        let pixelsPerHz = pixelsPerHundredHz / 100.0
        let height = CGFloat(freqRange) * pixelsPerHz
        return min(maxCanvasHeight, height)
    }
}
