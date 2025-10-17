import SwiftUI
import VocalisDomain

/// Recording control buttons (start, stop, cancel, play last)
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
                idleControls

            case .countdown:
                countdownControls

            case .recording:
                recordingControls
            }
        }
    }

    // MARK: - Idle State Controls

    private var idleControls: some View {
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
    }

    // MARK: - Countdown State Controls

    private var countdownControls: some View {
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
    }

    // MARK: - Recording State Controls

    private var recordingControls: some View {
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
