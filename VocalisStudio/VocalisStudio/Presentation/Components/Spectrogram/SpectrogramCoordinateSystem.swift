import SwiftUI

/// Spectrogram canvas coordinate system
/// Handles all coordinate calculations and conversions for spectrogram visualization
public class SpectrogramCoordinateSystem {
    // MARK: - Constants

    /// Pixels per kHz for frequency axis (9.6x zoom from original 60pt/kHz)
    private let basePixelsPerKHz: CGFloat = 576.0

    /// Maximum canvas height to prevent memory issues
    private let maxCanvasHeight: CGFloat = 10000.0

    /// Maximum frequency for display (matches analyzed data range)
    private let maxFrequency: Double = 6000.0

    /// Pixels per second for time axis (6x zoom from original 50pt/s)
    private let pixelsPerSecond: CGFloat = 300.0

    // MARK: - Initialization

    public init() {}

    // MARK: - Canvas Dimensions

    /// Calculate canvas height based on frequency range
    /// Canvas contains entire frequency range (0Hz ~ maxFreq)
    /// - Parameters:
    ///   - maxFreq: Maximum frequency in Hz (UI display limit, not data limit)
    ///   - viewportHeight: Unused (kept for API compatibility), canvas size is data-driven
    /// - Returns: Canvas height in points
    public func calculateCanvasHeight(maxFreq: Double, viewportHeight: CGFloat) -> CGFloat {
        // Pixel density maintained for detailed frequency analysis (9.6x from original 60pt/kHz)
        // With maxFreq=6kHz: 6 × 576 = 3456pt canvas (full data range 0-6kHz displayed)
        let canvasHeight = CGFloat(maxFreq / 1000.0) * basePixelsPerKHz

        // Apply maximum limit to prevent excessive memory usage
        return min(maxCanvasHeight, canvasHeight)
    }

    /// Calculate canvas width based on data duration
    /// - Parameters:
    ///   - dataDuration: Recording duration in seconds
    ///   - leftPadding: Left padding for canvas (to position initial data at viewport center)
    /// - Returns: Canvas width in points
    public func calculateCanvasWidth(dataDuration: Double, leftPadding: CGFloat) -> CGFloat {
        let dataWidth = CGFloat(dataDuration) * pixelsPerSecond
        return max(dataWidth + leftPadding, 100)  // Include left padding, minimum 100pt
    }

    // MARK: - Frequency Axis Conversions

    /// Convert frequency (Hz) to Canvas Y coordinate
    /// Canvas coordinate system: Y=0 at top (maxFreq), Y=canvasHeight at bottom (0Hz)
    /// - Parameters:
    ///   - frequency: Frequency in Hz
    ///   - canvasHeight: Total canvas height in points
    ///   - maxFreq: Maximum frequency in Hz
    /// - Returns: Y coordinate in canvas space
    public func frequencyToCanvasY(frequency: Double, canvasHeight: CGFloat, maxFreq: Double) -> CGFloat {
        let ratio = (maxFreq - frequency) / maxFreq
        return CGFloat(ratio) * canvasHeight
    }

    /// Get maximum frequency for display (fixed UI limit)
    /// - Returns: Fixed maximum frequency for UI display (6kHz)
    /// - Note: This is a UI design decision, not data-driven.
    ///         Keeping display range fixed provides stable UI and predictable scrolling.
    public func getMaxFrequency() -> Double {
        // Both views show full analyzed range (6kHz) to display all frequency data
        return maxFrequency  // 6kHz (matches data range)
    }

    // MARK: - Time Axis Conversions

    /// Convert time to canvas X coordinate
    /// - Parameters:
    ///   - time: Time in seconds
    ///   - leftPadding: Left padding offset for canvas
    /// - Returns: X coordinate in canvas space
    public func timeToCanvasX(time: Double, leftPadding: CGFloat) -> CGFloat {
        return CGFloat(time) * pixelsPerSecond + leftPadding
    }

    /// Get pixels per second (time axis density)
    /// - Returns: Pixels per second for time axis rendering
    public func getPixelsPerSecond() -> CGFloat {
        return pixelsPerSecond
    }
}
