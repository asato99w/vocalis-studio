import SwiftUI
import VocalisDomain

/// Recording list screen
public struct RecordingListView: View {
    @StateObject private var viewModel: RecordingListViewModel
    @StateObject private var localization = LocalizationManager.shared

    private let audioPlayer: AudioPlayerProtocol
    private let analyzeRecordingUseCase: AnalyzeRecordingUseCase

    public init(
        viewModel: RecordingListViewModel,
        audioPlayer: AudioPlayerProtocol,
        analyzeRecordingUseCase: AnalyzeRecordingUseCase
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.audioPlayer = audioPlayer
        self.analyzeRecordingUseCase = analyzeRecordingUseCase
    }

    public var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.recordings.isEmpty {
                emptyState
            } else {
                recordingList
            }
        }
        .navigationTitle("list.title".localized)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadRecordings()
        }
        .alert(isPresented: .constant(viewModel.errorMessage != nil)) {
            Alert(
                title: Text("error".localized),
                message: Text(viewModel.errorMessage ?? ""),
                dismissButton: .default(Text("ok".localized))
            )
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.slash")
                .font(.system(size: 60))
                .foregroundColor(ColorPalette.text.opacity(0.5))

            Text("list.empty_title".localized)
                .font(.title2)
                .foregroundColor(ColorPalette.text)

            Text("list.empty_message".localized)
                .font(.body)
                .foregroundColor(ColorPalette.text.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    // MARK: - Recording List

    private var recordingList: some View {
        List {
            ForEach(viewModel.recordings) { recording in
                RecordingRow(
                    recording: recording,
                    isPlaying: viewModel.playingRecordingId == recording.id,
                    currentTime: viewModel.currentTime,
                    audioPlayer: audioPlayer,
                    analyzeRecordingUseCase: analyzeRecordingUseCase,
                    onTap: {
                        Task {
                            await viewModel.playRecording(recording)
                            if viewModel.playingRecordingId == recording.id {
                                await viewModel.startPositionTracking()
                            } else {
                                await viewModel.stopPositionTracking()
                            }
                        }
                    },
                    onSeek: { time in
                        Task {
                            await viewModel.seekToPosition(time)
                        }
                    },
                    onDelete: {
                        Task {
                            await viewModel.deleteRecording(recording)
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Recording Row

private struct RecordingRow: View {
    let recording: Recording
    let isPlaying: Bool
    let currentTime: Double
    let audioPlayer: AudioPlayerProtocol
    let analyzeRecordingUseCase: AnalyzeRecordingUseCase
    let onTap: () -> Void
    let onSeek: (Double) -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 16) {
            // Play button
            Button(action: onTap) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(isPlaying ? ColorPalette.alertActive : ColorPalette.primary)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(isPlaying ? "stop.circle.fill" : "play.circle.fill")

            // Recording info
            VStack(alignment: .leading, spacing: 8) {
                // Date and scale info
                VStack(alignment: .leading, spacing: 4) {
                    Text(recording.formattedDate)
                        .font(.headline)
                        .foregroundColor(ColorPalette.text)

                    if let scaleDisplayName = recording.scaleDisplayName {
                        Text(scaleDisplayName)
                            .font(.subheadline)
                            .foregroundColor(ColorPalette.text.opacity(0.6))
                    }
                }

                // Position slider (only shown when playing)
                if isPlaying {
                    VStack(spacing: 4) {
                        Slider(
                            value: Binding(
                                get: { currentTime },
                                set: { newValue in onSeek(newValue) }
                            ),
                            in: 0...recording.duration.seconds
                        )
                        .accentColor(ColorPalette.primary)

                        HStack {
                            Text(formatTime(currentTime))
                                .font(.caption)
                                .foregroundColor(ColorPalette.text.opacity(0.5))
                            Spacer()
                            Text(formatTime(recording.duration.seconds))
                                .font(.caption)
                                .foregroundColor(ColorPalette.text.opacity(0.5))
                        }
                    }
                }
            }

            Spacer()

            // Analysis button
            NavigationLink(destination: AnalysisView(
                recording: recording,
                audioPlayer: audioPlayer,
                analyzeRecordingUseCase: analyzeRecordingUseCase
            )) {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(ColorPalette.accent)
                    .font(.title3)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityIdentifier("AnalysisNavigationLink_\(recording.id.value.uuidString)")

            // Delete button
            Button(action: { showDeleteConfirmation = true }) {
                Image(systemName: "trash")
                    .foregroundColor(ColorPalette.alertActive)
                    .font(.title3)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityIdentifier("DeleteRecordingButton_\(recording.id.value.uuidString)")
        }
        .padding(.vertical, 8)
        .confirmationDialog(
            "list.delete_confirmation_title".localized,
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("delete".localized, role: .destructive) {
                onDelete()
            }
            .accessibilityIdentifier("DeleteConfirmButton")

            Button("cancel".localized, role: .cancel) {}
                .accessibilityIdentifier("DeleteCancelButton")
        } message: {
            Text("list.delete_confirmation_message".localized)
        }
    }

    /// Format time in seconds to MM:SS format
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
