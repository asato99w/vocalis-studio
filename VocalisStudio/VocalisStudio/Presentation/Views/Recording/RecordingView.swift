import SwiftUI
import SubscriptionDomain
import VocalisDomain
import SubscriptionDomain

/// Main recording screen view with settings panel and real-time visualization
public struct RecordingView: View {
    @StateObject private var viewModel: RecordingViewModel
    @StateObject private var settingsViewModel = RecordingSettingsViewModel()
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
                    ),
                    audioPlayer: DependencyContainer.shared.audioPlayer,
                    analyzeRecordingUseCase: DependencyContainer.shared.analyzeRecordingUseCase
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
                settingsToggleButton

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
                    onStart: startRecording,
                    onStop: stopRecording,
                    onCancel: cancelCountdown,
                    onPlayLast: togglePlayback
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
                    onStart: startRecording,
                    onStop: stopRecording,
                    onCancel: cancelCountdown,
                    onPlayLast: togglePlayback
                )
            }
            .padding()
        }
    }

    // MARK: - Settings Toggle Button

    private var settingsToggleButton: some View {
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
    }

    // MARK: - Action Handlers

    private func startRecording() {
        Task {
            let settings = settingsViewModel.generateScaleSettings()
            await viewModel.startRecording(settings: settings)
        }
    }

    private func stopRecording() {
        Task {
            await viewModel.stopRecording()
        }
    }

    private func cancelCountdown() {
        Task {
            await viewModel.cancelCountdown()
        }
    }

    private func togglePlayback() {
        Task {
            if viewModel.isPlayingRecording {
                await viewModel.stopPlayback()
            } else {
                await viewModel.playLastRecording()
            }
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
                    scalePlayer: PreviewMockScalePlayer(),
                    subscriptionViewModel: SubscriptionViewModel(
                        getStatusUseCase: PreviewMockGetStatusUseCase(),
                        purchaseUseCase: PreviewMockPurchaseUseCase(),
                        restoreUseCase: PreviewMockRestoreUseCase()
                    )
                )
            )
        }
        .previewInterfaceOrientation(.landscapeLeft)
    }
}

// MARK: - Preview Mocks

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
    func execute(user: User) async throws -> RecordingSession {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return RecordingSession(
            recordingURL: URL(fileURLWithPath: "/tmp/preview.m4a"),
            settings: nil,
            startedAt: Date()
        )
    }
}

private class PreviewMockStartRecordingWithScaleUseCase: StartRecordingWithScaleUseCaseProtocol {
    func execute(user: User, settings: ScaleSettings) async throws -> RecordingSession {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return RecordingSession(
            recordingURL: URL(fileURLWithPath: "/tmp/preview.m4a"),
            settings: settings,
            startedAt: Date()
        )
    }
}

private class PreviewMockStopRecordingUseCase: StopRecordingUseCaseProtocol {
    func setRecordingContext(url: URL, settings: ScaleSettings?) {
        // Preview mock doesn't need to track context
    }

    func execute() async throws -> StopRecordingResult {
        try await Task.sleep(nanoseconds: 500_000_000)
        return StopRecordingResult(duration: 5.0)
    }
}

private class PreviewMockAudioPlayer: AudioPlayerProtocol {
    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0
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

private class PreviewMockGetStatusUseCase: GetSubscriptionStatusUseCaseProtocol {
    func execute() async throws -> SubscriptionStatus {
        return SubscriptionStatus(tier: .free, cohort: .v2_0)
    }
}

private class PreviewMockPurchaseUseCase: PurchaseSubscriptionUseCaseProtocol {
    func execute(tier: SubscriptionTier) async throws {
        // Mock implementation for preview
    }
}

private class PreviewMockRestoreUseCase: RestorePurchasesUseCaseProtocol {
    func execute() async throws {
        // Mock implementation for preview
    }
}
#endif
