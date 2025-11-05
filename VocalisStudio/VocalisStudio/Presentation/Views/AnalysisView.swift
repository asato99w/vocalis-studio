import SwiftUI
import VocalisDomain

/// Analysis screen - displays spectrogram and pitch analysis for a recording
public struct AnalysisView: View {
    let recording: Recording
    @StateObject private var viewModel: AnalysisViewModel
    @StateObject private var localization = LocalizationManager.shared
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    public init(
        recording: Recording,
        audioPlayer: AudioPlayerProtocol,
        analyzeRecordingUseCase: AnalyzeRecordingUseCase
    ) {
        self.recording = recording
        _viewModel = StateObject(wrappedValue: AnalysisViewModel(
            recording: recording,
            audioPlayer: audioPlayer,
            analyzeRecordingUseCase: analyzeRecordingUseCase
        ))
    }

    public var body: some View {
        ZStack {
            GeometryReader { geometry in
                if geometry.size.width > geometry.size.height {
                    // Landscape layout
                    landscapeLayout
                } else {
                    // Portrait layout
                    portraitLayout
                }
            }

            // Loading overlay
            if case .loading(let progress) = viewModel.state {
                ColorPalette.background.opacity(0.4)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Text("analysis.analyzing".localized)
                        .font(.headline)
                        .foregroundColor(ColorPalette.text)

                    VStack(spacing: 8) {
                        ProgressView(value: progress, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: ColorPalette.primary))
                            .frame(width: 200)

                        Text("\(Int(progress * 100))%")
                            .font(.subheadline)
                            .foregroundColor(ColorPalette.text)
                            .monospacedDigit()
                    }
                }
                .padding(32)
                .background(ColorPalette.secondary)
                .cornerRadius(16)
            }

            // Error overlay
            if case .error(let message) = viewModel.state {
                ColorPalette.background.opacity(0.4)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(ColorPalette.alertActive)

                    Text("analysis.error".localized)
                        .font(.headline)
                        .foregroundColor(ColorPalette.text)

                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(ColorPalette.text.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                .background(ColorPalette.background)
                .cornerRadius(16)
                .shadow(radius: 10)
            }
        }
        .navigationTitle("analysis.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.startAnalysis()
        }
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
                SpectrogramView(
                    currentTime: viewModel.currentTime,
                    spectrogramData: viewModel.analysisResult?.spectrogramData
                )
                .frame(maxHeight: .infinity)

                Divider()

                // Pitch analysis graph (bottom half)
                PitchAnalysisView(
                    currentTime: viewModel.currentTime,
                    pitchData: viewModel.analysisResult?.pitchData,
                    scaleSettings: viewModel.analysisResult?.scaleSettings
                )
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

                SpectrogramView(
                    currentTime: viewModel.currentTime,
                    spectrogramData: viewModel.analysisResult?.spectrogramData
                )
                .frame(height: 200)

