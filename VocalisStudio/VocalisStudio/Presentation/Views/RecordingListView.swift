import SwiftUI

/// Recording list screen
public struct RecordingListView: View {
    @StateObject private var viewModel: RecordingListViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: RecordingListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.recordings.isEmpty {
                    emptyState
                } else {
                    recordingList
                }
            }
            .navigationTitle("recording_list_title")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("close") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.loadRecordings()
            }
            .alert(isPresented: .constant(viewModel.errorMessage != nil)) {
                Alert(
                    title: Text("error_title"),
                    message: Text(viewModel.errorMessage ?? ""),
                    dismissButton: .default(Text("ok"))
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("no_recordings")
                .font(.title2)
                .foregroundColor(.gray)

            Text("no_recordings_message")
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

            // Delete button
            Button(action: { showDeleteConfirmation = true }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
        .confirmationDialog(
            "delete_confirmation_title",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("delete", role: .destructive) {
                onDelete()
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("delete_confirmation_message")
        }
    }
}
