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
                    onPlayPause: { viewModel.togglePlayback() },
                    onSeek: { time in viewModel.seek(to: time) }
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
                    onPlayPause: { viewModel.togglePlayback() },
                    onSeek: { time in viewModel.seek(to: time) }
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
                        onPlayPause: { viewModel.togglePlayback() },
                        onSeek: { time in viewModel.seek(to: time) }
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
    @State private var scrollManager = SpectrogramScrollManager()

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
                        yAxisContext.translateBy(x: -scrollManager.canvasOffsetX, y: 0)
                        renderer.drawFrequencyLabels(
                            context: yAxisContext,
                            canvasHeight: canvasHeight,
                            maxFreq: maxFreq,
                            viewportHeight: viewportHeight,
                            paperTop: scrollManager.paperTop
                        )

                        // 3. Draw time axis (X-axis) - X-SCROLLABLE, Y-FIXED
                        // Compensate for Y scroll offset to keep labels at viewport bottom
                        var timeAxisContext = context
                        timeAxisContext.translateBy(x: 0, y: -scrollManager.paperTop)
                        renderer.drawTimeAxis(
                            context: timeAxisContext,
                            size: CGSize(width: size.width, height: viewportHeight),
                            leftPadding: canvasLeftPadding
                        )

                        // 4. Draw playback position (red line) - FULLY FIXED
                        // Compensate for both X and Y scroll offsets
                        var playheadContext = context
                        playheadContext.translateBy(x: -scrollManager.canvasOffsetX, y: -scrollManager.paperTop)
                        renderer.drawPlaybackPosition(context: playheadContext, size: CGSize(width: viewportWidth, height: viewportHeight))
                    } else {
                        renderer.drawPlaceholder(context: context, size: size)
                    }
                }
                .frame(width: canvasWidth, height: canvasHeight)  // Fixed canvas size based on data
                .offset(x: scrollManager.canvasOffsetX, y: scrollManager.paperTop)  // Scroll by moving canvas
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
                        scrollManager.initializePosition(
                            viewportWidth: viewportWidth,
                            viewportHeight: viewportHeight,
                            canvasHeight: canvasHeight,
                            currentTime: currentTime,
                            pixelsPerSecond: pixelsPerSecond,
                            canvasLeftPadding: canvasLeftPadding
                        )
                    }
                }
                .onChange(of: isExpanded) { _, newValue in
                    // Re-initialize position when expanding (for non-fullScreenCover transitions)
                    if newValue {
                        scrollManager.initializePosition(
                            viewportWidth: viewportWidth,
                            viewportHeight: viewportHeight,
                            canvasHeight: canvasHeight,
                            currentTime: currentTime,
                            pixelsPerSecond: pixelsPerSecond,
                            canvasLeftPadding: canvasLeftPadding
                        )
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
                                scrollManager.handleVerticalDrag(
                                    translation: translation.height,
                                    viewportHeight: viewportHeight,
                                    canvasHeight: canvasHeight
                                )
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
                            scrollManager.endDrag()
                        }
                )
                .onChange(of: currentTime) { _, newTime in
                    scrollManager.updateTimeScroll(
                        currentTime: newTime,
                        viewportWidth: viewportWidth,
                        pixelsPerSecond: pixelsPerSecond,
                        canvasLeftPadding: canvasLeftPadding
                    )
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
    var onSeek: ((Double) -> Void)? = nil

    // Scroll manager for 2D scrolling (reusing SpectrogramScrollManager)
    @State private var scrollManager = SpectrogramScrollManager()

    // Drag state for horizontal seek
    @State private var lastDragTranslation: CGSize = .zero

    // Coordinate system and renderer
    private let coordinateSystem = PitchGraphCoordinateSystem()
    private let renderer = PitchGraphRenderer()

    // Drag gesture state
    @State private var dragStartLocation: CGPoint = .zero
    @State private var isDraggingVertically: Bool? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("analysis.pitch_graph_title".localized)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(ColorPalette.text)
                .accessibilityIdentifier("PitchGraphTitle")

            GeometryReader { geometry in
                let viewportWidth = geometry.size.width
                let viewportHeight = geometry.size.height
                let canvasHeight = coordinateSystem.calculateCanvasHeight()
                let leftPadding = coordinateSystem.calculateLeftPadding(viewportWidth: viewportWidth)
                let dataDuration = pitchData?.timeStamps.last ?? 10.0
                let canvasWidth = coordinateSystem.calculateCanvasWidth(dataDuration: dataDuration, leftPadding: leftPadding)

                Canvas { context, size in
                    var mutableContext = context
                    if let data = pitchData, !data.timeStamps.isEmpty {
                        drawPitchGraphCanvas(
                            context: &mutableContext,
                            viewportSize: size,
                            canvasHeight: canvasHeight,
                            canvasWidth: canvasWidth,
                            leftPadding: leftPadding,
                            data: data
                        )
                    } else {
                        renderer.drawPlaceholder(context: mutableContext, size: size)
                    }
                    drawLegend(context: mutableContext, size: size)
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            handleDrag(value: value, viewportHeight: viewportHeight, canvasHeight: canvasHeight)
                        }
                        .onEnded { _ in
                            scrollManager.endDrag()
                            isDraggingVertically = nil
                            lastDragTranslation = .zero
                        }
                )
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
                .onAppear {
                    // Wait for layout to be ready, then initialize position
                    DispatchQueue.main.async {
                        initializeScrollPosition(
                            viewportWidth: viewportWidth,
                            viewportHeight: viewportHeight,
                            canvasHeight: canvasHeight,
                            leftPadding: leftPadding
                        )
                    }
                }
                .onChange(of: isExpanded) { _, _ in
                    initializeScrollPosition(
                        viewportWidth: viewportWidth,
                        viewportHeight: viewportHeight,
                        canvasHeight: canvasHeight,
                        leftPadding: leftPadding
                    )
                }
                .onChange(of: pitchData?.frequencies.count) { _, newCount in
                    // Re-initialize scroll position when pitch data is loaded
                    if let count = newCount, count > 0 {
                        initializeScrollPosition(
                            viewportWidth: viewportWidth,
                            viewportHeight: viewportHeight,
                            canvasHeight: canvasHeight,
                            leftPadding: leftPadding
                        )
                    }
                }
                .onChange(of: currentTime) { _, newTime in
                    scrollManager.updateTimeScroll(
                        currentTime: newTime,
                        viewportWidth: viewportWidth,
                        pixelsPerSecond: PitchGraphConstants.pixelsPerSecond,
                        canvasLeftPadding: leftPadding
                    )
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

    // MARK: - Scroll Position Management

    private func initializeScrollPosition(
        viewportWidth: CGFloat,
        viewportHeight: CGFloat,
        canvasHeight: CGFloat,
        leftPadding: CGFloat
    ) {
        // Calculate target frequency to center (based on initial pitch data)
        var targetFrequency: Double? = nil
        if let data = pitchData, !data.frequencies.isEmpty {
            // Use pitch data from the first 3 seconds for initial positioning
            let initialDuration = 3.0
            var initialFrequencies: [Float] = []

            for i in 0..<data.timeStamps.count {
                if data.timeStamps[i] <= initialDuration {
                    initialFrequencies.append(data.frequencies[i])
                } else {
                    break
                }
            }

            // Fall back to all frequencies if no data in first 3 seconds
            let frequenciesToUse = initialFrequencies.isEmpty ? data.frequencies : initialFrequencies

            if let minFreq = frequenciesToUse.min(), let maxFreq = frequenciesToUse.max() {
                targetFrequency = (Double(minFreq) + Double(maxFreq)) / 2
            }
        }

        scrollManager.initializePosition(
            viewportWidth: viewportWidth,
            viewportHeight: viewportHeight,
            canvasHeight: canvasHeight,
            currentTime: currentTime,
            pixelsPerSecond: PitchGraphConstants.pixelsPerSecond,
            canvasLeftPadding: leftPadding
        )

        // Adjust Y position to center on detected pitch range
        if let targetFreq = targetFrequency {
            let coordinateSystem = PitchGraphCoordinateSystem()
            let targetCanvasY = coordinateSystem.frequencyToCanvasY(frequency: targetFreq, canvasHeight: canvasHeight)

            // Calculate paperTop to center targetCanvasY in viewport
            let idealPaperTop = viewportHeight / 2 - targetCanvasY

            // Clamp to valid range
            let maxPaperTop: CGFloat = 0
            let minPaperTop = viewportHeight - canvasHeight
            let clampedPaperTop = max(minPaperTop, min(maxPaperTop, idealPaperTop))

            scrollManager.paperTop = clampedPaperTop
            scrollManager.lastPaperTop = scrollManager.paperTop
        }
    }

    private func handleDrag(value: DragGesture.Value, viewportHeight: CGFloat, canvasHeight: CGFloat) {
        // Determine drag direction on first movement
        if isDraggingVertically == nil {
            let dx = abs(value.translation.width)
            let dy = abs(value.translation.height)
            if dx > 5 || dy > 5 {
                isDraggingVertically = dy > dx
            }
        }

        // Handle vertical drag for frequency scrolling
        if isDraggingVertically == true {
            scrollManager.handleVerticalDrag(
                translation: value.translation.height,
                viewportHeight: viewportHeight,
                canvasHeight: canvasHeight
            )
        } else if isDraggingVertically == false {
            // Handle horizontal drag for seek
            let dataDuration = pitchData?.timeStamps.last ?? 10.0
            let deltaX = value.translation.width - lastDragTranslation.width
            let deltaTime = -Double(deltaX) / Double(PitchGraphConstants.pixelsPerSecond)
            let newTime = max(0, min(dataDuration, currentTime + deltaTime))

            lastDragTranslation = value.translation
            onSeek?(newTime)
        }
    }

    // MARK: - Canvas Drawing

    private func drawPitchGraphCanvas(
        context: inout GraphicsContext,
        viewportSize: CGSize,
        canvasHeight: CGFloat,
        canvasWidth: CGFloat,
        leftPadding: CGFloat,
        data: PitchAnalysisData
    ) {
        let viewportWidth = viewportSize.width
        let viewportHeight = viewportSize.height

        // Create clipping region for graph area
        let clipRect = CGRect(
            x: PitchGraphConstants.leftMargin,
            y: 0,
            width: viewportWidth - PitchGraphConstants.leftMargin - PitchGraphConstants.rightMargin,
            height: viewportHeight - PitchGraphConstants.bottomMargin
        )

        // Draw main graph content with clipping (using a copy of context)
        var clippedContext = context
        clippedContext.clip(to: Path(clipRect))

        // Apply canvas offset for scrolling
        clippedContext.translateBy(x: scrollManager.canvasOffsetX, y: scrollManager.paperTop)

        // Draw background grid
        renderer.drawBackground(
            context: clippedContext,
            canvasHeight: canvasHeight,
            canvasWidth: canvasWidth,
            leftPadding: leftPadding
        )

        // Draw target scale lines if available
        if let settings = scaleSettings {
            let targetFrequencies = getTargetFrequencies(from: settings)
            renderer.drawTargetScaleLines(
                context: clippedContext,
                canvasHeight: canvasHeight,
                targetFrequencies: targetFrequencies,
                leftPadding: leftPadding,
                canvasWidth: canvasWidth
            )
        }

        // Prepare pitch data for renderer
        let pitchPoints = preparePitchData(from: data)
        renderer.drawPitchData(
            context: clippedContext,
            canvasHeight: canvasHeight,
            pitchData: pitchPoints,
            leftPadding: leftPadding
        )

        // Draw frequency labels (fixed X, scrolling Y) - use original context without clipping
        renderer.drawFrequencyLabels(
            context: context,
            canvasHeight: canvasHeight,
            viewportHeight: viewportHeight,
            paperTop: scrollManager.paperTop
        )

        // Draw time labels (scrolling X, fixed Y)
        let dataDuration = data.timeStamps.last ?? 10.0
        renderer.drawTimeLabels(
            context: context,
            dataDuration: dataDuration,
            leftPadding: leftPadding,
            viewportWidth: viewportWidth,
            viewportHeight: viewportHeight,
            canvasOffsetX: scrollManager.canvasOffsetX
        )

        // Draw playback position line (fully fixed)
        renderer.drawPlaybackPosition(
            context: context,
            viewportWidth: viewportWidth,
            viewportHeight: viewportHeight
        )
    }

    private func preparePitchData(from data: PitchAnalysisData) -> [(time: Double, frequency: Double, confidence: Float)] {
        var result: [(Double, Double, Float)] = []

        for (index, timestamp) in data.timeStamps.enumerated() {
            let frequency = Double(data.frequencies[index])
            let confidence = data.confidences[index]

            // Filter out frequencies outside display range
            guard frequency >= PitchGraphConstants.minFrequency &&
                  frequency <= PitchGraphConstants.maxFrequency else { continue }

            result.append((timestamp, frequency, confidence))
        }

        return result
    }

    private func getTargetFrequencies(from settings: ScaleSettings) -> [Double] {
        var frequencies: [Double] = []
        let startValue = settings.startNote.value
        let endValue = settings.endNote.value

        var currentOctaveStart = Int(startValue)
        while currentOctaveStart <= Int(endValue) {
            for interval in settings.notePattern.intervals {
                let noteValue = UInt8(currentOctaveStart + interval)
                if noteValue >= startValue && noteValue <= endValue {
                    if let note = try? MIDINote(noteValue) {
                        frequencies.append(note.frequency)
                    }
                }
            }
            currentOctaveStart += 12
        }

        return frequencies
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

    func play(url: URL, withPitchDetection: Bool) async throws {
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
