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
                    spectrogramData: viewModel.analysisResult?.spectrogramData
                )
                .frame(maxHeight: .infinity)
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        expandedGraph = .spectrogram
                    }
                }

                Divider()

                // Pitch analysis graph (bottom half)
                PitchAnalysisView(
                    currentTime: viewModel.currentTime,
                    pitchData: viewModel.analysisResult?.pitchData,
                    scaleSettings: viewModel.analysisResult?.scaleSettings
                )
                .frame(maxHeight: .infinity)
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        expandedGraph = .pitchAnalysis
                    }
                }
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
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        expandedGraph = .spectrogram
                    }
                }

                PitchAnalysisView(
                    currentTime: viewModel.currentTime,
                    pitchData: viewModel.analysisResult?.pitchData,
                    scaleSettings: viewModel.analysisResult?.scaleSettings
                )
                .frame(height: 200)
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        expandedGraph = .pitchAnalysis
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Expanded Graph Full Screen

    @ViewBuilder
    private func expandedGraphFullScreen(for type: ExpandedGraphType) -> some View {
        ZStack(alignment: .topTrailing) {
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
                        isExpanded: true
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .pitchAnalysis:
                    PitchAnalysisView(
                        currentTime: viewModel.currentTime,
                        pitchData: viewModel.analysisResult?.pitchData,
                        scaleSettings: viewModel.analysisResult?.scaleSettings,
                        isExpanded: true
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Compact playback control
                CompactPlaybackControl(
                    isPlaying: viewModel.isPlaying,
                    onPlayPause: { viewModel.togglePlayback() }
                )
                .padding()
                .background(ColorPalette.secondary.opacity(0.9))
            }

            // Close button (top right)
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    expandedGraph = nil
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(ColorPalette.text.opacity(0.8))
                    .padding()
            }
            .accessibilityLabel("analysis.close_expanded_view".localized)
            .accessibilityIdentifier("CloseExpandedViewButton")
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

    // Canvas scroll state (2D scrolling)
    // paperTop: Y coordinate of paper top relative to viewport top (vertical scroll)
    //   - paperTop = 0 (maxPaperTop): paper top aligned with viewport top (cannot push down further)
    //   - paperTop = viewportH - canvasH (minPaperTop): paper bottom aligned with viewport bottom (cannot push up further)
    //   - Initial: paperTop = minPaperTop (bottom-aligned, low frequency visible)
    @State private var paperTop: CGFloat = 0
    @State private var lastPaperTop: CGFloat = 0

    // paperLeft: X coordinate of paper left relative to viewport left (horizontal scroll)
    //   - paperLeft = viewportW / 2 - currentTime * pixelsPerSecond (playback cursor at center)
    //   - maxPaperLeft = viewportW / 2 (allows recording start (0s) to be centered)
    //   - minPaperLeft = viewportW - canvasW (paper right aligned with viewport right - end of recording)
    @State private var paperLeft: CGFloat = 0
    @State private var lastPaperLeft: CGFloat = 0
    @State private var isPaperLeftInitialized: Bool = false  // Flag to track initialization

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("analysis.spectrogram_title".localized)
                .font(.subheadline)
                .fontWeight(.semibold)
                .accessibilityIdentifier("SpectrogramTitle")

            GeometryReader { geometry in
                let viewportWidth = geometry.size.width
                let viewportHeightTotal = geometry.size.height

                // Fixed dimensions
                let labelColW: CGFloat = 72  // Fixed label column width
                let timeLabelHeight: CGFloat = 30  // Fixed time label band height

                // Separate label column width from spectrogram viewport width
                let spectroViewportW = max(0, viewportWidth - labelColW)

                // Spectrogram viewport height (excluding time label band)
                let viewportHeight = max(0, viewportHeightTotal - timeLabelHeight)

                let maxFreq = getMaxFrequency()
                let canvasHeight = calculateCanvasHeight(maxFreq: maxFreq, viewportHeight: viewportHeight)

                // Calculate duration strictly from min/max timestamps (in seconds)
                let durationSec: Double = {
                    guard let ts = spectrogramData?.timeStamps, ts.count >= 2 else { return 0 }
                    let minT = ts.min() ?? 0
                    let maxT = ts.max() ?? 0
                    return max(0, maxT - minT)
                }()

                // Fixed pixel density (NEVER changes with fullscreen)
                let pixelsPerSecond: CGFloat = 50

                // Canvas width: data width only (never pad to viewport width)
                let canvasWidth: CGFloat = CGFloat(durationSec) * pixelsPerSecond

                let cellWidth = pixelsPerSecond * 0.1

                // playheadX: Fixed position at viewport center (red cursor position)
                let playheadX = spectroViewportW / 2

                // Initialize horizontal scroll position
                // Initial: paperLeft = -playheadX (paper's left edge touches red line)
                let _ = {
                    // Only initialize once when data is available and not yet initialized
                    if !isPaperLeftInitialized && spectrogramData != nil {
                        // Initial: paper's left edge (0s) at red line (center)
                        paperLeft = -playheadX
                        lastPaperLeft = paperLeft
                        isPaperLeftInitialized = true

                        FileLogger.shared.log(level: "INFO", category: "paperLeft_init",
                            message: "📍 paperLeft initialized: \(paperLeft), playheadX=\(playheadX), spectroViewportW=\(spectroViewportW), canvasW=\(canvasWidth), durationSec=\(durationSec)")
                    }
                }()

                // Initialize scroll position to bottom when expanded (low frequency visible)
                let scrollableRange = canvasHeight - viewportHeight

                // Debug log
                let _ = {
                    FileLogger.shared.log(level: "INFO", category: "viewport_debug",
                        message: "🔍 VIEWPORT DEBUG: isExpanded=\(isExpanded), viewportW=\(viewportWidth), spectroViewportW=\(spectroViewportW), viewportH=\(viewportHeight), canvasW=\(canvasWidth), canvasH=\(canvasHeight), durationSec=\(durationSec), pixelsPerSecond=\(pixelsPerSecond), paperLeft=\(paperLeft)")
                }()

                // HStack: Separate label column (left lane) and spectrogram area (right lane)
                HStack(spacing: 0) {
                    // Left lane: Frequency labels column (fixed 72px width)
                    // - X is fixed (does not move horizontally)
                    // - Y follows offsetY only (vertical scroll)
                    Canvas { context, size in
                        if spectrogramData != nil {
                            drawFrequencyLabelsOnCanvas(
                                context: context,
                                canvasHeight: canvasHeight,
                                maxFreq: maxFreq
                            )
                        }
                    }
                    .frame(width: labelColW, height: canvasHeight)
                    .offset(x: 0, y: -paperTop)  // Y-only tracking (negative = paper moves up)
                    .frame(width: labelColW, height: viewportHeight)
                    .clipped()

                    // Right lane: VStack containing spectrogram area and time label band
                    VStack(spacing: 0) {
                        // Upper: Spectrogram canvas with red playback cursor overlay
                        ZStack(alignment: .topLeading) {
                            // Background: Spectrogram canvas (2D scrollable)
                            Canvas { context, size in
                                if let data = spectrogramData, !data.timeStamps.isEmpty {
                                    // Calculate actual data width (duration × pixelsPerSecond)
                                    let dataWidth = CGFloat(durationSec) * pixelsPerSecond

                                    // 1. Draw spectrogram (background) - SCROLLABLE
                                    drawSpectrogramOnCanvas(
                                        context: context,
                                        canvasWidth: dataWidth,  // Only draw data width, not padded canvas width
                                        canvasHeight: canvasHeight,
                                        maxFreq: maxFreq,
                                        data: data
                                    )

                                    // 2. Pad remaining area with weakest color (if canvas is wider than data)
                                    if size.width > dataWidth {
                                        let weakestColor = Color(red: 0.1, green: 0.1, blue: 0.2)  // Dark blue - weakest intensity
                                        let padRect = CGRect(x: dataWidth, y: 0, width: size.width - dataWidth, height: size.height)
                                        context.fill(Path(padRect), with: .color(weakestColor))
                                    }
                                } else {
                                    drawPlaceholder(context: context, size: size)
                                }
                            }
                            .frame(width: canvasWidth, height: canvasHeight)  // Fixed canvas size based on data
                            .offset(x: -paperLeft, y: -paperTop)  // 2D scroll (negative = paper moves left/up)
                            .frame(width: spectroViewportW, height: viewportHeight)  // Viewport window size
                            .clipped()  // Clip to viewport

                            // Foreground: Red playback cursor (fixed at playheadX position)
                            Canvas { context, size in
                                // Red cursor is always at viewport center (playheadX)
                                let cursorX = playheadX

                                context.stroke(
                                    Path { path in
                                        path.move(to: CGPoint(x: cursorX, y: 0))
                                        path.addLine(to: CGPoint(x: cursorX, y: size.height))
                                    },
                                    with: .color(.red),
                                    lineWidth: 2
                                )
                            }
                            .frame(width: spectroViewportW, height: viewportHeight)
                            .allowsHitTesting(false)
                        }

                        // Lower: Time label band (separate lane)
                        // - X follows offsetX only (horizontal scroll)
                        // - Y is fixed (does not move vertically)
                        Canvas { context, size in
                            if spectrogramData != nil {
                                drawSpectrogramTimeAxis(context: context, size: size, durationSec: durationSec)
                            }
                        }
                        .frame(width: canvasWidth, height: timeLabelHeight)  // Canvas size
                        .offset(x: -paperLeft, y: 0)  // X-only tracking (negative = paper moves left)
                        .frame(width: spectroViewportW, height: timeLabelHeight, alignment: .topLeading)  // Clip with topLeading alignment
                        .clipped()
                    }
                }
                .frame(width: viewportWidth, height: viewportHeightTotal)
                .accessibilityIdentifier("SpectrogramCanvas")
                .onAppear {
                    // Wait for layout to be ready, then initialize position
                    DispatchQueue.main.async {
                        if isExpanded {
                            // Strict definitions
                            let viewportH = viewportHeight
                            let canvasH = canvasHeight
                            let maxPaperTop: CGFloat = 0
                            let minPaperTop = viewportH - canvasH

                            // Initial placement: bottom-aligned (downside fixed)
                            paperTop = minPaperTop

                            // Clamp (mandatory after any movement)
                            paperTop = max(minPaperTop, min(maxPaperTop, paperTop))

                            lastPaperTop = paperTop

                            os_log(.debug, log: OSLog(subsystem: "com.kazuasato.VocalisStudio", category: "scroll_init"),
                                   "📍 Initial: paperTop=%{public}f, minPaperTop=%{public}f, maxPaperTop=%{public}f",
                                   paperTop, minPaperTop, maxPaperTop)
                            FileLogger.shared.log(level: "INFO", category: "scroll_init",
                                message: "📍 Initial placement: paperTop=\(paperTop), viewportH=\(viewportH), canvasH=\(canvasH)")
                        }
                    }
                }
                .onChange(of: isExpanded) { _, newValue in
                    // Re-initialize position when expanding (for non-fullScreenCover transitions)
                    if newValue {
                        let viewportH = viewportHeight
                        let canvasH = canvasHeight
                        let maxPaperTop: CGFloat = 0
                        let minPaperTop = viewportH - canvasH

                        // Initial placement: bottom-aligned
                        paperTop = minPaperTop

                        // Clamp (mandatory)
                        paperTop = max(minPaperTop, min(maxPaperTop, paperTop))

                        lastPaperTop = paperTop

                        os_log(.debug, log: OSLog(subsystem: "com.kazuasato.VocalisStudio", category: "scroll_init"),
                               "📍 onChange reinit: paperTop=%{public}f, minPaperTop=%{public}f",
                               paperTop, minPaperTop)
                        FileLogger.shared.log(level: "INFO", category: "scroll_init",
                            message: "📍 Reinit on expand: paperTop=\(paperTop), viewportH=\(viewportH), canvasH=\(canvasH)")
                    }
                }
                .onChange(of: currentTime) { _, newTime in
                    // Update paperLeft to keep currentTime position under red line (playheadX)
                    // Formula: paperLeft = min(currentTime * pps - playheadX, canvasW - playheadX)
                    let playheadX = spectroViewportW / 2
                    let paperLeft_target = CGFloat(newTime) * pixelsPerSecond - playheadX
                    let paperLeft_max = canvasWidth - playheadX
                    paperLeft = min(paperLeft_target, paperLeft_max)
                    // No lower clamp (allow negative values for initial state)

                    FileLogger.shared.log(level: "DEBUG", category: "playback_scroll",
                        message: "⏩ Playback scroll: currentTime=\(newTime), paperLeft=\(paperLeft), target=\(paperLeft_target), max=\(paperLeft_max), playheadX=\(playheadX)")
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let translation = value.translation

                            // Detect vertical-dominant drag
                            let angle = atan2(abs(translation.height), abs(translation.width))

                            if angle > .pi / 4 {
                                // Strict definitions
                                let viewportH = viewportHeight
                                let canvasH = canvasHeight
                                let maxPaperTop: CGFloat = 0
                                let minPaperTop = viewportH - canvasH

                                // Calculate candidate position
                                let candidate = lastPaperTop + translation.height

                                // Clamp immediately (mandatory after any movement)
                                paperTop = max(minPaperTop, min(maxPaperTop, candidate))
                            }
                        }
                        .onEnded { _ in
                            lastPaperTop = paperTop
                        }
                )
            }
            .background(Color.black.opacity(0.1))
            .cornerRadius(8)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("SpectrogramView")
    }

    // MARK: - Canvas Architecture - Phase 1: Core Functions

    /// Calculate canvas height based on frequency range
    /// Canvas contains entire frequency range (0Hz ~ maxFreq)
    /// - Parameters:
    ///   - maxFreq: Maximum frequency in Hz (UI display limit, not data limit)
    ///   - viewportHeight: Unused (kept for API compatibility), canvas size is data-driven
    /// - Returns: Canvas height in points
    private func calculateCanvasHeight(maxFreq: Double, viewportHeight: CGFloat) -> CGFloat {
        // Fixed pixel density per kHz (isExpanded only affects viewport, not canvas drawing)
        let basePixelsPerKHz: CGFloat = 60.0
        let canvasHeight = CGFloat(maxFreq / 1000.0) * basePixelsPerKHz

        // Apply maximum limit to prevent excessive memory usage
        let maxHeight: CGFloat = 10000.0

        return min(maxHeight, canvasHeight)
    }

    /// Convert frequency (Hz) to Canvas Y coordinate
    /// Canvas coordinate system: Y=0 at top (maxFreq), Y=canvasHeight at bottom (0Hz)
    /// - Parameters:
    ///   - frequency: Frequency in Hz
    ///   - canvasHeight: Total canvas height in points
    ///   - maxFreq: Maximum frequency in Hz
    /// - Returns: Y coordinate in canvas space
    private func frequencyToCanvasY(frequency: Double, canvasHeight: CGFloat, maxFreq: Double) -> CGFloat {
        let ratio = (maxFreq - frequency) / maxFreq
        return CGFloat(ratio) * canvasHeight
    }

    /// Get maximum frequency for display (fixed UI limit)
    /// - Returns: Fixed maximum frequency for UI display (8kHz)
    /// - Note: This is a UI design decision, not data-driven.
    ///         Keeping display range fixed provides stable UI and predictable scrolling.
    private func getMaxFrequency() -> Double {
        // Expanded view shows wider frequency range for scroll testing
        return isExpanded ? 12000.0 : 8000.0  // Normal: 8kHz, Expanded: 12kHz (for scroll testing)
    }

    // MARK: - Canvas Architecture - Phase 1: Y-Axis Label Drawing

    /// Draw frequency labels on canvas (canvas coordinate system)
    /// Labels are drawn at fixed intervals across entire canvas
    /// - Parameters:
    ///   - context: Graphics context
    ///   - canvasHeight: Total canvas height
    ///   - maxFreq: Maximum frequency
    private func drawFrequencyLabelsOnCanvas(
        context: GraphicsContext,
        canvasHeight: CGFloat,
        maxFreq: Double
    ) {
        // Fixed label interval in canvas coordinate system
        let labelInterval: Double = 1000.0  // 1kHz
        let textHeight: CGFloat = 16
        let textWidth: CGFloat = 45

        // Clipping margin to prevent labels from being cut off at edges
        let clipMargin = textHeight / 2

        var frequency: Double = 0
        while frequency <= maxFreq {
            // Calculate canvas Y position
            let canvasY = frequencyToCanvasY(
                frequency: frequency,
                canvasHeight: canvasHeight,
                maxFreq: maxFreq
            )

            // Clamp label position to prevent cutoff at top/bottom edges
            let clampedY = max(clipMargin, min(canvasHeight - clipMargin, canvasY))

            // Create label text
            let labelText: String
            if frequency >= 1000 {
                let kHz = frequency / 1000.0
                labelText = kHz.truncatingRemainder(dividingBy: 1.0) == 0 ?
                    "\(Int(kHz))k" : String(format: "%.1fk", kHz)
            } else {
                labelText = "\(Int(frequency))Hz"
            }

            let text = Text(labelText)
                .font(.caption2)
                .foregroundColor(.white)

            // Draw background with clamped position
            let backgroundRect = CGRect(
                x: 5,
                y: clampedY - textHeight / 2,
                width: textWidth,
                height: textHeight
            )

            context.fill(
                Path(roundedRect: backgroundRect, cornerRadius: 4),
                with: .color(.black.opacity(0.6))
            )

            // Draw text with clamped position
            context.draw(
                text,
                at: CGPoint(x: 5 + textWidth / 2, y: clampedY)
            )

            frequency += labelInterval
        }
    }

    // MARK: - Canvas Architecture - Phase 2: Spectrogram Drawing

    /// Draw spectrogram on canvas (canvas coordinate system)
    /// - Parameters:
    ///   - context: Graphics context
    ///   - canvasWidth: Canvas width
    ///   - canvasHeight: Canvas height
    ///   - maxFreq: Maximum frequency
    ///   - data: Spectrogram data
    private func drawSpectrogramOnCanvas(
        context: GraphicsContext,
        canvasWidth: CGFloat,
        canvasHeight: CGFloat,
        maxFreq: Double,
        data: SpectrogramData
    ) {
        // Fixed time axis density (isExpanded only affects viewport, not drawing parameters)
        let pixelsPerSecond: CGFloat = 50
        let timeWindow = Double(canvasWidth / pixelsPerSecond)
        let centerX = canvasWidth / 2
        let maxMagnitude = data.magnitudes.flatMap { $0 }.max() ?? 1.0

        // Calculate cell dimensions
        let cellWidth = pixelsPerSecond * 0.1

        // Determine the highest frequency bin we have data for
        let maxDataFreq = data.frequencyBins.last.map { Double($0) } ?? 0.0

        // Calculate number of bins needed to cover entire canvas (0Hz to maxFreq)
        let avgBinWidth: Double
        if data.frequencyBins.count >= 2 {
            avgBinWidth = Double(data.frequencyBins[1] - data.frequencyBins[0])
        } else {
            avgBinWidth = 100.0  // fallback
        }

        let totalBinsNeeded = Int(ceil(maxFreq / avgBinWidth))

        // Draw all frequency bins (including areas with no data)
        for binIndex in 0..<totalBinsNeeded {
            let binFreqLow = Double(binIndex) * avgBinWidth
            let binFreqHigh = Double(binIndex + 1) * avgBinWidth

            // Skip if this bin is entirely above maxFreq
            guard binFreqLow < maxFreq else { break }

            // Find corresponding data bin index (if exists)
            let dataFreqIndex = data.frequencyBins.firstIndex { Double($0) >= binFreqLow }

            // Convert frequency range to canvas Y coordinates
            let yTop = frequencyToCanvasY(
                frequency: min(binFreqHigh, maxFreq),
                canvasHeight: canvasHeight,
                maxFreq: maxFreq
            )
            let yBottom = frequencyToCanvasY(
                frequency: binFreqLow,
                canvasHeight: canvasHeight,
                maxFreq: maxFreq
            )
            let cellHeight = yBottom - yTop

            // Draw cells for this frequency bin across time
            for (timeIndex, timestamp) in data.timeStamps.enumerated() {
                let timeOffset = timestamp - currentTime
                guard abs(timeOffset) <= timeWindow / 2 else { continue }

                let x = centerX + CGFloat(timeOffset) * pixelsPerSecond

                // Get magnitude from data (if exists)
                let magnitude: Float
                if let dataIdx = dataFreqIndex,
                   timeIndex < data.magnitudes.count,
                   dataIdx < data.magnitudes[timeIndex].count {
                    magnitude = data.magnitudes[timeIndex][dataIdx]
                } else {
                    magnitude = 0.0  // No data - use weakest color
                }

                // Color calculation with proper weakest color
                let normalizedMagnitude = CGFloat(magnitude / maxMagnitude)

                // Gradient: blue-purple (hue ~0.6) for weak → green-yellow (hue ~0.0) for strong
                let hue = 0.6 - normalizedMagnitude * 0.6

                // For magnitude = 0, show visible weak color (not black)
                // saturation: keep constant for consistent color
                // brightness: ensure minimum visibility even at magnitude = 0
                let saturation: CGFloat = 0.8
                let brightness: CGFloat
                if normalizedMagnitude < 0.01 {
                    // Weakest color: clearly visible dark blue-purple
                    brightness = 0.3
                } else {
                    // Scale brightness for stronger signals
                    brightness = 0.3 + 0.6 * normalizedMagnitude
                }

                let color = Color(hue: hue, saturation: saturation, brightness: brightness)

                let rect = CGRect(x: x, y: yTop, width: cellWidth, height: cellHeight)
                context.fill(Path(rect), with: .color(color))
            }
        }
    }

    private func drawPlaceholder(context: GraphicsContext, size: CGSize) {
        let text = Text("分析データなし").font(.caption).foregroundColor(.secondary)
        context.draw(text, at: CGPoint(x: size.width / 2, y: size.height / 2))
    }

    private func drawPlaybackPosition(context: GraphicsContext, size: CGSize) {
        // Draw playback cursor at viewport center (fixed position)
        // This is drawn in viewport coordinates, so always at center
        let centerX = size.width / 2

        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: centerX, y: 0))
                path.addLine(to: CGPoint(x: centerX, y: size.height))
            },
            with: .color(.red),  // Red cursor for visibility
            lineWidth: 2
        )
    }

    private func drawSpectrogramTimeAxis(context: GraphicsContext, size: CGSize, durationSec: Double) {
        // Draw time axis with labels at fixed canvas coordinates
        // Only draw from 0 to durationSec (never beyond recording duration)
        let pixelsPerSecond: CGFloat = 50

        // Draw labels at 1-second intervals from 0 to durationSec
        let labelInterval: Double = 1.0  // 1 second
        var time: Double = 0

        while time <= durationSec {
            let x = CGFloat(time) * pixelsPerSecond
            let y = size.height / 2  // Center vertically in label band

            let text = Text(String(format: "%.0fs", time))
                .font(.caption)
                .foregroundColor(.gray)

            // Draw with leading (left) anchor so text doesn't get cut off at edges
            context.draw(text, at: CGPoint(x: x, y: y), anchor: .leading)

            time += labelInterval
        }
    }
}

// MARK: - Pitch Analysis View

struct PitchAnalysisView: View {
    let currentTime: Double
    let pitchData: PitchAnalysisData?
    let scaleSettings: ScaleSettings?
    var isExpanded: Bool = false

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
            }
            .background(ColorPalette.secondary)
            .cornerRadius(8)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("PitchAnalysisView")
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
