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
    @Published public private(set) var currentTime: Double = 0.0
    @Published public private(set) var currentPlaybackPosition: [RecordingId: TimeInterval] = [:]

    private let recordingRepository: RecordingRepositoryProtocol
    private let audioPlayer: AudioPlayerProtocol
    private var positionTrackingTask: Task<Void, Never>?

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

            // Start playback without waiting for completion
            Task {
                do {
                    try await audioPlayer.play(url: recording.fileURL)
                    // Playback finished naturally
                    await MainActor.run {
                        if playingRecordingId == recording.id {
                            playingRecordingId = nil
                            stopPositionTracking()
                            // Reset position to beginning
                            currentPlaybackPosition[recording.id] = 0.0
                            currentTime = 0.0
                        }
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        if playingRecordingId == recording.id {
                            playingRecordingId = nil
                            stopPositionTracking()
                            // Reset position to beginning on error too
                            currentPlaybackPosition[recording.id] = 0.0
                            currentTime = 0.0
                        }
                    }
                }
            }
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

    /// Start position tracking
    public func startPositionTracking() async {
        stopPositionTracking()

        positionTrackingTask = Task { @MainActor in
            while !Task.isCancelled {
                if let recordingId = playingRecordingId {
                    let position = await audioPlayer.currentTime
                    currentTime = position
                    currentPlaybackPosition[recordingId] = position
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms update interval
            }
        }
    }

    /// Stop position tracking
    public func stopPositionTracking() {
        positionTrackingTask?.cancel()
        positionTrackingTask = nil
    }

    /// Seek to a specific position
    public func seekToPosition(_ time: Double) async {
        await audioPlayer.seek(to: time)
        currentTime = time
    }

    /// Seek to a specific position for a specific recording
    public func seek(to position: TimeInterval, for recordingId: RecordingId) async {
        guard playingRecordingId == recordingId else { return }
        await audioPlayer.seek(to: position)
        currentPlaybackPosition[recordingId] = position
        currentTime = position
    }
}
