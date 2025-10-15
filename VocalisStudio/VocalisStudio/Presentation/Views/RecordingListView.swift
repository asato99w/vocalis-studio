import SwiftUI
import VocalisDomain

/// Recording list screen
public struct RecordingListView: View {
    @StateObject private var viewModel: RecordingListViewModel
    @StateObject private var localization = LocalizationManager.shared

    public init(viewModel: RecordingListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
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
                .foregroundColor(.gray)

            Text("list.empty_title".localized)
                .font(.title2)
                .foregroundColor(.gray)

            Text("list.empty_message".localized)
                .font(.body)
                .foregroundColor(.secondary)
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
                    onTap: {
                        Task {
                            await viewModel.playRecording(recording)
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
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 16) {
            // Play button
            Button(action: onTap) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(isPlaying ? .red : .blue)
            }
            .buttonStyle(PlainButtonStyle())

            // Recording info
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.formattedDate)
                    .font(.headline)

                Text(recording.duration.formatted)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Analysis button
            NavigationLink(destination: AnalysisView(recording: recording)) {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(.blue)
                    .font(.title3)
            }
            .buttonStyle(PlainButtonStyle())

            // Delete button
            Button(action: { showDeleteConfirmation = true }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.title3)
            }
            .buttonStyle(PlainButtonStyle())
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
            Button("cancel".localized, role: .cancel) {}
        } message: {
            Text("list.delete_confirmation_message".localized)
        }
    }
}