                PitchAnalysisView(
                    currentTime: viewModel.currentTime,
                    pitchData: viewModel.analysisResult?.pitchData,
                    scaleSettings: viewModel.analysisResult?.scaleSettings
                )
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
                .foregroundColor(ColorPalette.text)

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
        .background(ColorPalette.secondary)
        .cornerRadius(8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("RecordingInfoPanel")
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
                .foregroundColor(ColorPalette.text)
            HStack {
                Text(formatDate(recording.createdAt))
                Text("|")
                Text(recording.duration.formatted)
                Text("|")
                Text("recording.scale_five_tone".localized + " C3 120" + "recording.tempo_unit".localized)
            }
            .font(.subheadline)
            .foregroundColor(ColorPalette.text.opacity(0.6))
            Text("analysis.info_ascending_count".localized + ": 3 " + "recording.ascending_count_unit".localized)
                .font(.subheadline)
                .foregroundColor(ColorPalette.text.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(ColorPalette.secondary)
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
                .foregroundColor(ColorPalette.text.opacity(0.6))
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(ColorPalette.text)
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
                .foregroundColor(ColorPalette.text)

            // Playback buttons
            HStack(spacing: 20) {
                Button(action: { onSeek(max(0, currentTime - 5)) }) {
                    Image(systemName: "backward.fill")
                        .font(.callout)
                        .foregroundColor(ColorPalette.primary)
                }
                .accessibilityIdentifier("AnalysisSeekBackButton")

                Button(action: onPlayPause) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(ColorPalette.primary)
                }
                .accessibilityIdentifier("AnalysisPlayPauseButton")

                Button(action: { onSeek(min(duration, currentTime + 5)) }) {
                    Image(systemName: "forward.fill")
                        .font(.callout)
                        .foregroundColor(ColorPalette.primary)
                }
                .accessibilityIdentifier("AnalysisSeekForwardButton")
            }

            // Progress bar
            VStack(spacing: 3) {
                Slider(value: Binding(
                    get: { currentTime },
                    set: { onSeek($0) }
                ), in: 0...duration)
                .tint(ColorPalette.primary)
                .accessibilityIdentifier("AnalysisProgressSlider")

                HStack {
                    Text(formatTime(currentTime))
                    Spacer()
                    Text(formatTime(duration))
                }
                .font(.caption2)
                .foregroundColor(ColorPalette.text.opacity(0.6))
            }
        }
        .padding(10)
        .background(ColorPalette.secondary)
        .cornerRadius(8)
    }

    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - Spectrogram View

struct SpectrogramView: View {
    let currentTime: Double
    let spectrogramData: SpectrogramData?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("analysis.spectrogram_title".localized)
                .font(.subheadline)
                .fontWeight(.semibold)

            ZStack(alignment: .topLeading) {
                GeometryReader { geometry in
                    Canvas { context, size in
                        if let data = spectrogramData, !data.timeStamps.isEmpty {
                            drawSpectrogram(context: context, size: size, data: data)
                        } else {
                            drawPlaceholder(context: context, size: size)
                        }

                        // Draw playback position line
                        drawPlaybackPosition(context: context, size: size)

                        // Draw time axis
                        drawSpectrogramTimeAxis(context: context, size: size)
                    }
                }

                // Frequency labels (overlay on top)
                VStack(spacing: 0) {
                    HStack {
                        Text("2000Hz")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(4)
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Text("1100Hz")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(4)
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Text("200Hz")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(4)
                        Spacer()
                    }
                }
                .padding(8)
                .allowsHitTesting(false)
            }
            .background(Color.black.opacity(0.1))
            .cornerRadius(8)
        }
    }

    private func drawSpectrogram(context: GraphicsContext, size: CGSize, data: SpectrogramData) {
        let timeWindow = 6.0  // Display 6 seconds total (3 sec before, 3 sec after)
        let centerX = size.width / 2  // Playback position at center

        // Find max magnitude for normalization
        let maxMagnitude = data.magnitudes.flatMap { $0 }.max() ?? 1.0

        let freqBinCount = data.frequencyBins.count
        let cellHeight = size.height / CGFloat(freqBinCount)

        // Draw cells for visible time range
        for (timeIndex, timestamp) in data.timeStamps.enumerated() {
            let timeOffset = timestamp - currentTime  // Offset from current time

            // Only draw if within visible time window (-3 to +3 seconds from current)
            guard abs(timeOffset) <= timeWindow / 2 else { continue }

            // Calculate x position: center + offset scaled to pixels
            let pixelsPerSecond = size.width / timeWindow
            let x = centerX + CGFloat(timeOffset) * pixelsPerSecond

            let cellWidth = pixelsPerSecond * 0.1  // 0.1 sec per cell

            guard timeIndex < data.magnitudes.count else { continue }
            let magnitudeFrame = data.magnitudes[timeIndex]

            for (freqIndex, magnitude) in magnitudeFrame.enumerated() {
                let normalizedMagnitude = CGFloat(magnitude / maxMagnitude)
                let hue = 0.6 - normalizedMagnitude * 0.6 // Blue (low) to red (high)
                let color = Color(hue: hue, saturation: 0.8, brightness: 0.9 * normalizedMagnitude + 0.1)

                let rect = CGRect(
                    x: x,
                    y: size.height - CGFloat(freqIndex + 1) * cellHeight,
                    width: cellWidth,
                    height: cellHeight
                )
                context.fill(Path(rect), with: .color(color))
            }
        }
    }

    private func drawPlaceholder(context: GraphicsContext, size: CGSize) {
        let text = Text("分析データなし").font(.caption).foregroundColor(.secondary)
        context.draw(text, at: CGPoint(x: size.width / 2, y: size.height / 2))
    }

    private func drawPlaybackPosition(context: GraphicsContext, size: CGSize) {
        // Draw playback position line at center
        let centerX = size.width / 2

        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: centerX, y: 0))
                path.addLine(to: CGPoint(x: centerX, y: size.height))
            },
            with: .color(.white),
            lineWidth: 2
        )
    }

    private func drawSpectrogramTimeAxis(context: GraphicsContext, size: CGSize) {
        // Draw time labels at left (-3s), center (current), right (+3s)
        let timeOffsets: [Double] = [-3, 0, 3]
        let positions: [CGFloat] = [0.1, 0.5, 0.9]

        for (offset, position) in zip(timeOffsets, positions) {
            let time = currentTime + offset
            guard time >= 0 else { continue }

            let x = size.width * position
            let y = size.height - 5
            let text = Text(String(format: "%.1fs", time)).font(.caption2).foregroundColor(.white)
            context.draw(text, at: CGPoint(x: x, y: y))
        }
    }
}

