import SwiftUI
import VocalisDomain

/// Main recording screen view with settings panel and real-time visualization
public struct RecordingView: View {
    @StateObject private var viewModel: RecordingViewModel
    @StateObject private var settingsViewModel = MockRecordingSettingsViewModel()
    @StateObject private var localization = LocalizationManager.shared
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

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
    }

    // MARK: - Landscape Layout

    private var landscapeLayout: some View {
        HStack(spacing: 0) {
            // Left side: Settings panel
            RecordingSettingsPanel(viewModel: settingsViewModel)
                .frame(width: 240)

            Divider()

            // Right side: Real-time display and controls
            VStack(spacing: 8) {
                RealtimeDisplayArea(
                    recordingState: viewModel.recordingState
                )
                .frame(maxHeight: .infinity)

                RecordingControls(
                    recordingState: viewModel.recordingState,
                    hasLastRecording: viewModel.lastRecordingURL != nil,
                    isPlayingRecording: viewModel.isPlayingRecording,
                    onStart: {
                        Task {
                            let settings = settingsViewModel.generateScaleSettings()
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
                RecordingSettingsCompact(viewModel: settingsViewModel)

                RealtimeDisplayArea(
                    recordingState: viewModel.recordingState
                )
                .frame(height: 200)

                RecordingControls(
                    recordingState: viewModel.recordingState,
                    hasLastRecording: viewModel.lastRecordingURL != nil,
                    isPlayingRecording: viewModel.isPlayingRecording,
                    onStart: {
                        Task {
                            let settings = settingsViewModel.generateScaleSettings()
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

    var body: some View {
        VStack(spacing: 12) {
            // Spectrogram
            VStack(alignment: .leading, spacing: 6) {
                Text("recording.realtime_spectrum_title".localized)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                MockSpectrogramView(isActive: recordingState == .recording)
                    .frame(maxHeight: .infinity)
            }

            Divider()

            // Pitch indicator
            VStack(alignment: .leading, spacing: 6) {
                Text("recording.pitch_indicator_title".localized)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                MockPitchIndicator(isActive: recordingState == .recording)
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

struct MockPitchIndicator: View {
    let isActive: Bool
    @State private var currentNote = "C4"
    @State private var cents = 0

    var body: some View {
        VStack(spacing: 8) {
            // Target scale
            HStack(spacing: 6) {
                Text("recording.pitch_target".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach([
                    "scale.note_do".localized,
                    "scale.note_re".localized,
                    "scale.note_mi".localized,
                    "scale.note_fa".localized,
                    "scale.note_so".localized
                ], id: \.self) { note in
                    Text(note)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(3)
                }
            }

            // Detected pitch
            HStack(spacing: 8) {
                Text("recording.pitch_detected".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if isActive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(centsColor)
                            .frame(width: 10, height: 10)

                        Text(currentNote)
                            .font(.callout)
                            .fontWeight(.bold)

                        Text(cents >= 0 ? "+\(cents)¢" : "\(cents)¢")
                            .font(.caption)
                            .foregroundColor(centsColor)
                    }
                } else {
                    Text("--")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(6)
        .onAppear {
            if isActive {
                // Simulate pitch detection
                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                    cents = Int.random(in: -30...30)
                }
            }
        }
    }

    private var centsColor: Color {
        if abs(cents) < 10 {
            return .green
        } else if abs(cents) < 25 {
            return .orange
        } else {
            return .red
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
                    stopRecordingUseCase: PreviewMockStopRecordingUseCase(),
                    audioPlayer: PreviewMockAudioPlayer()
                )
            )
        }
        .previewInterfaceOrientation(.landscapeLeft)
    }
}

// Mocks for preview
private class PreviewMockStartRecordingUseCase: StartRecordingWithScaleUseCaseProtocol {
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

    func play(url: URL) async throws {
        isPlaying = true
    }

    func stop() async {
        isPlaying = false
    }
}
#endif
