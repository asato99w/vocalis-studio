import SwiftUI
import VocalisDomain

/// Recording list screen
public struct RecordingListView: View {
    @StateObject private var viewModel: RecordingListViewModel
    @StateObject private var localization = LocalizationManager.shared
    @State private var selectedRecording: Recording?

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
        VStack(spacing: 0) {
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.recordings.isEmpty {
                emptyState
            } else {
                recordingList
            }

            // Fixed bottom playback control panel
            if !viewModel.recordings.isEmpty {
                PlaybackControlPanel(viewModel: viewModel)
            }
        }
        .navigationTitle("list.title".localized)
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(item: $selectedRecording) { recording in
            AnalysisView(
                recording: recording,
                audioPlayer: audioPlayer,
                analyzeRecordingUseCase: analyzeRecordingUseCase
            )
        }
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
                    isSelected: viewModel.selectedRecording?.id == recording.id,
                    isPlaying: viewModel.playingRecordingId == recording.id,
                    selectedRecording: $selectedRecording,
                    onTap: {
                        Task {
                            await viewModel.selectAndPlay(recording)
                        }
                    },
                    onAnalyze: {
                        selectedRecording = recording
                    }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task {
                            await viewModel.deleteRecording(recording)
                        }
                    } label: {
                        Label("delete".localized, systemImage: "trash")
                    }
                    .accessibilityIdentifier("DeleteRecordingButton_\(recording.id.value.uuidString)")
                }
            }
        }
    }
}

// MARK: - Recording Row

private struct RecordingRow: View {
    let recording: Recording
    let isSelected: Bool
    let isPlaying: Bool
    @Binding var selectedRecording: Recording?
    let onTap: () -> Void
    let onAnalyze: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Selection indicator bar
            Rectangle()
                .fill(isSelected ? ColorPalette.primary : Color.clear)
                .frame(width: 4)

            // Main content
            VStack(alignment: .leading, spacing: 8) {
                // Scale name (primary info)
                if let scaleDisplayName = recording.scaleDisplayName {
                    Text(scaleDisplayName)
                        .font(.headline)
                        .foregroundColor(ColorPalette.text)
                } else {
                    Text("recording.title".localized)
                        .font(.headline)
                        .foregroundColor(ColorPalette.text)
                }

                // Date and duration on same line
                HStack {
                    Text(recording.formattedDate)
                        .font(.caption)
                        .foregroundColor(ColorPalette.text.opacity(0.6))

                    Text("•")
                        .font(.caption)
                        .foregroundColor(ColorPalette.text.opacity(0.4))

                    Text(formatTime(recording.duration.seconds))
                        .font(.caption)
                        .foregroundColor(ColorPalette.text.opacity(0.6))

                    Spacer()

                    // Analysis button (subtle, right-aligned)
                    Button(action: onAnalyze) {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundColor(ColorPalette.accent.opacity(0.8))
                            .font(.subheadline)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityIdentifier("AnalysisNavigationLink_\(recording.id.value.uuidString)")
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? ColorPalette.primary.opacity(0.05) : ColorPalette.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? ColorPalette.primary.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .accessibilityIdentifier("RecordingRow_\(recording.id.value.uuidString)")
    }

    /// Format time in seconds to MM:SS format
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