// MARK: - Pitch Analysis View

struct PitchAnalysisView: View {
    let currentTime: Double
    let pitchData: PitchAnalysisData?
    let scaleSettings: ScaleSettings?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("analysis.pitch_graph_title".localized)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(ColorPalette.text)

            GeometryReader { geometry in
                Canvas { context, size in
                    if let data = pitchData, !data.timeStamps.isEmpty {
                        drawPitchGraph(context: context, size: size, data: data)
                    } else {
                        drawPlaceholder(context: context, size: size)
                    }
                    drawLegend(context: context, size: size)
                }
            }
            .background(ColorPalette.secondary)
            .cornerRadius(8)
        }
    }

    private func drawPitchGraph(context: GraphicsContext, size: CGSize, data: PitchAnalysisData) {
        let frequencies = data.frequencies
        guard !frequencies.isEmpty else { return }

        // Calculate frequency range
        let minFreq = frequencies.min() ?? 200.0
        let maxFreq = frequencies.max() ?? 800.0
        let freqRange = maxFreq - minFreq
        guard freqRange > 0 else { return }

        let timeWindow = 6.0  // Display 6 seconds total (3 sec before, 3 sec after)
        let leftMargin: CGFloat = 40
        let rightMargin: CGFloat = 10
        let topMargin: CGFloat = 50
        let bottomMargin: CGFloat = 30

        let graphWidth = size.width - leftMargin - rightMargin
        let graphHeight = size.height - topMargin - bottomMargin
        let centerX = leftMargin + graphWidth / 2  // Playback position at center

        // Draw target scale lines if available
        if let settings = scaleSettings {
            drawTargetScaleLines(context: context, leftMargin: leftMargin, topMargin: topMargin,
                               graphWidth: graphWidth, graphHeight: graphHeight,
                               minFreq: minFreq, freqRange: freqRange, settings: settings)
        }

        // Draw detected pitch line (only visible range)
        var path = Path()
        var pathStarted = false
        let pixelsPerSecond = graphWidth / timeWindow

        for (index, timestamp) in data.timeStamps.enumerated() {
            let timeOffset = timestamp - currentTime  // Offset from current time

            // Only draw if within visible time window (-3 to +3 seconds from current)
            guard abs(timeOffset) <= timeWindow / 2 else { continue }

            let frequency = frequencies[index]
            let x = centerX + CGFloat(timeOffset) * pixelsPerSecond
            let y = topMargin + graphHeight - CGFloat((frequency - minFreq) / freqRange) * graphHeight

            if !pathStarted {
                path.move(to: CGPoint(x: x, y: y))
                pathStarted = true
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }

            // Draw confidence indicator (dot size based on confidence)
            let confidence = data.confidences[index]
            let dotSize = CGFloat(confidence * 6.0 + 2.0)
            context.fill(
                Path(ellipseIn: CGRect(x: x - dotSize/2, y: y - dotSize/2, width: dotSize, height: dotSize)),
                with: .color(.blue.opacity(Double(confidence)))
            )
        }

        if pathStarted {
            context.stroke(path, with: .color(.blue), lineWidth: 1.5)
        }

        // Draw playback position line at center
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: centerX, y: topMargin))
                path.addLine(to: CGPoint(x: centerX, y: topMargin + graphHeight))
            },
            with: .color(.white),
            lineWidth: 2
        )

        // Draw frequency axis labels
        drawFrequencyAxis(context: context, leftMargin: leftMargin, topMargin: topMargin,
                         graphHeight: graphHeight, minFreq: minFreq, maxFreq: maxFreq)

        // Draw time axis labels
        drawTimeAxis(context: context, leftMargin: leftMargin, topMargin: topMargin,
                    graphWidth: graphWidth, graphHeight: graphHeight, bottomMargin: bottomMargin,
                    centerTime: currentTime, timeWindow: timeWindow)
    }

    private func drawTargetScaleLines(context: GraphicsContext, leftMargin: CGFloat, topMargin: CGFloat,
                                     graphWidth: CGFloat, graphHeight: CGFloat,
                                     minFreq: Float, freqRange: Float, settings: ScaleSettings) {
        // Draw horizontal reference lines for target notes
        // Generate notes from start to end using intervals
        var notes: [MIDINote] = []
        let startValue = settings.startNote.value
        let endValue = settings.endNote.value

        // Generate all notes in the range using the pattern intervals
        var currentOctaveStart = Int(startValue)
        while currentOctaveStart <= Int(endValue) {
            for interval in settings.notePattern.intervals {
                let noteValue = UInt8(currentOctaveStart + interval)
                if noteValue >= startValue && noteValue <= endValue {
                    if let note = try? MIDINote(noteValue) {
                        notes.append(note)
                    }
                }
            }
            currentOctaveStart += 12  // Next octave
        }

        for note in notes {
            let frequency = Float(note.frequency)
            let y = topMargin + graphHeight - CGFloat((frequency - minFreq) / freqRange) * graphHeight

            var path = Path()
            path.move(to: CGPoint(x: leftMargin, y: y))
            path.addLine(to: CGPoint(x: leftMargin + graphWidth, y: y))

            context.stroke(path, with: .color(.gray.opacity(0.3)), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        }
    }

    private func drawFrequencyAxis(context: GraphicsContext, leftMargin: CGFloat, topMargin: CGFloat,
                                   graphHeight: CGFloat, minFreq: Float, maxFreq: Float) {
        let labels = [maxFreq, (maxFreq + minFreq) / 2, minFreq]
        let positions: [CGFloat] = [0, 0.5, 1.0]

        for (label, position) in zip(labels, positions) {
            let y = topMargin + graphHeight * position
            let text = Text(String(format: "%.0fHz", label)).font(.caption2).foregroundColor(.secondary)
            context.draw(text, at: CGPoint(x: leftMargin - 25, y: y))
        }
    }

    private func drawTimeAxis(context: GraphicsContext, leftMargin: CGFloat, topMargin: CGFloat,
                             graphWidth: CGFloat, graphHeight: CGFloat, bottomMargin: CGFloat,
                             centerTime: Double, timeWindow: Double) {
        // Draw time labels at -3s, 0s (center), +3s
        let timeOffsets: [Double] = [-3, 0, 3]
        let positions: [CGFloat] = [0, 0.5, 1.0]

        for (offset, position) in zip(timeOffsets, positions) {
            let time = centerTime + offset
            guard time >= 0 else { continue }  // Don't show negative times

            let x = leftMargin + graphWidth * position
            let y = topMargin + graphHeight + 15
            let text = Text(String(format: "%.1fs", time)).font(.caption2).foregroundColor(.secondary)
            context.draw(text, at: CGPoint(x: x, y: y))
        }
    }

    private func drawPlaceholder(context: GraphicsContext, size: CGSize) {
        let text = Text("ピッチデータなし").font(.caption).foregroundColor(.secondary)
        context.draw(text, at: CGPoint(x: size.width / 2, y: size.height / 2))
    }

    private func drawLegend(context: GraphicsContext, size: CGSize) {
        let legendY: CGFloat = 20

        // Target scale legend
        var path1 = Path()
        path1.move(to: CGPoint(x: 10, y: legendY))
        path1.addLine(to: CGPoint(x: 40, y: legendY))
        context.stroke(path1, with: .color(.gray.opacity(0.3)), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        context.draw(Text("目標音階").font(.caption2), at: CGPoint(x: 70, y: legendY))

        // Detected pitch legend
        var path2 = Path()
        path2.move(to: CGPoint(x: 120, y: legendY))
        path2.addLine(to: CGPoint(x: 150, y: legendY))
        context.stroke(path2, with: .color(.blue), lineWidth: 1.5)
        context.draw(Text("検出ピッチ").font(.caption2), at: CGPoint(x: 185, y: legendY))
    }
}


// MARK: - Preview

#if DEBUG
private class PreviewAudioPlayer: AudioPlayerProtocol {
    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0.0
    var duration: TimeInterval = 10.0

    func play(url: URL) async throws {
        isPlaying = true
    }

    func stop() async {
        isPlaying = false
    }

    func pause() {
        isPlaying = false
    }

    func resume() {
        isPlaying = true
    }

    func seek(to time: TimeInterval) {
        currentTime = time
    }
}

private class PreviewAudioFileAnalyzer: AudioFileAnalyzerProtocol {
    func analyze(fileURL: URL, progress: @escaping @MainActor (Double) async -> Void) async throws -> (pitchData: PitchAnalysisData, spectrogramData: SpectrogramData) {
        // Simulate progress updates
        await progress(0.0)
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5s
        await progress(0.5)
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5s
        await progress(1.0)

        let pitchData = PitchAnalysisData(
            timeStamps: [0.0, 0.05, 0.10],
            frequencies: [261.6, 262.3, 261.9],
            confidences: [0.85, 0.92, 0.88],
            targetNotes: [nil, nil, nil]
        )

        let spectrogramData = SpectrogramData(
            timeStamps: [0.0, 0.1, 0.2],
            frequencyBins: [80, 180, 280],
            magnitudes: [[0.1, 0.3, 0.8], [0.2, 0.4, 0.7], [0.3, 0.5, 0.6]]
        )

        return (pitchData, spectrogramData)
    }
}

private class PreviewLogger: LoggerProtocol {
    func debug(_ message: String, category: String) {}
    func info(_ message: String, category: String) {}
    func warning(_ message: String, category: String) {}
    func error(_ message: String, category: String) {}
}

struct AnalysisView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AnalysisView(
                recording: Recording(
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
                ),
                audioPlayer: PreviewAudioPlayer(),
                analyzeRecordingUseCase: AnalyzeRecordingUseCase(
                    audioFileAnalyzer: PreviewAudioFileAnalyzer(),
                    analysisCache: AnalysisCache(),
                    logger: PreviewLogger()
                )
            )
        }
        .previewInterfaceOrientation(.landscapeLeft)
    }
}
#endif
