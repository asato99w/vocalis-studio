import SwiftUI

/// Pitch graph rendering logic
/// Handles all drawing operations for pitch graph visualization
public class PitchGraphRenderer {
    private let coordinateSystem: PitchGraphCoordinateSystem

    // MARK: - Initialization

    public init(coordinateSystem: PitchGraphCoordinateSystem = PitchGraphCoordinateSystem()) {
        self.coordinateSystem = coordinateSystem
    }

    // MARK: - Main Drawing

    /// Draw pitch data points and lines
    /// - Parameters:
    ///   - context: Graphics context
    ///   - canvasHeight: Canvas height
    ///   - pitchData: Array of (time, frequency, confidence) tuples
    ///   - leftPadding: Left padding for canvas
    public func drawPitchData(
        context: GraphicsContext,
        canvasHeight: CGFloat,
        pitchData: [(time: Double, frequency: Double, confidence: Float)],
        leftPadding: CGFloat
    ) {
        guard !pitchData.isEmpty else { return }

        // Draw lines connecting pitch points
        var path = Path()
        var isFirstPoint = true

        for point in pitchData {
            let x = coordinateSystem.timeToCanvasX(time: point.time, leftPadding: leftPadding)
            let y = coordinateSystem.frequencyToCanvasY(frequency: point.frequency, canvasHeight: canvasHeight)

            if isFirstPoint {
                path.move(to: CGPoint(x: x, y: y))
                isFirstPoint = false
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.stroke(
            path,
            with: .color(PitchGraphConstants.pitchLineColor),
            lineWidth: PitchGraphConstants.pitchLineWidth
        )

        // Draw dots at each pitch point with size based on confidence
        for point in pitchData {
            let x = coordinateSystem.timeToCanvasX(time: point.time, leftPadding: leftPadding)
            let y = coordinateSystem.frequencyToCanvasY(frequency: point.frequency, canvasHeight: canvasHeight)

            // Calculate dot radius based on confidence
            let radius = PitchGraphConstants.minDotRadius +
                (PitchGraphConstants.maxDotRadius - PitchGraphConstants.minDotRadius) * CGFloat(point.confidence)

            let dotRect = CGRect(
                x: x - radius,
                y: y - radius,
                width: radius * 2,
                height: radius * 2
            )

            context.fill(
                Path(ellipseIn: dotRect),
                with: .color(PitchGraphConstants.pitchLineColor)
            )
        }
    }

    /// Draw target scale lines (reference frequencies)
    /// - Parameters:
    ///   - context: Graphics context
    ///   - canvasHeight: Canvas height
    ///   - targetFrequencies: Array of target frequencies in Hz
    ///   - leftPadding: Left padding for canvas
    ///   - canvasWidth: Canvas width
    public func drawTargetScaleLines(
        context: GraphicsContext,
        canvasHeight: CGFloat,
        targetFrequencies: [Double],
        leftPadding: CGFloat,
        canvasWidth: CGFloat
    ) {
        for frequency in targetFrequencies {
            // Check if frequency is within display range
            guard frequency >= PitchGraphConstants.minFrequency &&
                  frequency <= PitchGraphConstants.maxFrequency else { continue }

            let y = coordinateSystem.frequencyToCanvasY(frequency: frequency, canvasHeight: canvasHeight)

            var path = Path()
            path.move(to: CGPoint(x: leftPadding, y: y))
            path.addLine(to: CGPoint(x: canvasWidth, y: y))

            context.stroke(
                path,
                with: .color(PitchGraphConstants.targetLineColor),
                style: StrokeStyle(
                    lineWidth: PitchGraphConstants.targetLineWidth,
                    dash: [5, 3]  // 5pt line, 3pt gap
                )
            )
        }
    }

    // MARK: - Axis Labels

    /// Draw frequency labels (Y-axis)
    /// These labels are fixed in X direction but scroll with Y direction
    /// - Parameters:
    ///   - context: Graphics context
    ///   - canvasHeight: Canvas height
    ///   - viewportHeight: Viewport height (for clipping)
    ///   - paperTop: Y-axis scroll position
    public func drawFrequencyLabels(
        context: GraphicsContext,
        canvasHeight: CGFloat,
        viewportHeight: CGFloat,
        paperTop: CGFloat
    ) {
        let labelPositions = coordinateSystem.getFrequencyLabelPositions(canvasHeight: canvasHeight)

        for (frequency, canvasY) in labelPositions {
            let viewportY = canvasY + paperTop

            // Skip labels outside viewport
            guard viewportY >= -20 && viewportY <= viewportHeight + 20 else { continue }

            let labelText = "\(Int(frequency))Hz"

            // Draw label at fixed X position (left edge), scrolling Y position
            context.draw(
                Text(labelText)
                    .font(.system(size: 10))
                    .foregroundColor(PitchGraphConstants.frequencyLabelColor),
                at: CGPoint(x: 5, y: viewportY),
                anchor: .leading
            )

            // Draw grid line (optional)
            var gridPath = Path()
            gridPath.move(to: CGPoint(x: PitchGraphConstants.leftMargin - 5, y: viewportY))
            gridPath.addLine(to: CGPoint(x: PitchGraphConstants.leftMargin, y: viewportY))

            context.stroke(
                gridPath,
                with: .color(PitchGraphConstants.frequencyLabelColor.opacity(0.5)),
                lineWidth: 0.5
            )
        }
    }

    /// Draw time labels (X-axis)
    /// These labels are fixed in Y direction but scroll with X direction
    /// - Parameters:
    ///   - context: Graphics context
    ///   - dataDuration: Total duration of audio
    ///   - leftPadding: Left padding for canvas
    ///   - viewportWidth: Viewport width
    ///   - viewportHeight: Viewport height
    ///   - canvasOffsetX: X-axis scroll position
    public func drawTimeLabels(
        context: GraphicsContext,
        dataDuration: Double,
        leftPadding: CGFloat,
        viewportWidth: CGFloat,
        viewportHeight: CGFloat,
        canvasOffsetX: CGFloat
    ) {
        let labelPositions = coordinateSystem.getTimeLabelPositions(dataDuration: dataDuration, leftPadding: leftPadding)

        for (time, canvasX) in labelPositions {
            let viewportX = canvasX + canvasOffsetX

            // Skip labels outside viewport
            guard viewportX >= -30 && viewportX <= viewportWidth + 30 else { continue }

            let labelText = String(format: "%.1fs", time)

            // Draw label at scrolling X position, fixed Y position (bottom)
            let labelY = viewportHeight - PitchGraphConstants.bottomMargin / 2

            context.draw(
                Text(labelText)
                    .font(.system(size: 10))
                    .foregroundColor(PitchGraphConstants.timeLabelColor),
                at: CGPoint(x: viewportX, y: labelY),
                anchor: .center
            )
        }
    }

    // MARK: - Playback Position

    /// Draw playback position line
    /// This line is fully fixed at screen center
    /// - Parameters:
    ///   - context: Graphics context
    ///   - viewportWidth: Viewport width
    ///   - viewportHeight: Viewport height
    public func drawPlaybackPosition(
        context: GraphicsContext,
        viewportWidth: CGFloat,
        viewportHeight: CGFloat
    ) {
        let centerX = viewportWidth / 2

        var path = Path()
        path.move(to: CGPoint(x: centerX, y: 0))
        path.addLine(to: CGPoint(x: centerX, y: viewportHeight - PitchGraphConstants.bottomMargin))

        context.stroke(
            path,
            with: .color(PitchGraphConstants.playbackLineColor),
            lineWidth: PitchGraphConstants.playbackLineWidth
        )
    }

    // MARK: - Placeholder

    /// Draw placeholder when no data available
    /// - Parameters:
    ///   - context: Graphics context
    ///   - size: View size
    public func drawPlaceholder(context: GraphicsContext, size: CGSize) {
        context.draw(
            Text("No pitch data")
                .font(.caption)
                .foregroundColor(.gray),
            at: CGPoint(x: size.width / 2, y: size.height / 2),
            anchor: .center
        )
    }

    // MARK: - Background

    /// Draw graph background with grid
    /// - Parameters:
    ///   - context: Graphics context
    ///   - canvasHeight: Canvas height
    ///   - canvasWidth: Canvas width
    ///   - leftPadding: Left padding
    public func drawBackground(
        context: GraphicsContext,
        canvasHeight: CGFloat,
        canvasWidth: CGFloat,
        leftPadding: CGFloat
    ) {
        // Draw horizontal grid lines at each frequency label position
        let labelPositions = coordinateSystem.getFrequencyLabelPositions(canvasHeight: canvasHeight)

        for (_, canvasY) in labelPositions {
            var gridPath = Path()
            gridPath.move(to: CGPoint(x: leftPadding, y: canvasY))
            gridPath.addLine(to: CGPoint(x: canvasWidth, y: canvasY))

            context.stroke(
                gridPath,
                with: .color(Color.gray.opacity(0.1)),
                lineWidth: 0.5
            )
        }
    }
}
