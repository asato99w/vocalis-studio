//
//  SpectrumGraphView.swift
//  PoC
//
//  Spectrum visualization using SwiftUI Canvas
//

import SwiftUI

struct SpectrumGraphView: View {
    let spectrumData: SpectrumData?

    // Display configuration
    private let maxFrequency: Float = 2000.0  // Display up to 2kHz
    private let padding: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Frequency Spectrum")
                .font(.headline)

            if let spectrum = spectrumData {
                spectrumCanvas(spectrum: spectrum)
                legend(spectrum: spectrum)
            } else {
                emptyState
            }
        }
    }

    private var emptyState: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
            Text("No spectrum data")
                .foregroundColor(.gray)
        }
        .frame(height: 200)
    }

    private func spectrumCanvas(spectrum: SpectrumData) -> some View {
        Canvas { context, size in
            drawSpectrum(context: context, size: size, spectrum: spectrum)
        }
        .frame(height: 200)
        .background(Color.black)
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private func legend(spectrum: SpectrumData) -> some View {
        HStack(spacing: 20) {
            if let dominantFreq = spectrum.dominantFrequency {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Peak: \(Int(dominantFreq)) Hz")
                        .font(.caption)
                }
            }

            Spacer()

            Text(String(format: "%.2fs", spectrum.timestamp))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Spectrum Drawing

    private func drawSpectrum(context: GraphicsContext, size: CGSize, spectrum: SpectrumData) {
        let graphWidth = size.width - padding * 2
        let graphHeight = size.height - padding * 2

        // Draw axes
        drawAxes(context: context, size: size, graphWidth: graphWidth, graphHeight: graphHeight)

        // Draw spectrum bars
        drawSpectrumBars(
            context: context,
            graphWidth: graphWidth,
            graphHeight: graphHeight,
            spectrum: spectrum
        )
    }

    private func drawAxes(context: GraphicsContext, size: CGSize, graphWidth: CGFloat, graphHeight: CGFloat) {
        let axisColor = Color.white.opacity(0.3)

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

        // Frequency labels
        let freqSteps = [0.0, 500.0, 1000.0, 1500.0, 2000.0]
        for freq in freqSteps {
            let x = padding + CGFloat(freq / Double(maxFrequency)) * graphWidth

            let text = Text("\(Int(freq))Hz")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
            context.draw(text, at: CGPoint(x: x, y: padding + graphHeight + 15), anchor: .top)
        }

        // Magnitude labels
        let magLabels = ["0%", "50%", "100%"]
        for (index, label) in magLabels.enumerated() {
            let y = padding + graphHeight - (CGFloat(index) / 2.0) * graphHeight

            let text = Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
            context.draw(text, at: CGPoint(x: padding - 5, y: y), anchor: .trailing)
        }
    }

    private func drawSpectrumBars(context: GraphicsContext, graphWidth: CGFloat, graphHeight: CGFloat, spectrum: SpectrumData) {
        // Filter frequencies up to maxFrequency
        let filteredIndices = spectrum.frequencies.enumerated().filter { $0.element <= maxFrequency }

        guard !filteredIndices.isEmpty else { return }

        let barWidth = graphWidth / CGFloat(filteredIndices.count)

        for (index, (freqIndex, frequency)) in filteredIndices.enumerated() {
            let magnitude = spectrum.magnitudes[freqIndex]

            let x = padding + CGFloat(index) * barWidth
            let barHeight = CGFloat(magnitude) * graphHeight
            let y = padding + graphHeight - barHeight

            // Color gradient based on frequency (low freq = red, high freq = blue)
            let hue = Double(frequency) / Double(maxFrequency) * 0.7  // 0.0 (red) to 0.7 (blue)
            let color = Color(hue: hue, saturation: 0.8, brightness: 0.9)

            // Draw bar
            let barRect = CGRect(
                x: x,
                y: y,
                width: max(barWidth - 1, 1),
                height: barHeight
            )
            context.fill(Path(roundedRect: barRect, cornerRadius: 1), with: .color(color))

            // Highlight peak frequency
            if let dominantFreq = spectrum.dominantFrequency,
               abs(frequency - dominantFreq) < 10 {
                context.stroke(
                    Path(roundedRect: barRect.insetBy(dx: -1, dy: -1), cornerRadius: 2),
                    with: .color(.green),
                    lineWidth: 2
                )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    // Create sample spectrum data
    let frequencies = (0..<1024).map { Float($0) * 2000.0 / 1024.0 }
    let magnitudes = (0..<1024).map { index -> Float in
        let freq = Float(index) * 2000.0 / 1024.0
        // Simulate some peaks
        if abs(freq - 440) < 50 { return 0.8 }  // A4 peak
        if abs(freq - 880) < 50 { return 0.5 }  // A5 peak
        return Float.random(in: 0.05...0.2)
    }

    let sampleSpectrum = SpectrumData(
        timestamp: 1.5,
        frequencies: frequencies,
        magnitudes: magnitudes,
        sampleRate: 44100.0
    )

    return SpectrumGraphView(spectrumData: sampleSpectrum)
        .padding()
        .background(Color.gray.opacity(0.1))
}
