//
//  PitchGraphView.swift
//  PoC
//
//  SwiftUI Canvas-based pitch graph visualization
//

import SwiftUI

struct PitchGraphView: View {
    let pitchData: [PitchData]
    let duration: TimeInterval
    let playbackPosition: TimeInterval?  // Optional: current playback position

    // Graph configuration
    private let minFrequency: Double = 80.0   // Hz
    private let maxFrequency: Double = 1000.0 // Hz
    private let padding: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pitch Graph")
                .font(.headline)

            if pitchData.isEmpty {
                emptyState
            } else {
                graphCanvas
                legend
            }
        }
    }

    private var emptyState: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
            Text("No pitch data")
                .foregroundColor(.gray)
        }
        .frame(height: 200)
    }

    private var graphCanvas: some View {
        Canvas { context, size in
            drawGraph(context: context, size: size)
        }
        .frame(height: 250)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private var legend: some View {
        HStack(spacing: 20) {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                Text("Detected Pitch")
                    .font(.caption)
            }

            if let avgFreq = averageFrequency {
                Text("Avg: \(Int(avgFreq)) Hz")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(pitchData.count) points")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 4)
    }

    private var averageFrequency: Double? {
        guard !pitchData.isEmpty else { return nil }
        let sum = pitchData.reduce(0.0) { $0 + $1.frequency }
        return sum / Double(pitchData.count)
    }

    // MARK: - Graph Drawing

    private func drawGraph(context: GraphicsContext, size: CGSize) {
        let graphWidth = size.width - padding * 2
        let graphHeight = size.height - padding * 2

        // Draw axes
        drawAxes(context: context, size: size, graphWidth: graphWidth, graphHeight: graphHeight)

        // Draw pitch points and lines
        drawPitchData(context: context, graphWidth: graphWidth, graphHeight: graphHeight)

        // Draw playback position indicator
        if let position = playbackPosition, duration > 0 {
            drawPlaybackIndicator(context: context, graphWidth: graphWidth, graphHeight: graphHeight, position: position)
        }
    }

    private func drawAxes(context: GraphicsContext, size: CGSize, graphWidth: CGFloat, graphHeight: CGFloat) {
        let axisColor = Color.gray.opacity(0.3)

        // Y-axis
        var yAxisPath = Path()
        yAxisPath.move(to: CGPoint(x: padding, y: padding))
        yAxisPath.addLine(to: CGPoint(x: padding, y: padding + graphHeight))
        context.stroke(yAxisPath, with: .color(axisColor), lineWidth: 1)

        // X-axis
        var xAxisPath = Path()
        xAxisPath.move(to: CGPoint(x: padding, y: padding + graphHeight))
        xAxisPath.addLine(to: CGPoint(x: padding + graphWidth, y: padding + graphHeight))
        context.stroke(xAxisPath, with: .color(axisColor), lineWidth: 1)

        // Y-axis labels (frequency)
        let freqSteps = [200.0, 400.0, 600.0, 800.0]
        for freq in freqSteps {
            let y = padding + graphHeight - (CGFloat(freq - minFrequency) / CGFloat(maxFrequency - minFrequency)) * graphHeight

            // Grid line
            var gridPath = Path()
            gridPath.move(to: CGPoint(x: padding, y: y))
            gridPath.addLine(to: CGPoint(x: padding + graphWidth, y: y))
            context.stroke(gridPath, with: .color(axisColor.opacity(0.3)), lineWidth: 0.5)

            // Label
            let text = Text("\(Int(freq)) Hz")
                .font(.caption2)
                .foregroundColor(.gray)
            context.draw(text, at: CGPoint(x: padding - 5, y: y), anchor: .trailing)
        }

        // X-axis labels (time)
        let timeSteps = stride(from: 0.0, through: duration, by: max(duration / 5, 0.5))
        for time in timeSteps {
            let x = padding + (CGFloat(time) / CGFloat(duration)) * graphWidth

            let text = Text(String(format: "%.1fs", time))
                .font(.caption2)
                .foregroundColor(.gray)
            context.draw(text, at: CGPoint(x: x, y: padding + graphHeight + 15), anchor: .top)
        }
    }

    private func drawPitchData(context: GraphicsContext, graphWidth: CGFloat, graphHeight: CGFloat) {
        guard !pitchData.isEmpty else { return }

        var path = Path()
        var isFirstPoint = true

        for data in pitchData {
            let x = padding + (CGFloat(data.timestamp) / CGFloat(duration)) * graphWidth
            let normalizedFreq = (data.frequency - minFrequency) / (maxFrequency - minFrequency)
            let y = padding + graphHeight - CGFloat(normalizedFreq) * graphHeight

            // Clamp to graph bounds
            let clampedY = max(padding, min(padding + graphHeight, y))

            if isFirstPoint {
                path.move(to: CGPoint(x: x, y: clampedY))
                isFirstPoint = false
            } else {
                path.addLine(to: CGPoint(x: x, y: clampedY))
            }

            // Draw point
            let pointSize: CGFloat = 3
            let pointRect = CGRect(
                x: x - pointSize / 2,
                y: clampedY - pointSize / 2,
                width: pointSize,
                height: pointSize
            )
            context.fill(Path(ellipseIn: pointRect), with: .color(.blue))
        }

        // Draw connecting line
        context.stroke(path, with: .color(.blue.opacity(0.5)), lineWidth: 1.5)
    }

    private func drawPlaybackIndicator(context: GraphicsContext, graphWidth: CGFloat, graphHeight: CGFloat, position: TimeInterval) {
        let x = padding + (CGFloat(position) / CGFloat(duration)) * graphWidth

        // Draw vertical line
        var linePath = Path()
        linePath.move(to: CGPoint(x: x, y: padding))
        linePath.addLine(to: CGPoint(x: x, y: padding + graphHeight))
        context.stroke(linePath, with: .color(.red), lineWidth: 2)

        // Draw triangle marker at top
        var trianglePath = Path()
        trianglePath.move(to: CGPoint(x: x, y: padding - 5))
        trianglePath.addLine(to: CGPoint(x: x - 5, y: padding - 15))
        trianglePath.addLine(to: CGPoint(x: x + 5, y: padding - 15))
        trianglePath.closeSubpath()
        context.fill(trianglePath, with: .color(.red))

        // Draw time label
        let timeText = Text(String(format: "%.1fs", position))
            .font(.caption2)
            .foregroundColor(.red)
            .fontWeight(.bold)
        context.draw(timeText, at: CGPoint(x: x, y: padding - 20), anchor: .bottom)
    }
}

// MARK: - Preview

#Preview {
    let sampleData = [
        PitchData(timestamp: 0.0, frequency: 440.0, confidence: 0.9),
        PitchData(timestamp: 0.5, frequency: 493.88, confidence: 0.85),
        PitchData(timestamp: 1.0, frequency: 523.25, confidence: 0.8),
        PitchData(timestamp: 1.5, frequency: 587.33, confidence: 0.75),
        PitchData(timestamp: 2.0, frequency: 659.25, confidence: 0.9),
    ]

    return PitchGraphView(pitchData: sampleData, duration: 2.5, playbackPosition: 1.0)
        .padding()
}
