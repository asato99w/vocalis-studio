import SwiftUI
import VocalisDomain

/// Main recording screen view with settings panel and real-time visualization
public struct RecordingView: View {
    @StateObject private var viewModel: RecordingViewModel
    @StateObject private var settingsViewModel = MockRecordingSettingsViewModel()
    @StateObject private var localization = LocalizationManager.shared
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var isSettingsPanelVisible: Bool = true

    public init(viewModel: RecordingViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
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
        .navigationTitle("recording.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: RecordingListView(
                    viewModel: RecordingListViewModel(
                        recordingRepository: DependencyContainer.shared.recordingRepository,
                        audioPlayer: DependencyContainer.shared.audioPlayer
                    )
                )) {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                        Text("recording.list_button".localized)
                    }
                }
            }
        }
        .alert(isPresented: .constant(viewModel.errorMessage != nil)) {
            Alert(
                title: Text("error".localized),
                message: Text(viewModel.errorMessage ?? ""),
                dismissButton: .default(Text("ok".localized))
            )
        }
        .onChange(of: viewModel.recordingState) { newState in
            // Auto-hide settings panel when recording starts
            if newState == .recording {
                withAnimation {
                    isSettingsPanelVisible = false
                }
            }
        }
    }

    // MARK: - Landscape Layout

    private var landscapeLayout: some View {
        HStack(spacing: 0) {
            // Left side: Settings panel (collapsible)
            if isSettingsPanelVisible {
                RecordingSettingsPanel(viewModel: settingsViewModel)
                    .frame(width: 240)
                    .transition(.move(edge: .leading))

                Divider()
            }

            // Right side: Real-time display and controls
            VStack(spacing: 8) {
                // Toggle button for settings panel
                HStack {
                    Button(action: {
                        withAnimation {
                            isSettingsPanelVisible.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isSettingsPanelVisible ? "sidebar.left" : "gearshape.fill")
                            Text(isSettingsPanelVisible ? "recording.hide_settings".localized : "recording.show_settings".localized)
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                    }
                    .disabled(viewModel.recordingState == .recording)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                RealtimeDisplayArea(
                    recordingState: viewModel.recordingState,
                    isPlayingRecording: viewModel.isPlayingRecording,
                    targetPitch: viewModel.targetPitch,
                    detectedPitch: viewModel.detectedPitch,
                    pitchAccuracy: viewModel.pitchAccuracy,
                    spectrum: viewModel.spectrum
                )
                .frame(maxHeight: .infinity)

                RecordingControls(
                    recordingState: viewModel.recordingState,
                    hasLastRecording: viewModel.lastRecordingURL != nil,
                    isPlayingRecording: viewModel.isPlayingRecording,
                    onStart: {
                        Task {
                            let settings = settingsViewModel.generateScaleSettings()
                            print("📱 [RecordingView] 録音開始: scaleType=\(settingsViewModel.scaleType), settings=\(settings != nil ? "あり" : "なし")")
                            await viewModel.startRecording(settings: settings)
                        }
                    },
                    onStop: {
                        Task {
                            await viewModel.stopRecording()
                        }
                    },
                    onCancel: {
                        Task {
                            await viewModel.cancelCountdown()
                        }
                    },
                    onPlayLast: {
                        Task {
                            if viewModel.isPlayingRecording {
                                await viewModel.stopPlayback()
                            } else {
                                await viewModel.playLastRecording()
                            }
                        }
                    }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Portrait Layout

    private var portraitLayout: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Toggle button for settings panel
                HStack {
                    Button(action: {
                        withAnimation {
                            isSettingsPanelVisible.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isSettingsPanelVisible ? "chevron.up" : "gearshape.fill")
                            Text(isSettingsPanelVisible ? "recording.hide_settings".localized : "recording.show_settings".localized)
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .disabled(viewModel.recordingState == .recording)

                    Spacer()
                }

                // Settings panel (collapsible)
                if isSettingsPanelVisible {
                    RecordingSettingsCompact(viewModel: settingsViewModel)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                RealtimeDisplayArea(
                    recordingState: viewModel.recordingState,
                    isPlayingRecording: viewModel.isPlayingRecording,
                    targetPitch: viewModel.targetPitch,
                    detectedPitch: viewModel.detectedPitch,
                    pitchAccuracy: viewModel.pitchAccuracy,
                    spectrum: viewModel.spectrum
                )
                .frame(height: isSettingsPanelVisible ? 200 : 350)

                RecordingControls(
                    recordingState: viewModel.recordingState,
                    hasLastRecording: viewModel.lastRecordingURL != nil,
                    isPlayingRecording: viewModel.isPlayingRecording,
                    onStart: {
                        Task {
                            let settings = settingsViewModel.generateScaleSettings()
                            print("📱 [RecordingView] 録音開始: scaleType=\(settingsViewModel.scaleType), settings=\(settings != nil ? "あり" : "なし")")
                            await viewModel.startRecording(settings: settings)
                        }
                    },
                    onStop: {
                        Task {
                            await viewModel.stopRecording()
                        }
                    },
                    onCancel: {
                        Task {
                            await viewModel.cancelCountdown()
                        }
                    },
                    onPlayLast: {
                        Task {
                            if viewModel.isPlayingRecording {
                                await viewModel.stopPlayback()
                            } else {
                                await viewModel.playLastRecording()
                            }
                        }
                    }
                )
            }
            .padding()
        }
    }
}

// MARK: - Recording Settings Panel

struct RecordingSettingsPanel: View {
    @ObservedObject var viewModel: MockRecordingSettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("recording.settings_title".localized)
                    .font(.headline)
                    .padding(.bottom, 4)

                // Scale selection
                VStack(alignment: .leading, spacing: 6) {
                    Text("recording.scale_label".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("recording.scale_label".localized, selection: $viewModel.scaleType) {
                        Text("recording.scale_five_tone".localized).tag(ScaleType.fiveTone)
                        Text("recording.scale_off".localized).tag(ScaleType.off)
                    }
                    .pickerStyle(.segmented)
                }

                // Start pitch
                VStack(alignment: .leading, spacing: 6) {
                    Text("recording.start_pitch_label".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("recording.start_pitch_label".localized, selection: $viewModel.startPitchIndex) {
                        ForEach(0..<viewModel.availablePitches.count, id: \.self) { index in
                            Text(viewModel.availablePitches[index]).tag(index)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(!viewModel.isSettingsEnabled)
                }

                // Tempo
                VStack(alignment: .leading, spacing: 6) {
                    Text("recording.tempo_label".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Text("\(viewModel.tempo)")
                            .font(.callout)
                            .monospacedDigit()
                            .frame(width: 50, alignment: .leading)

                        Slider(value: Binding(
                            get: { Double(viewModel.tempo) },
                            set: { viewModel.tempo = Int($0) }
                        ), in: 60...180, step: 1)

                        Text("recording.tempo_unit".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .disabled(!viewModel.isSettingsEnabled)
                }

                // Ascending count
                VStack(alignment: .leading, spacing: 6) {
                    Text("recording.ascending_count_label".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("recording.ascending_count_label".localized, selection: $viewModel.ascendingCount) {
                        ForEach(1...10, id: \.self) { count in
                            Text("\(count) " + "recording.ascending_count_unit".localized).tag(count)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(!viewModel.isSettingsEnabled)
                }
            }
            .padding(12)
        }
        .background(Color(.systemGray6))
    }
}

struct RecordingSettingsCompact: View {
    @ObservedObject var viewModel: MockRecordingSettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("recording.settings_title".localized)
                .font(.headline)

            HStack {
                Text("recording.scale_label".localized + ":")
                Picker("", selection: $viewModel.scaleType) {
                    Text("recording.scale_five_tone".localized).tag(ScaleType.fiveTone)
                    Text("recording.scale_off".localized).tag(ScaleType.off)
                }
                .pickerStyle(.segmented)
            }

            if viewModel.isSettingsEnabled {
                HStack {
                    Text("recording.start_pitch_label".localized + ":")
                    Picker("", selection: $viewModel.startPitchIndex) {
                        ForEach(0..<viewModel.availablePitches.count, id: \.self) { index in
                            Text(viewModel.availablePitches[index]).tag(index)
                        }
                    }
                    .pickerStyle(.menu)
                }

                VStack(alignment: .leading) {
                    Text("recording.tempo_label".localized + ": \(viewModel.tempo) " + "recording.tempo_unit".localized)
                    Slider(value: Binding(
                        get: { Double(viewModel.tempo) },
                        set: { viewModel.tempo = Int($0) }
                    ), in: 60...180, step: 1)
                }

                HStack {
                    Text("recording.ascending_count_label".localized + ":")
                    Picker("", selection: $viewModel.ascendingCount) {
                        ForEach(1...10, id: \.self) { count in
                            Text("\(count) " + "recording.ascending_count_unit".localized).tag(count)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Real-time Display Area

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

            // Pitch indicator (real implementation)
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

struct MockSpectrogramView: View {
    let isActive: Bool
    @State private var animationPhase: Double = 0

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let columns = 40
                let rows = 15
                let cellWidth = size.width / CGFloat(columns)
                let cellHeight = size.height / CGFloat(rows)

                for col in 0..<columns {
                    for row in 0..<rows {
                        let baseIntensity = isActive ? sin(Double(col) * 0.3 + Double(row) * 0.2 + animationPhase) * 0.5 + 0.5 : 0.1
                        let hue = 0.6 - baseIntensity * 0.6
                        let color = Color(hue: hue, saturation: 0.8, brightness: isActive ? 0.9 : 0.3)

                        let rect = CGRect(
                            x: CGFloat(col) * cellWidth,
                            y: size.height - CGFloat(row + 1) * cellHeight,
                            width: cellWidth,
                            height: cellHeight
                        )
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
            .onAppear {
                if isActive {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        animationPhase = .pi * 2
                    }
                }
            }
        }
        .background(Color.black)
        .cornerRadius(8)
    }
}

/// Frequency spectrum bar chart view
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

struct PitchIndicator: View {
    let isActive: Bool
    let isPlayingRecording: Bool
    let targetPitch: DetectedPitch?
    let detectedPitch: DetectedPitch?
    let pitchAccuracy: PitchAccuracy

    var body: some View {
        VStack(spacing: 10) {
            // Target pitch row
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

            // Detected pitch row
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
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private var accuracyColor: Color {
        switch pitchAccuracy {
        case .accurate: return .green
        case .slightlyOff: return .orange
        case .off: return .red
        case .none: return .gray
        }
    }
}

// MARK: - Recording Controls

struct RecordingControls: View {
    let recordingState: RecordingState
    let hasLastRecording: Bool
    let isPlayingRecording: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    let onCancel: () -> Void
    let onPlayLast: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            switch recordingState {
            case .idle:
                VStack(spacing: 8) {
                    Button(action: onStart) {
                        HStack {
                            Image(systemName: "mic.fill")
                            Text("recording.start_button".localized)
                        }
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .cornerRadius(10)
                    }

                    if hasLastRecording {
                        Button(action: onPlayLast) {
                            HStack {
                                Image(systemName: isPlayingRecording ? "stop.fill" : "play.fill")
                                Text(isPlayingRecording ? "recording.stop_playback_button".localized : "recording.play_last_button".localized)
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(8)
                        }
                    }
                }

            case .countdown:
                VStack(spacing: 8) {
                    Text("recording.countdown_message".localized)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Button(action: onCancel) {
                        Text("cancel".localized)
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.gray)
                            .cornerRadius(8)
                    }
                }

            case .recording:
                Button(action: onStop) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("recording.stop_button".localized)
                    }
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.gray)
                    .cornerRadius(10)
                }
            }
        }
    }
}

// MARK: - Mock ViewModels

enum ScaleType {
    case fiveTone
    case off
}

class MockRecordingSettingsViewModel: ObservableObject {
    @Published var scaleType: ScaleType = .fiveTone
    @Published var startPitchIndex: Int = 12 // C3 (MIDI 48)
    @Published var tempo: Int = 120
    @Published var ascendingCount: Int = 3

    let availablePitches = [
        "C2", "C#2", "D2", "D#2", "E2", "F2", "F#2", "G2", "G#2", "A2", "A#2", "B2",
        "C3", "C#3", "D3", "D#3", "E3", "F3", "F#3", "G3", "G#3", "A3", "A#3", "B3",
        "C4", "C#4", "D4", "D#4", "E4", "F4", "F#4", "G4", "G#4", "A4", "A#4", "B4",
        "C5", "C#5", "D5", "D#5", "E5", "F5", "F#5", "G5", "G#5", "A5", "A#5", "B5",
        "C6"
    ]

    var isSettingsEnabled: Bool {
        scaleType != .off
    }

    /// Generate ScaleSettings from current UI settings
    func generateScaleSettings() -> ScaleSettings? {
        guard scaleType == .fiveTone else {
            return nil // Scale off - no settings
        }

        // Calculate MIDI note number: C2 = 36
        let midiNoteNumber = 36 + startPitchIndex

        // Calculate end note (one octave up) - kept for compatibility but not used
        let endNoteNumber = midiNoteNumber + 12

        // Calculate tempo (convert BPM to seconds per note)
        // At 120 BPM, each quarter note is 0.5 seconds
        let secondsPerNote = 60.0 / Double(tempo)

        do {
            let settings = ScaleSettings(
                startNote: try MIDINote(UInt8(midiNoteNumber)),
                endNote: try MIDINote(UInt8(endNoteNumber)),
                notePattern: .fiveToneScale,
                tempo: try Tempo(secondsPerNote: secondsPerNote),
                ascendingCount: ascendingCount  // Use UI setting
            )
            return settings
        } catch {
            print("Error creating ScaleSettings: \(error)")
            return nil
        }
    }
}

// MARK: - Preview

#if DEBUG
struct RecordingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            RecordingView(
                viewModel: RecordingViewModel(
                    startRecordingUseCase: PreviewMockStartRecordingUseCase(),
                    startRecordingWithScaleUseCase: PreviewMockStartRecordingWithScaleUseCase(),
                    stopRecordingUseCase: PreviewMockStopRecordingUseCase(),
                    audioPlayer: PreviewMockAudioPlayer(),
                    pitchDetector: RealtimePitchDetector(),
                    scalePlayer: PreviewMockScalePlayer()
                )
            )
        }
        .previewInterfaceOrientation(.landscapeLeft)
    }
}

// Mocks for preview
private class PreviewMockScalePlayer: ScalePlayerProtocol {
    var isPlaying: Bool = false
    var currentNoteIndex: Int = 0
    var progress: Double = 0.0
    var currentScaleElement: ScaleElement? = nil

    func loadScale(_ notes: [MIDINote], tempo: Tempo) async throws {}
    func loadScaleElements(_ elements: [ScaleElement], tempo: Tempo) async throws {}
    func play(muted: Bool) async throws {}
    func stop() async {}
}

private class PreviewMockStartRecordingUseCase: StartRecordingUseCaseProtocol {
    func execute() async throws -> RecordingSession {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return RecordingSession(
            recordingURL: URL(fileURLWithPath: "/tmp/preview.m4a"),
            settings: nil,
            startedAt: Date()
        )
    }
}

private class PreviewMockStartRecordingWithScaleUseCase: StartRecordingWithScaleUseCaseProtocol {
    func execute(settings: ScaleSettings) async throws -> RecordingSession {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return RecordingSession(
            recordingURL: URL(fileURLWithPath: "/tmp/preview.m4a"),
            settings: settings,
            startedAt: Date()
        )
    }
}

private class PreviewMockStopRecordingUseCase: StopRecordingUseCaseProtocol {
    func execute() async throws -> StopRecordingResult {
        try await Task.sleep(nanoseconds: 500_000_000)
        return StopRecordingResult(duration: 5.0)
    }
}

private class PreviewMockAudioPlayer: AudioPlayerProtocol {
    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0

    func play(url: URL) async throws {
        isPlaying = true
    }

    func stop() async {
        isPlaying = false
    }
}
#endif
