import SwiftUI
import VocalisDomain

/// Analysis screen - displays spectrogram and pitch analysis for a recording
public struct AnalysisView: View {
    let recording: Recording
    @StateObject private var viewModel: MockAnalysisViewModel
    @StateObject private var localization = LocalizationManager.shared
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    public init(recording: Recording) {
        self.recording = recording
        _viewModel = StateObject(wrappedValue: MockAnalysisViewModel())
    }

    public var body: some View {
        GeometryReader { geometry in
            if geometry.size.width > geometry.size.height {
                // Landscape layout
                landscapeLayout
            } else {
                // Portrait layout
                portraitLayout
            }
        }
        .navigationTitle("analysis.title".localized)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Landscape Layout

    private var landscapeLayout: some View {
        HStack(spacing: 0) {
            // Left side: Recording info and playback controls
            VStack(spacing: 12) {
                RecordingInfoPanel(recording: recording)

                PlaybackControl(
                    isPlaying: viewModel.isPlaying,
                    currentTime: viewModel.currentTime,
                    duration: recording.duration.seconds,
                    onPlayPause: { viewModel.togglePlayback() },
                    onSeek: { time in viewModel.seek(to: time) }
                )

                Spacer()
            }
            .frame(width: 240)
            .padding(12)

            Divider()

            // Right side: Visualization area
            VStack(spacing: 12) {
                // Spectrogram (top half)
                SpectrogramView(currentTime: viewModel.currentTime)
                    .frame(maxHeight: .infinity)

                Divider()

                // Pitch analysis graph (bottom half)
                PitchAnalysisView(currentTime: viewModel.currentTime)
                    .frame(maxHeight: .infinity)
            }
            .padding(12)
        }
    }

    // MARK: - Portrait Layout

    private var portraitLayout: some View {
        ScrollView {
            VStack(spacing: 16) {
                RecordingInfoCompact(recording: recording)

                PlaybackControl(
                    isPlaying: viewModel.isPlaying,
                    currentTime: viewModel.currentTime,
                    duration: recording.duration.seconds,
                    onPlayPause: { viewModel.togglePlayback() },
                    onSeek: { time in viewModel.seek(to: time) }
                )

                SpectrogramView(currentTime: viewModel.currentTime)
                    .frame(height: 200)

                PitchAnalysisView(currentTime: viewModel.currentTime)
                    .frame(height: 200)
            }
            .padding()
        }
    }
}

// MARK: - Recording Info Panel

struct RecordingInfoPanel: View {
    let recording: Recording

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("analysis.info_title".localized)
                .font(.subheadline)
                .fontWeight(.semibold)

            Group {
                InfoRow(label: "analysis.info_datetime".localized, value: formatDate(recording.createdAt))
                InfoRow(label: "analysis.info_duration".localized, value: recording.duration.formatted)
                InfoRow(label: "analysis.info_scale".localized, value: "recording.scale_five_tone".localized)
                InfoRow(label: "analysis.info_pitch".localized, value: "C3")
                InfoRow(label: "analysis.info_tempo".localized, value: "120 " + "recording.tempo_unit".localized)
                InfoRow(label: "analysis.info_ascending_count".localized, value: "3 " + "recording.ascending_count_unit".localized)
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

struct RecordingInfoCompact: View {
    let recording: Recording

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("analysis.info_title".localized)
                .font(.headline)
            HStack {
                Text(formatDate(recording.createdAt))
                Text("|")
                Text(recording.duration.formatted)
                Text("|")
                Text("recording.scale_five_tone".localized + " C3 120" + "recording.tempo_unit".localized)
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            Text("analysis.info_ascending_count".localized + ": 3 " + "recording.ascending_count_unit".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.caption)
    }
}

// MARK: - Playback Control

struct PlaybackControl: View {
    let isPlaying: Bool
    let currentTime: Double
    let duration: Double
    let onPlayPause: () -> Void
    let onSeek: (Double) -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("analysis.playback_title".localized)
                .font(.subheadline)
                .fontWeight(.semibold)

            // Playback buttons
            HStack(spacing: 20) {
                Button(action: { onSeek(max(0, currentTime - 5)) }) {
                    Image(systemName: "backward.fill")
                        .font(.callout)
                }

                Button(action: onPlayPause) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 40))
                }

                Button(action: { onSeek(min(duration, currentTime + 5)) }) {
                    Image(systemName: "forward.fill")
                        .font(.callout)
                }
            }

