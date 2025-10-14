//
//  ContentView.swift
//  PoC
//
//  Pitch Detection PoC - Main View
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AudioRecorderViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Recording Controls
                    recordingControlsSection

                    // Pitch Graph
                    if !viewModel.pitchDataPoints.isEmpty {
                        pitchGraphSection
                    }

                    // Spectrum Graph (shown during playback)
                    if viewModel.isPlaying || viewModel.currentSpectrum != nil {
                        spectrumGraphSection
                    }

                    // Detected Pitches List
                    if !viewModel.pitchDataPoints.isEmpty {
                        pitchListSection
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Pitch Detection PoC")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Voice Pitch Analyzer")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Record your voice and analyze pitch")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top)
    }

    private var recordingControlsSection: some View {
        VStack(spacing: 16) {
            // Recording Status
            HStack {
                Circle()
                    .fill(viewModel.isRecording ? Color.red : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 12)

                Text(viewModel.isRecording ? "Recording..." : "Ready")
                    .font(.headline)

                if viewModel.isRecording {
                    Text(String(format: "%.1fs", viewModel.recordingDuration))
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }

            // Record Button
            Button(action: {
                Task {
                    if viewModel.isRecording {
                        await viewModel.stopRecording()
                    } else {
                        await viewModel.startRecording()
                    }
                }
            }) {
                HStack {
                    Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "record.circle")
                        .font(.title2)
                    Text(viewModel.isRecording ? "Stop Recording" : "Start Recording")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.isRecording ? Color.red : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(viewModel.isAnalyzing)

            // Reset Button
            if !viewModel.pitchDataPoints.isEmpty {
                Button(action: {
                    viewModel.reset()
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
            }

            // Analyzing Indicator
            if viewModel.isAnalyzing {
                HStack {
                    ProgressView()
                    Text("Analyzing pitch...")
                        .foregroundColor(.secondary)
                }
            }

            // Error Message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(16)
    }

    private var pitchGraphSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            PitchGraphView(
                pitchData: viewModel.pitchDataPoints,
                duration: viewModel.recordingDuration,
                playbackPosition: viewModel.isPlaying ? viewModel.playbackPosition : nil
            )

            // Playback controls
            HStack(spacing: 16) {
                Button(action: {
                    Task {
                        if viewModel.isPlaying {
                            await viewModel.stopPlayback()
                        } else {
                            await viewModel.playRecording()
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                        Text(viewModel.isPlaying ? "Stop" : "Play Recording")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.isPlaying ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }

                if viewModel.isPlaying {
                    Text(String(format: "%.1fs / %.1fs", viewModel.playbackPosition, viewModel.recordingDuration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private var spectrumGraphSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SpectrumGraphView(spectrumData: viewModel.currentSpectrum)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private var pitchListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detected Pitches")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(viewModel.pitchDataPoints.prefix(20).enumerated()), id: \.offset) { index, data in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(data.noteName)
                                .font(.headline)
                            Text("\(Int(data.frequency)) Hz")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1fs", data.timestamp))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }

            if viewModel.pitchDataPoints.count > 20 {
                Text("Showing first 20 of \(viewModel.pitchDataPoints.count) points")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(16)
    }
}

#Preview {
    ContentView()
}
