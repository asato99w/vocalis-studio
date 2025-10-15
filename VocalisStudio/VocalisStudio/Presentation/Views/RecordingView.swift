import SwiftUI
import VocalisDomain

/// Main recording screen view
public struct RecordingView: View {
    @StateObject private var viewModel: RecordingViewModel
    @State private var showRecordingList = false

    public init(viewModel: RecordingViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Status Display
                statusView

                Spacer()

                // Control Buttons
                controlButtons

                Spacer()
            }
            .padding()

            // Recording List Button (top-right)
            VStack {
                HStack {
                    Spacer()
                    Button {
                        showRecordingList = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.gray.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .sheet(isPresented: $showRecordingList) {
            RecordingListView(
                viewModel: RecordingListViewModel(
                    recordingRepository: DependencyContainer.shared.recordingRepository,
                    audioPlayer: DependencyContainer.shared.audioPlayer
                )
            )
        }
        .alert(isPresented: .constant(viewModel.errorMessage != nil)) {
            Alert(
                title: Text("recording_error_title"),
                message: Text(viewModel.errorMessage ?? ""),
                dismissButton: .default(Text("ok"))
            )
        }
    }

    // MARK: - Status View

    @ViewBuilder
    private var statusView: some View {
        switch viewModel.recordingState {
        case .idle:
            Text("ready_to_record")
                .font(.title)
                .foregroundColor(.white)

        case .countdown:
            VStack(spacing: 20) {
                Text("countdown_message")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))

                Text("\(viewModel.countdownValue)")
                    .font(.system(size: 120, weight: .bold))
                    .foregroundColor(.white)
            }

        case .recording:
            VStack(spacing: 20) {
                // Recording indicator
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 20, height: 20)
                        .opacity(recordingPulse ? 0.3 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                            value: recordingPulse
                        )
                        .onAppear { recordingPulse.toggle() }

                    Text("recording_in_progress")
                        .font(.title2)
                        .foregroundColor(.white)
                }

                // Progress bar
                if viewModel.progress > 0 {
                    ProgressView(value: viewModel.progress)
                        .progressViewStyle(.linear)
                        .tint(.white)
                        .frame(maxWidth: 300)
                }
            }
        }
    }

    @State private var recordingPulse = false

    // MARK: - Control Buttons

    @ViewBuilder
    private var controlButtons: some View {
        switch viewModel.recordingState {
        case .idle:
            VStack(spacing: 20) {
                Button {
                    Task {
                        await viewModel.startRecording()
                    }
                } label: {
                    HStack {
                        Image(systemName: "mic.fill")
                        Text("start_recording")
                    }
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 20)
                    .background(Color.red)
                    .cornerRadius(12)
                }

                // Play last recording button
                if viewModel.lastRecordingURL != nil {
                    Button {
                        Task {
                            if viewModel.isPlayingRecording {
                                await viewModel.stopPlayback()
                            } else {
                                await viewModel.playLastRecording()
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: viewModel.isPlayingRecording ? "stop.fill" : "play.fill")
                            Text(viewModel.isPlayingRecording ? "stop_playback" : "play_recording")
                        }
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 15)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                }
            }

        case .countdown:
            Button {
                Task {
                    await viewModel.cancelCountdown()
                }
            } label: {
                Text("cancel")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(Color.gray)
                    .cornerRadius(12)
            }

        case .recording:
            Button {
                Task {
                    await viewModel.stopRecording()
                }
            } label: {
                HStack {
                    Image(systemName: "stop.fill")
                    Text("stop_recording")
                }
                .font(.title2)
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
                .background(Color.gray)
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct RecordingView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview requires mock use cases
        RecordingView(
            viewModel: RecordingViewModel(
                startRecordingUseCase: PreviewMockStartRecordingUseCase(),
                stopRecordingUseCase: PreviewMockStopRecordingUseCase(),
                audioPlayer: PreviewMockAudioPlayer()
            )
        )
    }
}

// Mocks for preview
private class PreviewMockStartRecordingUseCase: StartRecordingWithScaleUseCaseProtocol {
    func execute(settings: ScaleSettings) async throws -> RecordingSession {
        // Simulate delay
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
        // Simulate delay
        try await Task.sleep(nanoseconds: 500_000_000)

        return StopRecordingResult(duration: 5.0)
    }
}

private class PreviewMockAudioPlayer: AudioPlayerProtocol {
    var isPlaying: Bool = false

    func play(url: URL) async throws {
        // Simulate playback
    }

    func stop() async {
        // Simulate stop
    }
}
#endif