            // Progress bar
            VStack(spacing: 3) {
                Slider(value: Binding(
                    get: { currentTime },
                    set: { onSeek($0) }
                ), in: 0...duration)

                HStack {
                    Text(formatTime(currentTime))
                    Spacer()
                    Text(formatTime(duration))
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - Spectrogram View (Mock)

struct SpectrogramView: View {
    let currentTime: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("analysis.spectrogram_title".localized)
                .font(.subheadline)
                .fontWeight(.semibold)

            ZStack {
                // Mock spectrogram visualization
                GeometryReader { geometry in
                    Canvas { context, size in
                        // Draw mock spectrogram with color gradient
                        let columns = 50
                        let rows = 20
                        let cellWidth = size.width / CGFloat(columns)
                        let cellHeight = size.height / CGFloat(rows)

                        for col in 0..<columns {
                            for row in 0..<rows {
                                let intensity = sin(Double(col) * 0.3 + Double(row) * 0.2) * 0.5 + 0.5
                                let hue = 0.6 - intensity * 0.6 // Blue to red
                                let color = Color(hue: hue, saturation: 0.8, brightness: 0.9)

                                let rect = CGRect(
                                    x: CGFloat(col) * cellWidth,
                                    y: size.height - CGFloat(row + 1) * cellHeight,
                                    width: cellWidth,
                                    height: cellHeight
                                )
                                context.fill(Path(rect), with: .color(color))
                            }
                        }

                        // Draw playback position line
                        let position = currentTime / 10.0 * size.width // Assuming 10 seconds duration
                        context.stroke(
                            Path { path in
                                path.move(to: CGPoint(x: position, y: 0))
                                path.addLine(to: CGPoint(x: position, y: size.height))
                            },
                            with: .color(.white),
                            lineWidth: 2
                        )
                    }
                }

                // Frequency labels
                VStack {
                    HStack {
                        Text("2000Hz")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Text("200Hz")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .padding(8)
            }
            .background(Color.black.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

// MARK: - Pitch Analysis View (Mock)

struct PitchAnalysisView: View {
    let currentTime: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("analysis.pitch_graph_title".localized)
                .font(.subheadline)
                .fontWeight(.semibold)

            GeometryReader { geometry in
                Canvas { context, size in
                    // Draw target scale line (horizontal reference lines)
                    let notes = [
                        "scale.note_do".localized,
                        "scale.note_re".localized,
                        "scale.note_mi".localized,
                        "scale.note_fa".localized,
                        "scale.note_so".localized
                    ]
                    let noteHeight = size.height * 0.6
                    let noteSpacing = size.width / CGFloat(notes.count + 1)

                    // Target pitch line
                    context.stroke(
                        Path { path in
                            for i in 0..<notes.count {
                                let x = CGFloat(i + 1) * noteSpacing
                                if i == 0 {
                                    path.move(to: CGPoint(x: x, y: noteHeight))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: noteHeight))
                                }
                            }
                        },
                        with: .color(.gray.opacity(0.5)),
                        style: StrokeStyle(lineWidth: 2, dash: [5, 5])
                    )

                    // Detected pitch line with variation
                    context.stroke(
                        Path { path in
                            for i in 0..<notes.count {
                                let x = CGFloat(i + 1) * noteSpacing
                                let variation = sin(Double(i) * 1.2) * 20 // Mock variation
                                let y = noteHeight + variation

                                if i == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }

                                // Draw dot
                                context.fill(
                                    Path(ellipseIn: CGRect(x: x - 4, y: y - 4, width: 8, height: 8)),
                                    with: .color(.blue)
                                )
                            }
                        },
                        with: .color(.blue),
                        lineWidth: 2
                    )

                    // Note labels
                    for (i, note) in notes.enumerated() {
                        let x = CGFloat(i + 1) * noteSpacing
                        let text = Text(note).font(.caption)
                        context.draw(text, at: CGPoint(x: x, y: size.height - 10))
                    }

                    // Legend
                    let legendY: CGFloat = 20
                    context.stroke(
                        Path { path in
                            path.move(to: CGPoint(x: 10, y: legendY))
                            path.addLine(to: CGPoint(x: 40, y: legendY))
                        },
                        with: .color(.gray.opacity(0.5)),
                        style: StrokeStyle(lineWidth: 2, dash: [5, 5])
                    )
                    context.draw(Text("analysis.target_scale".localized).font(.caption), at: CGPoint(x: 80, y: legendY))

                    context.stroke(
                        Path { path in
                            path.move(to: CGPoint(x: 10, y: legendY + 20))
                            path.addLine(to: CGPoint(x: 40, y: legendY + 20))
                        },
                        with: .color(.blue),
                        lineWidth: 2
                    )
                    context.draw(Text("analysis.detected_pitch".localized).font(.caption), at: CGPoint(x: 80, y: legendY + 20))
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

// MARK: - Mock ViewModel

class MockAnalysisViewModel: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: Double = 0.0

    private var timer: Timer?

    func togglePlayback() {
        isPlaying.toggle()

        if isPlaying {
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.currentTime += 0.1
                if self.currentTime >= 10.0 {
                    self.currentTime = 10.0
                    self.isPlaying = false
                    self.timer?.invalidate()
                }
            }
        } else {
            timer?.invalidate()
        }
    }

    func seek(to time: Double) {
        currentTime = time
    }
}

// MARK: - Preview

#if DEBUG
struct AnalysisView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AnalysisView(recording: Recording(
                id: RecordingId(),
                fileURL: URL(fileURLWithPath: "/tmp/test.m4a"),
                createdAt: Date(),
                duration: Duration(seconds: 10.0),
                scaleSettings: ScaleSettings(
                    startNote: try! MIDINote(60), // C3
                    endNote: try! MIDINote(72),   // C4
                    notePattern: .fiveToneScale,
                    tempo: try! Tempo(secondsPerNote: 0.5)
                )
            ))
        }
        .previewInterfaceOrientation(.landscapeLeft)
    }
}
#endif
