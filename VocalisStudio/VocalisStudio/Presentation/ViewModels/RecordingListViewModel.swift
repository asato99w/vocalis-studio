import Foundation
import VocalisDomain
import Combine

/// ViewModel for recording list screen
@MainActor
public class RecordingListViewModel: ObservableObject {
    @Published public private(set) var recordings: [Recording] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var playingRecordingId: RecordingId?

    private let recordingRepository: RecordingRepositoryProtocol
    private let audioPlayer: AudioPlayerProtocol

    public init(
        recordingRepository: RecordingRepositoryProtocol,
        audioPlayer: AudioPlayerProtocol
    ) {
        self.recordingRepository = recordingRepository
        self.audioPlayer = audioPlayer
    }

    /// Load all recordings
    public func loadRecordings() async {
        isLoading = true
        errorMessage = nil

        do {
            recordings = try await recordingRepository.findAll()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Play a recording
    public func playRecording(_ recording: Recording) async {
        // If this recording is already playing, stop it
        if playingRecordingId == recording.id {
            await stopPlayback()
            return
        }

        // If another recording is playing, stop it first
        if playingRecordingId != nil {
            await stopPlayback()
        }

        do {
            playingRecordingId = recording.id
            try await audioPlayer.play(url: recording.fileURL)

            // Wait for playback to complete
            while audioPlayer.isPlaying {
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }

            playingRecordingId = nil
        } catch {
            errorMessage = error.localizedDescription
            playingRecordingId = nil
        }
    }

    /// Stop playback
    public func stopPlayback() async {
        await audioPlayer.stop()
        playingRecordingId = nil
    }

    /// Delete a recording
    public func deleteRecording(_ recording: Recording) async {
        do {
            // Stop playback if this recording is playing
            if playingRecordingId == recording.id {
                await stopPlayback()
            }

            try await recordingRepository.delete(recording.id)

            // Reload recordings
            await loadRecordings()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
