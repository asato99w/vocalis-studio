import SwiftUI
import VocalisDomain
import OSLog

/// Recording control buttons (start, stop, cancel, play last)
struct RecordingControls: View {
    let recordingState: RecordingState
    let hasLastRecording: Bool
    let isPlayingRecording: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    let onCancel: () -> Void
    let onPlayLast: () -> Void

    // Logger for diagnostic purposes
    private static let logger = Logger(subsystem: "com.kazuasato.VocalisStudio", category: "RecordingControls")

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
            Button(action: {
                Self.logger.error("UI_TEST_MARK: StartRecordingButton action called")
                onStart()
            }) {
                HStack {
                    Image(systemName: "mic.fill")
                    Text("recording.start_button".localized)
                }
            }
            .buttonStyle(AlertButtonStyle())
            .accessibilityIdentifier("StartRecordingButton")

            if hasLastRecording {
                if isPlayingRecording {
                    // Separate button for stopping playback with fixed ID
                    Button(action: {
                        Self.logger.error("UI_TEST_MARK: StopPlaybackButton action called")
                        Self.logger.logToFile(level: "ERROR", message: "UI_TEST_MARK: StopPlaybackButton action called")
                        onPlayLast()
                    }) {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text("recording.stop_playback_button".localized)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("StopPlaybackButton")
                } else {
                    // Separate button for playing last recording with fixed ID
                    Button(action: {
                        Self.logger.error("UI_TEST_MARK: PlayLastRecordingButton action called")
                        Self.logger.logToFile(level: "ERROR", message: "UI_TEST_MARK: PlayLastRecordingButton action called")
                        onPlayLast()
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("recording.play_last_button".localized)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("PlayLastRecordingButton")
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
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    // MARK: - Recording State Controls

    private var recordingControls: some View {
        Button(action: onStop) {
            HStack {
                Image(systemName: "stop.fill")
                Text("recording.stop_button".localized)
            }
        }
        .buttonStyle(SecondaryButtonStyle())
        .accessibilityIdentifier("StopRecordingButton")
    }
}
