import SwiftUI
#if os(iOS)
import AVFoundation
#endif

public struct RecordingView: View {
    @StateObject private var viewModel: RecordingViewModel
    
    public init(viewModel: RecordingViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Recording status
                VStack(spacing: 10) {
                    Image(systemName: viewModel.isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 60))
                        .foregroundColor(viewModel.isRecording ? .red : .gray)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.isRecording)
                    
                    if viewModel.isRecording {
                        Text(formatTime(viewModel.recordingDuration))
                            .font(.title)
                            .fontWeight(.medium)
                    }
                }
                .padding(.top, 40)
                
                // Recording button
                Button(action: {
                    Task {
                        await viewModel.toggleRecording()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(viewModel.isRecording ? Color.red : Color.blue)
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: viewModel.isRecording ? "stop.fill" : "circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                }
                
                // Status text
                Text(viewModel.isRecording ? "recording.status.recording".localized : "recording.status.idle".localized)
                    .font(.title2)
                    .foregroundColor(.primary)
                
                // Error message
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // Recordings list
                if !viewModel.recordings.isEmpty {
                    VStack(alignment: .leading) {
                        Text("recording.history.title".localized)
                            .font(.headline)
                            .padding(.horizontal)
                        
                        List {
                            ForEach(viewModel.recordings, id: \.id.value) { recording in
                                RecordingRowView(recording: recording)
                            }
                            .onDelete { indexSet in
                                Task {
                                    for index in indexSet {
                                        await viewModel.deleteRecording(viewModel.recordings[index])
                                    }
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                        .frame(maxHeight: 300)
                    }
                }
            }
            .navigationTitle("recording.title".localized)
            .onAppear {
                Task {
                    await viewModel.loadRecordings()
                }
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, seconds, milliseconds)
    }
}

struct RecordingRowView: View {
    let recording: Recording
    @State private var isPlaying = false
    private let audioPlayer = AudioPlayer()
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatDate(recording.startTime))
                    .font(.headline)
                
                if let duration = recording.duration {
                    Text("recording.duration.label".localized(with: duration.formatted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: {
                togglePlayback()
            }) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func togglePlayback() {
        if isPlaying {
            audioPlayer.stop()
            isPlaying = false
        } else {
            audioPlayer.play(url: recording.audioFileUrl) {
                isPlaying = false
            }
            isPlaying = true
        }
    }
}

#if os(iOS)
// Simple audio player for playback
class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var completion: (() -> Void)?
    
    func play(url: URL, completion: @escaping () -> Void) {
        self.completion = completion
        
        do {
            // Configure audio session for playback with compatibility for recording
            let audioSession = AVAudioSession.sharedInstance()
            // Use playAndRecord to maintain compatibility with recording session
            try audioSession.setCategory(.playAndRecord, 
                                        mode: .default, 
                                        options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            
            // Check if file exists
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("Audio file does not exist at path: \(url.path)")
                completion()
                return
            }
            
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.volume = 1.0  // Set volume to maximum
            player?.prepareToPlay()
            
            let success = player?.play() ?? false
            if !success {
                print("Failed to start audio playback")
                completion()
            } else {
                print("Audio playback started successfully for: \(url.lastPathComponent)")
            }
        } catch {
            print("Failed to play audio: \(error)")
            print("Error details: \(error.localizedDescription)")
            completion()
        }
    }
    
    func stop() {
        player?.stop()
        player = nil
        completion?()
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        completion?()
    }
}
#else
// macOS用のダミー実装
class AudioPlayer: NSObject {
    private var completion: (() -> Void)?
    
    func play(url: URL, completion: @escaping () -> Void) {
        self.completion = completion
        print("Playing audio: \(url)")
        completion()
    }
    
    func stop() {
        completion?()
    }
}
#endif