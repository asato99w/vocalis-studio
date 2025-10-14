//
//  AudioRecorderViewModel.swift
//  PoC
//
//  ViewModel for audio recording and pitch detection
//

import Foundation
import AVFoundation
import SwiftUI

@MainActor
class AudioRecorderViewModel: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var isRecording: Bool = false
    @Published var isAnalyzing: Bool = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var pitchDataPoints: [PitchData] = []
    @Published var errorMessage: String?
    @Published var isPlaying: Bool = false
    @Published var playbackPosition: TimeInterval = 0
    @Published var currentSpectrum: SpectrumData?
    @Published var allSpectrumData: [SpectrumData] = []

    // MARK: - Private Properties

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var recordingTimer: Timer?
    private let pitchDetector = AudioKitPitchDetector()
    private let spectrumAnalyzer = SpectrumAnalyzer()

    // Audio player
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?

    // MARK: - Audio Session Setup

    private func setupAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
    }

    // MARK: - Recording

    func startRecording() async {
        do {
            try setupAudioSession()

            // Generate recording URL
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
            recordingURL = documentsPath.appendingPathComponent(fileName)

            guard let url = recordingURL else { return }

            // Audio settings
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            // Create recorder
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()

            isRecording = true
            recordingDuration = 0
            pitchDataPoints = []
            errorMessage = nil

            // Start timer for duration tracking
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    self.recordingDuration = self.audioRecorder?.currentTime ?? 0
                }
            }

            print("Recording started: \(url.lastPathComponent)")

        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            print("Recording error: \(error)")
        }
    }

    func stopRecording() async {
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false

        print("Recording stopped")

        // Analyze pitch
        if let url = recordingURL {
            await analyzePitch(url: url)
        }
    }

    // MARK: - Pitch Analysis

    private func analyzePitch(url: URL) async {
        isAnalyzing = true
        errorMessage = nil

        do {
            print("Starting pitch and spectrum analysis...")

            // Run both analyses in parallel
            async let pitchResults = Task.detached {
                try await self.pitchDetector.analyze(audioFile: url)
            }.value

            async let spectrumResults = Task.detached {
                try await self.spectrumAnalyzer.analyze(audioFile: url)
            }.value

            pitchDataPoints = try await pitchResults
            allSpectrumData = try await spectrumResults

            print("Analysis complete: \(pitchDataPoints.count) pitch points, \(allSpectrumData.count) spectrum frames")

            if pitchDataPoints.isEmpty {
                errorMessage = "No pitch detected. Try recording with voice."
            }

        } catch {
            errorMessage = "Failed to analyze: \(error.localizedDescription)"
            print("Analysis error: \(error)")
        }

        isAnalyzing = false
    }

    // MARK: - Playback

    func playRecording() async {
        guard let url = recordingURL, !isPlaying else { return }

        do {
            // Setup audio player
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()

            isPlaying = true
            playbackPosition = 0

            // Start playback
            audioPlayer?.play()

            // Start playback position timer
            playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    self.playbackPosition = self.audioPlayer?.currentTime ?? 0

                    // Update current spectrum
                    if !self.allSpectrumData.isEmpty {
                        self.currentSpectrum = self.spectrumAnalyzer.getSpectrum(
                            at: self.playbackPosition,
                            from: self.allSpectrumData
                        )
                    }

                    // Stop when finished
                    if let player = self.audioPlayer, !player.isPlaying {
                        await self.stopPlayback()
                    }
                }
            }

            print("Playback started")

        } catch {
            errorMessage = "Failed to play recording: \(error.localizedDescription)"
            isPlaying = false
        }
    }

    func stopPlayback() async {
        audioPlayer?.stop()
        playbackTimer?.invalidate()
        playbackTimer = nil
        isPlaying = false
        playbackPosition = 0
        currentSpectrum = nil
        print("Playback stopped")
    }

    // MARK: - Cleanup

    func reset() {
        Task {
            await stopPlayback()
        }
        pitchDataPoints = []
        recordingDuration = 0
        errorMessage = nil
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecorderViewModel: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("Recording finished successfully: \(flag)")
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("Recording encode error: \(String(describing: error))")
        Task { @MainActor in
            self.errorMessage = error?.localizedDescription
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioRecorderViewModel: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("Playback finished successfully: \(flag)")
        Task { @MainActor in
            await self.stopPlayback()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Playback decode error: \(String(describing: error))")
        Task { @MainActor in
            self.errorMessage = error?.localizedDescription
            await self.stopPlayback()
        }
    }
}
