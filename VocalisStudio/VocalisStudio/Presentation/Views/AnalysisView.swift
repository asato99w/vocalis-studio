import SwiftUI
import VocalisDomain
import os.log

/// Analysis screen - displays spectrogram and pitch analysis for a recording
public struct AnalysisView: View {
    let recording: Recording
    @StateObject private var viewModel: AnalysisViewModel
    @StateObject private var localization = LocalizationManager.shared
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    // MARK: - Expanded Graph State
    @State private var expandedGraph: ExpandedGraphType? = nil

    enum ExpandedGraphType: Identifiable {
        case spectrogram
        case pitchAnalysis

        var id: Self { self }
    }

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
        .fullScreenCover(item: $expandedGraph) { graphType in
            expandedGraphFullScreen(for: graphType)
        }
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
                    spectrogramData: viewModel.analysisResult?.spectrogramData,
                    onExpand: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            expandedGraph = .spectrogram
                        }
                    },
                    onPlayPause: { viewModel.togglePlayback() },
                    onSeek: { time in viewModel.seek(to: time) }
                )
                .frame(maxHeight: .infinity)

                Divider()

                // Pitch analysis graph (bottom half)
                PitchAnalysisView(
                    currentTime: viewModel.currentTime,
                    pitchData: viewModel.analysisResult?.pitchData,
                    scaleSettings: viewModel.analysisResult?.scaleSettings,
                    onExpand: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            expandedGraph = .pitchAnalysis
                        }
                    },
                    onPlayPause: { viewModel.togglePlayback() }
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
                    spectrogramData: viewModel.analysisResult?.spectrogramData,
                    onExpand: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            expandedGraph = .spectrogram
                        }
                    },
                    onPlayPause: { viewModel.togglePlayback() },
                    onSeek: { time in viewModel.seek(to: time) }
                )
                .frame(height: 200)

                PitchAnalysisView(
                    currentTime: viewModel.currentTime,
                    pitchData: viewModel.analysisResult?.pitchData,
                    scaleSettings: viewModel.analysisResult?.scaleSettings,
                    onExpand: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            expandedGraph = .pitchAnalysis
                        }
                    },
                    onPlayPause: { viewModel.togglePlayback() }
                )
                .frame(height: 200)
            }
            .padding()
        }
    }

    // MARK: - Expanded Graph Full Screen

    @ViewBuilder
    private func expandedGraphFullScreen(for type: ExpandedGraphType) -> some View {
        ZStack {
            // Background
            ColorPalette.background
                .ignoresSafeArea()

            // Graph content
            VStack(spacing: 0) {
                // Graph area (maximized)
                switch type {
                case .spectrogram:
                    SpectrogramView(
                        currentTime: viewModel.currentTime,
                        spectrogramData: viewModel.analysisResult?.spectrogramData,
                        isExpanded: true,
                        onCollapse: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                expandedGraph = nil
                            }
                        },
                        onPlayPause: { viewModel.togglePlayback() },
                        onSeek: { time in viewModel.seek(to: time) }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .pitchAnalysis:
                    PitchAnalysisView(
                        currentTime: viewModel.currentTime,
                        pitchData: viewModel.analysisResult?.pitchData,
                        scaleSettings: viewModel.analysisResult?.scaleSettings,
                        isExpanded: true,
                        onCollapse: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                expandedGraph = nil
                            }
                        },
                        onPlayPause: { viewModel.togglePlayback() }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}

// MARK: - Compact Playback Control

struct CompactPlaybackControl: View {
    let isPlaying: Bool
    let onPlayPause: () -> Void

    var body: some View {
        HStack {
            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(ColorPalette.primary)
            }
            .accessibilityIdentifier("ExpandedAnalysisPlayPauseButton")

            Text(isPlaying ? "analysis.playing".localized : "analysis.paused".localized)
                .font(.caption)
                .foregroundColor(ColorPalette.text.opacity(0.6))
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
    var isExpanded: Bool = false
    var onExpand: (() -> Void)? = nil
    var onCollapse: (() -> Void)? = nil
    var onPlayPause: (() -> Void)? = nil
    var onSeek: ((Double) -> Void)? = nil

    // MARK: - Dependencies
    private let coordinateSystem = SpectrogramCoordinateSystem()
    private var renderer: SpectrogramRenderer {
        SpectrogramRenderer(coordinateSystem: coordinateSystem)
    }

    // Canvas scroll state (2D scrolling)

    // Y-axis scroll (vertical - frequency axis)
    // paperTop: Y coordinate of paper top relative to viewport top
    //   - paperTop = 0 (maxPaperTop): paper top aligned with viewport top (cannot push down further)
    //   - paperTop = viewportH - canvasH (minPaperTop): paper bottom aligned with viewport bottom (cannot push up further)
    //   - Initial: paperTop = minPaperTop (bottom-aligned, low frequency visible)
    @State private var paperTop: CGFloat = 0
    @State private var lastPaperTop: CGFloat = 0

    // X-axis scroll (horizontal - time axis)
    // canvasOffsetX: X offset to apply to canvas (positive = move canvas right)
    //   - Formula: canvasOffsetX = playheadX - currentTimeCanvasX
    //   - Initial (currentTime=0): canvasOffsetX = playheadX (positive, canvas shifts right, 0s at center)
    //   - During playback: canvasOffsetX decreases (canvas shifts left, spectrogram flows left)
    // NOTE: With data positioned at leftPadding, initial offset = 0 aligns Canvas left edge with screen left edge
    // This puts 0s data (at Canvas x=leftPadding) at screen center (playheadX)
    @State private var canvasOffsetX: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("analysis.spectrogram_title".localized)
                .font(.subheadline)
                .fontWeight(.semibold)
                .accessibilityIdentifier("SpectrogramTitle")

            GeometryReader { geometry in
                let viewportWidth = geometry.size.width
                let viewportHeight = geometry.size.height
                let maxFreq = coordinateSystem.getMaxFrequency()
                let canvasHeight = coordinateSystem.calculateCanvasHeight(maxFreq: maxFreq, viewportHeight: viewportHeight)

                // Calculate canvas width based on data duration, NOT viewport
                let pixelsPerSecond: CGFloat = 300  // Ultra-high density for time axis zoom (6x from 50)
                // Add extra space at the beginning of canvas to ensure frequency labels
                // are always within canvas bounds even at initial scroll position
                let canvasLeftPadding: CGFloat = viewportWidth / 2  // Same as playhead offset
                let canvasWidth: CGFloat = {
                    if let data = spectrogramData, !data.timeStamps.isEmpty {
                        let dataDuration = data.timeStamps.last ?? 0.0
                        let dataWidth = CGFloat(dataDuration) * pixelsPerSecond
                        return max(dataWidth + canvasLeftPadding, 100)  // Include left padding
                    }
                    return viewportWidth + canvasLeftPadding  // fallback with padding
                }()

                let cellWidth = pixelsPerSecond * 0.1

                // Initialize scroll position to bottom when expanded (low frequency visible)
                let scrollableRange = canvasHeight - viewportHeight

                // Debug log
                let _ = {
                    FileLogger.shared.log(level: "INFO", category: "viewport_debug",
                        message: "🔍 VIEWPORT DEBUG: isExpanded=\(isExpanded), viewportW=\(viewportWidth), viewportH=\(viewportHeight), canvasW=\(canvasWidth), canvasH=\(canvasHeight), pixelsPerSecond=\(pixelsPerSecond), cellWidth=\(cellWidth), scrollableRange=\(scrollableRange)")
                }()

                // Canvas: Contains the entire frequency range (0Hz ~ maxFreq)
                Canvas { context, size in
                    if let data = spectrogramData, !data.timeStamps.isEmpty {
                        // Draw everything in canvas coordinates
                        // size here is the canvas size, not viewport size

                        // 1. Draw spectrogram (background) - SCROLLABLE
                        renderer.drawSpectrogram(
                            context: context,
                            canvasWidth: size.width,
                            canvasHeight: canvasHeight,
                            maxFreq: maxFreq,
                            data: data,
                            leftPadding: canvasLeftPadding
                        )

                        // 2. Draw Y-axis labels - Y-SCROLLABLE, X-FIXED
                        // Compensate for X scroll offset to keep labels in viewport
                        var yAxisContext = context
                        yAxisContext.translateBy(x: -canvasOffsetX, y: 0)
                        renderer.drawFrequencyLabels(
                            context: yAxisContext,
                            canvasHeight: canvasHeight,
                            maxFreq: maxFreq,
                            viewportHeight: viewportHeight,
                            paperTop: paperTop
                        )

                        // 3. Draw time axis (X-axis) - X-SCROLLABLE, Y-FIXED
                        // Compensate for Y scroll offset to keep labels at viewport bottom
                        var timeAxisContext = context
                        timeAxisContext.translateBy(x: 0, y: -paperTop)
                        renderer.drawTimeAxis(
                            context: timeAxisContext,
                            size: CGSize(width: size.width, height: viewportHeight),
                            leftPadding: canvasLeftPadding
                        )

                        // 4. Draw playback position (red line) - FULLY FIXED
                        // Compensate for both X and Y scroll offsets
                        var playheadContext = context
                        playheadContext.translateBy(x: -canvasOffsetX, y: -paperTop)
                        renderer.drawPlaybackPosition(context: playheadContext, size: CGSize(width: viewportWidth, height: viewportHeight))
                    } else {
                        renderer.drawPlaceholder(context: context, size: size)
                    }
                }
                .frame(width: canvasWidth, height: canvasHeight)  // Fixed canvas size based on data
                .offset(x: canvasOffsetX, y: paperTop)  // Scroll by moving canvas
                // - canvasOffsetX: X offset to keep currentTime position under red line (playhead)
                // - paperTop: Y offset for frequency axis scrolling (canvas top edge Y in viewport space)
                .frame(width: viewportWidth, height: viewportHeight, alignment: .topLeading)  // Viewport window
                .clipped()  // Viewport clips to visible area
                .accessibilityIdentifier("SpectrogramCanvas")
                .overlay(alignment: .topTrailing) {
                    if !isExpanded, let onExpand = onExpand {
                        Button(action: onExpand) {
                            Image(systemName: "arrow.down.left.and.arrow.up.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(6)
                        }
                        .padding(8)
                        .accessibilityLabel("フルスクリーン")
                        .accessibilityIdentifier("SpectrogramExpandButton")
                    } else if isExpanded, let onCollapse = onCollapse {
                        Button(action: onCollapse) {
                            Image(systemName: "arrow.up.right.and.arrow.down.left")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(6)
                        }
                        .padding(8)
                        .accessibilityLabel("閉じる")
                        .accessibilityIdentifier("SpectrogramCollapseButton")
                    }
                }
                .onAppear {
                    // Wait for layout to be ready, then initialize position
                    DispatchQueue.main.async {
                        // Y-axis scroll initialization (both Normal and Expanded views)
                        let viewportH = viewportHeight
                        let canvasH = canvasHeight
                        let maxPaperTop: CGFloat = 0
                        let minPaperTop = viewportH - canvasH

                        // Initial placement: bottom-aligned (low frequency visible)
                        paperTop = minPaperTop

                        // Clamp (mandatory after any movement)
                        paperTop = max(minPaperTop, min(maxPaperTop, paperTop))

                        lastPaperTop = paperTop

                        // X-axis scroll initialization
                        let playheadX = viewportWidth / 2
                        let currentTimeCanvasX = CGFloat(currentTime) * pixelsPerSecond + canvasLeftPadding
                        canvasOffsetX = playheadX - currentTimeCanvasX

                        os_log(.debug, log: OSLog(subsystem: "com.kazuasato.VocalisStudio", category: "scroll_init"),
                               "📍 Initial: paperTop=%{public}f, minPaperTop=%{public}f, maxPaperTop=%{public}f, canvasOffsetX=%{public}f",
                               paperTop, minPaperTop, maxPaperTop, canvasOffsetX)
                        FileLogger.shared.log(level: "INFO", category: "scroll_init",
                            message: "📍 Initial placement: paperTop=\(paperTop), viewportH=\(viewportH), canvasH=\(canvasH), canvasOffsetX=\(canvasOffsetX), playheadX=\(playheadX), currentTime=\(currentTime)")
                    }
                }
                .onChange(of: isExpanded) { _, newValue in
                    // Re-initialize position when expanding (for non-fullScreenCover transitions)
                    if newValue {
                        // Y-axis scroll re-initialization
                        let viewportH = viewportHeight
                        let canvasH = canvasHeight
                        let maxPaperTop: CGFloat = 0
                        let minPaperTop = viewportH - canvasH

                        // Initial placement: bottom-aligned
                        paperTop = minPaperTop

                        // Clamp (mandatory)
                        paperTop = max(minPaperTop, min(maxPaperTop, paperTop))

                        lastPaperTop = paperTop

                        // X-axis scroll re-initialization
                        let playheadX = viewportWidth / 2
                        let currentTimeCanvasX = CGFloat(currentTime) * pixelsPerSecond + canvasLeftPadding
                        canvasOffsetX = playheadX - currentTimeCanvasX

                        os_log(.debug, log: OSLog(subsystem: "com.kazuasato.VocalisStudio", category: "scroll_init"),
                               "📍 onChange reinit: paperTop=%{public}f, minPaperTop=%{public}f, canvasOffsetX=%{public}f",
                               paperTop, minPaperTop, canvasOffsetX)
                        FileLogger.shared.log(level: "INFO", category: "scroll_init",
                            message: "📍 Reinit on expand: paperTop=\(paperTop), viewportH=\(viewportH), canvasH=\(canvasH), canvasOffsetX=\(canvasOffsetX), playheadX=\(playheadX)")
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let translation = value.translation

                            // Detect drag direction
                            let angle = atan2(abs(translation.height), abs(translation.width))

                            if angle > .pi / 4 {
                                // Vertical-dominant drag: frequency axis scrolling
                                let viewportH = viewportHeight
                                let canvasH = canvasHeight
                                let maxPaperTop: CGFloat = 0
                                let minPaperTop = viewportH - canvasH

                                // Calculate candidate position
                                let candidate = lastPaperTop + translation.height

                                // Clamp immediately (mandatory after any movement)
                                paperTop = max(minPaperTop, min(maxPaperTop, candidate))
                            } else if let onSeek = onSeek {
                                // Horizontal-dominant drag: time axis seeking
                                // Calculate time change from horizontal translation (reduced sensitivity)
                                let seekSensitivity = 3.0  // Lower sensitivity: 3x more drag needed
                                let timeChange = -Double(translation.width) / (Double(pixelsPerSecond) * seekSensitivity)
                                let newTime = max(0, currentTime + timeChange)

                                // Seek to new time
                                onSeek(newTime)
                            }
                        }
                        .onEnded { _ in
                            lastPaperTop = paperTop
                        }
                )
                .onChange(of: currentTime) { _, newTime in
                    // Update canvasOffsetX to keep currentTime position under red line (playheadX)
                    let playheadX = viewportWidth / 2
                    let currentTimeCanvasX = CGFloat(newTime) * pixelsPerSecond + canvasLeftPadding
                    canvasOffsetX = playheadX - currentTimeCanvasX

                    // Calculate label position in viewport coordinates for verification
                    let labelViewportX = currentTimeCanvasX + canvasOffsetX
                    let alignmentError = abs(labelViewportX - playheadX)

                    FileLogger.shared.log(level: "DEBUG", category: "time_axis_scroll",
                        message: "⏩ Time axis scroll: currentTime=\(String(format: "%.2f", newTime))s, playheadX=\(String(format: "%.1f", playheadX)), labelCanvasX=\(String(format: "%.1f", currentTimeCanvasX)), canvasOffsetX=\(String(format: "%.1f", canvasOffsetX)), labelViewportX=\(String(format: "%.1f", labelViewportX)), alignmentError=\(String(format: "%.2f", alignmentError))px")
                }
            }
            .background(Color.black.opacity(0.1))
            .cornerRadius(8)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("SpectrogramView")
        .onTapGesture {
            onPlayPause?()
        }
    }

}

// MARK: - Pitch Analysis View

struct PitchAnalysisView: View {
    let currentTime: Double
    let pitchData: PitchAnalysisData?
    let scaleSettings: ScaleSettings?
    var isExpanded: Bool = false
    var onExpand: (() -> Void)? = nil
    var onCollapse: (() -> Void)? = nil
    var onPlayPause: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("analysis.pitch_graph_title".localized)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(ColorPalette.text)
                .accessibilityIdentifier("PitchGraphTitle")

            GeometryReader { geometry in
                Canvas { context, size in
                    if let data = pitchData, !data.timeStamps.isEmpty {
                        drawPitchGraph(context: context, size: size, data: data)
                    } else {
                        drawPlaceholder(context: context, size: size)
                    }
                    drawLegend(context: context, size: size)
                }
                .overlay(alignment: .topTrailing) {
                    if !isExpanded, let onExpand = onExpand {
                        Button(action: onExpand) {
                            Image(systemName: "arrow.down.left.and.arrow.up.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(6)
                        }
                        .padding(8)
                        .accessibilityLabel("フルスクリーン")
                        .accessibilityIdentifier("PitchGraphExpandButton")
                    } else if isExpanded, let onCollapse = onCollapse {
                        Button(action: onCollapse) {
                            Image(systemName: "arrow.up.right.and.arrow.down.left")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(6)
                        }
                        .padding(8)
                        .accessibilityLabel("閉じる")
                        .accessibilityIdentifier("PitchGraphCollapseButton")
                    }
                }
            }
            .background(ColorPalette.secondary)
            .cornerRadius(8)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("PitchAnalysisView")
        .onTapGesture {
            onPlayPause?()
        }
    }

    private func drawPitchGraph(context: GraphicsContext, size: CGSize, data: PitchAnalysisData) {
        let frequencies = data.frequencies
        guard !frequencies.isEmpty else { return }

        // Calculate frequency range with expansion
        let baseMinFreq = frequencies.min() ?? 200.0
        let baseMaxFreq = frequencies.max() ?? 800.0

        // Expanded view: show wider frequency range
        let minFreq = isExpanded ? max(100.0, baseMinFreq - 100) : baseMinFreq
        let maxFreq = isExpanded ? min(2000.0, baseMaxFreq + 200) : baseMaxFreq
        let freqRange = maxFreq - minFreq
        guard freqRange > 0 else { return }

        // Fixed pixel density (pixels per second)
        // Expanded view: LOWER density = WIDER time range displayed
        let pixelsPerSecond: CGFloat = isExpanded ? 30 : 50
        let leftMargin: CGFloat = 40
        let rightMargin: CGFloat = 10
        let topMargin: CGFloat = 50
        let bottomMargin: CGFloat = 30

        let graphWidth = size.width - leftMargin - rightMargin
        let graphHeight = size.height - topMargin - bottomMargin
        let centerX = leftMargin + graphWidth / 2  // Playback position at center

        // Calculate time window based on graph width and density
        let timeWindow = Double(graphWidth / pixelsPerSecond)

        // Draw target scale lines if available
        if let settings = scaleSettings {
            drawTargetScaleLines(context: context, leftMargin: leftMargin, topMargin: topMargin,
                               graphWidth: graphWidth, graphHeight: graphHeight,
                               minFreq: minFreq, freqRange: freqRange, settings: settings)
        }

        // Draw detected pitch line (only visible range)
        var path = Path()
        var pathStarted = false

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
                    centerTime: currentTime, timeWindow: timeWindow, pixelsPerSecond: pixelsPerSecond)
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
                             centerTime: Double, timeWindow: Double, pixelsPerSecond: CGFloat) {
        // Calculate half window based on actual time window
        let halfWindow = timeWindow / 2

        // Draw time labels at -halfWindow, 0s (center), +halfWindow
        let timeOffsets: [Double] = [-halfWindow, 0, halfWindow]
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
