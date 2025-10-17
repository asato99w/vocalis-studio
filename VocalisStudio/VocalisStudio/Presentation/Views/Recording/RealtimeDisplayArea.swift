import SwiftUI
import VocalisDomain

/// Real-time audio visualization area (spectrum and pitch indicator)
struct RealtimeDisplayArea: View {
    let recordingState: RecordingState
    let isPlayingRecording: Bool
    let targetPitch: DetectedPitch?
    let detectedPitch: DetectedPitch?
    let pitchAccuracy: PitchAccuracy
    let spectrum: [Float]?

    var body: some View {
        VStack(spacing: 12) {
            // Frequency spectrum bar chart
            VStack(alignment: .leading, spacing: 6) {
                Text("recording.realtime_spectrum_title".localized)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                FrequencySpectrumView(
                    spectrum: spectrum,
                    isActive: recordingState == .recording || isPlayingRecording
                )
                .frame(maxHeight: .infinity)
            }

            Divider()

            // Pitch indicator
            VStack(alignment: .leading, spacing: 6) {
                Text("recording.pitch_indicator_title".localized)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                PitchIndicator(
                    isActive: recordingState == .recording,
                    isPlayingRecording: isPlayingRecording,
                    targetPitch: targetPitch,
                    detectedPitch: detectedPitch,
                    pitchAccuracy: pitchAccuracy
                )
            }
        }
        .padding(12)
    }
}

// MARK: - Frequency Spectrum View

/// Frequency spectrum bar chart view with real-time audio visualization
struct FrequencySpectrumView: View {
    let spectrum: [Float]?
    let isActive: Bool

    private let minFreq: Double = 100.0  // Hz
    private let maxFreq: Double = 800.0  // Hz

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                guard let spectrum = spectrum, !spectrum.isEmpty else {
                    // Draw placeholder when no spectrum data
                    drawPlaceholder(context: context, size: size)
                    return
                }

                let barCount = spectrum.count
                let barWidth = size.width / CGFloat(barCount)
                let maxMagnitude = spectrum.max() ?? 1.0

                for (index, magnitude) in spectrum.enumerated() {
                    let normalizedHeight = maxMagnitude > 0 ? CGFloat(magnitude / maxMagnitude) : 0
                    let barHeight = normalizedHeight * size.height

                    let rect = CGRect(
                        x: CGFloat(index) * barWidth,
                        y: size.height - barHeight,
                        width: max(barWidth - 1, 1),
                        height: barHeight
                    )

                    // Color gradient based on magnitude: blue -> green -> red
                    let color = magnitudeColor(normalizedMagnitude: normalizedHeight)
                    context.fill(Path(rect), with: .color(color))
                }

                // Draw frequency labels
                drawFrequencyLabels(context: context, size: size)
            }
        }
        .background(Color.black)
        .cornerRadius(8)
    }

    private func drawPlaceholder(context: GraphicsContext, size: CGSize) {
        // Draw subtle grid for inactive state
        let gridColor = Color.gray.opacity(0.2)
        for i in 0..<10 {
            let y = CGFloat(i) * size.height / 10
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
        }
    }

    private func drawFrequencyLabels(context: GraphicsContext, size: CGSize) {
        let labelColor = Color.white.opacity(0.6)
        let frequencies = [100, 200, 300, 400, 500, 600, 700, 800]

        for freq in frequencies {
            let ratio = (Double(freq) - minFreq) / (maxFreq - minFreq)
            let x = CGFloat(ratio) * size.width

            // Draw tick mark
            var path = Path()
            path.move(to: CGPoint(x: x, y: size.height - 5))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(path, with: .color(labelColor), lineWidth: 1)
        }
    }

    private func magnitudeColor(normalizedMagnitude: CGFloat) -> Color {
        if normalizedMagnitude < 0.33 {
            // Low: Blue
            let ratio = normalizedMagnitude / 0.33
            return Color(
                red: 0,
                green: ratio * 0.5,
                blue: 1.0
            )
        } else if normalizedMagnitude < 0.66 {
            // Medium: Blue -> Green
            let ratio = (normalizedMagnitude - 0.33) / 0.33
            return Color(
                red: 0,
                green: 0.5 + ratio * 0.5,
                blue: 1.0 - ratio
            )
        } else {
            // High: Green -> Red
            let ratio = (normalizedMagnitude - 0.66) / 0.34
            return Color(
                red: ratio,
                green: 1.0 - ratio * 0.5,
                blue: 0
            )
        }
    }
}

// MARK: - Pitch Indicator

/// Pitch indicator displaying target pitch and detected pitch with accuracy
struct PitchIndicator: View {
    let isActive: Bool
    let isPlayingRecording: Bool
    let targetPitch: DetectedPitch?
    let detectedPitch: DetectedPitch?
    let pitchAccuracy: PitchAccuracy

    var body: some View {
        VStack(spacing: 10) {
            // Target pitch row
            targetPitchRow

            // Detected pitch row
            detectedPitchRow
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    // MARK: - Target Pitch Row

    private var targetPitchRow: some View {
        HStack(spacing: 8) {
            Text("recording.pitch_target".localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)

            if let target = targetPitch {
                HStack(spacing: 6) {
                    Text(target.noteName)
                        .font(.callout)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)

                    Text(String(format: "%.1f Hz", target.frequency))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("--")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Detected Pitch Row

    private var detectedPitchRow: some View {
        HStack(spacing: 8) {
            Text("recording.pitch_detected".localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)

            if (isActive || isPlayingRecording), let detected = detectedPitch {
                HStack(spacing: 6) {
                    // Accuracy indicator
                    Circle()
                        .fill(accuracyColor)
                        .frame(width: 12, height: 12)

                    Text(detected.noteName)
                        .font(.callout)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text(String(format: "%.1f Hz", detected.frequency))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Cents deviation
                    if let cents = detected.cents {
                        Text(cents >= 0 ? "+\(cents)¢" : "\(cents)¢")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(accuracyColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(accuracyColor.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
            } else {
                Text((isActive || isPlayingRecording) ? "..." : "--")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Accuracy Color

    private var accuracyColor: Color {
        switch pitchAccuracy {
        case .accurate: return .green
        case .slightlyOff: return .orange
        case .off: return .red
        case .none: return .gray
        }
    }
}
