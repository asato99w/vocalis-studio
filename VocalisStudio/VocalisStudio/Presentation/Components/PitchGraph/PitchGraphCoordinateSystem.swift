import SwiftUI

/// Pitch graph coordinate system calculations
/// Handles all coordinate transformations between frequency/time and canvas positions
public class PitchGraphCoordinateSystem {
    // MARK: - Initialization

    public init() {}

    // MARK: - Canvas Dimensions

    /// Calculate canvas height based on frequency range
    /// - Returns: Canvas height in points
    public func calculateCanvasHeight() -> CGFloat {
        let freqRange = PitchGraphConstants.maxFrequency - PitchGraphConstants.minFrequency
        let pixelsPerHz = PitchGraphConstants.pixelsPerHundredHz / 100.0
        let canvasHeight = CGFloat(freqRange) * pixelsPerHz
        return min(PitchGraphConstants.maxCanvasHeight, canvasHeight)
    }

    /// Calculate canvas width based on data duration
    /// - Parameters:
    ///   - dataDuration: Total duration of audio data in seconds
    ///   - leftPadding: Left padding for positioning data at screen center when time=0
    /// - Returns: Canvas width in points
    public func calculateCanvasWidth(dataDuration: Double, leftPadding: CGFloat) -> CGFloat {
        let dataWidth = CGFloat(dataDuration) * PitchGraphConstants.pixelsPerSecond
        return max(dataWidth + leftPadding, PitchGraphConstants.minCanvasWidth)
    }

    /// Calculate left padding for canvas
    /// Positions time=0 at screen center when canvasOffsetX=0
    /// - Parameter viewportWidth: Viewport width
    /// - Returns: Left padding in points
    public func calculateLeftPadding(viewportWidth: CGFloat) -> CGFloat {
        return viewportWidth / 2
    }

    // MARK: - Frequency Conversions

    /// Convert frequency to canvas Y coordinate
    /// Y=0: maxFrequency (top), Y=canvasHeight: minFrequency (bottom)
    /// - Parameters:
    ///   - frequency: Frequency in Hz
    ///   - canvasHeight: Canvas height in points
    /// - Returns: Canvas Y coordinate
    public func frequencyToCanvasY(frequency: Double, canvasHeight: CGFloat) -> CGFloat {
        let minFreq = PitchGraphConstants.minFrequency
        let maxFreq = PitchGraphConstants.maxFrequency

        // Clamp frequency to valid range
        let clampedFreq = max(minFreq, min(maxFreq, frequency))

        // Y=0 at top (maxFreq), Y=canvasHeight at bottom (minFreq)
        let ratio = (maxFreq - clampedFreq) / (maxFreq - minFreq)
        return CGFloat(ratio) * canvasHeight
    }

    /// Convert canvas Y coordinate to frequency
    /// - Parameters:
    ///   - y: Canvas Y coordinate
    ///   - canvasHeight: Canvas height in points
    /// - Returns: Frequency in Hz
    public func canvasYToFrequency(y: CGFloat, canvasHeight: CGFloat) -> Double {
        let minFreq = PitchGraphConstants.minFrequency
        let maxFreq = PitchGraphConstants.maxFrequency

        let ratio = Double(y / canvasHeight)
        return maxFreq - ratio * (maxFreq - minFreq)
    }

    // MARK: - Time Conversions

    /// Convert time to canvas X coordinate
    /// - Parameters:
    ///   - time: Time in seconds
    ///   - leftPadding: Left padding for canvas
    /// - Returns: Canvas X coordinate
    public func timeToCanvasX(time: Double, leftPadding: CGFloat) -> CGFloat {
        return CGFloat(time) * PitchGraphConstants.pixelsPerSecond + leftPadding
    }

    /// Convert canvas X coordinate to time
    /// - Parameters:
    ///   - x: Canvas X coordinate
    ///   - leftPadding: Left padding for canvas
    /// - Returns: Time in seconds
    public func canvasXToTime(x: CGFloat, leftPadding: CGFloat) -> Double {
        return Double((x - leftPadding) / PitchGraphConstants.pixelsPerSecond)
    }

    // MARK: - Viewport Calculations

    /// Calculate viewport coordinates from canvas coordinates
    /// - Parameters:
    ///   - canvasX: Canvas X coordinate
    ///   - canvasY: Canvas Y coordinate
    ///   - canvasOffsetX: Canvas X offset (scroll position)
    ///   - paperTop: Canvas Y offset (scroll position)
    /// - Returns: Viewport coordinates as CGPoint
    public func canvasToViewport(
        canvasX: CGFloat,
        canvasY: CGFloat,
        canvasOffsetX: CGFloat,
        paperTop: CGFloat
    ) -> CGPoint {
        let viewportX = canvasX + canvasOffsetX
        let viewportY = canvasY + paperTop
        return CGPoint(x: viewportX, y: viewportY)
    }

    // MARK: - Label Positions

    /// Get frequency label Y positions for rendering
    /// - Parameter canvasHeight: Canvas height
    /// - Returns: Array of (frequency, canvasY) tuples
    public func getFrequencyLabelPositions(canvasHeight: CGFloat) -> [(frequency: Double, canvasY: CGFloat)] {
        var positions: [(Double, CGFloat)] = []

        let interval = PitchGraphConstants.frequencyLabelInterval
        let minFreq = PitchGraphConstants.minFrequency
        let maxFreq = PitchGraphConstants.maxFrequency

        // Start from first interval above minFreq
        var freq = ceil(minFreq / interval) * interval

        // Skip minFreq if it's exactly on the interval
        if freq == minFreq {
            freq += interval
        }

        while freq < maxFreq {  // Use < instead of <= to exclude maxFreq
            let y = frequencyToCanvasY(frequency: freq, canvasHeight: canvasHeight)
            positions.append((freq, y))
            freq += interval
        }

        return positions
    }

    /// Get time label X positions for rendering
    /// - Parameters:
    ///   - dataDuration: Total duration of audio data
    ///   - leftPadding: Left padding for canvas
    /// - Returns: Array of (time, canvasX) tuples
    public func getTimeLabelPositions(dataDuration: Double, leftPadding: CGFloat) -> [(time: Double, canvasX: CGFloat)] {
        var positions: [(Double, CGFloat)] = []

        let interval = PitchGraphConstants.timeLabelInterval

        // Start from 0
        var time: Double = 0

        while time <= dataDuration {
            let x = timeToCanvasX(time: time, leftPadding: leftPadding)
            positions.append((time, x))
            time += interval
        }

        return positions
    }
}
