//
//  ComparisonView.swift
//  PoC
//
//  UI for comparing pitch detection methods
//

import SwiftUI
import AVFoundation

struct ComparisonView: View {
    @StateObject private var viewModel = ComparisonViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection

                recordingControlsSection

                if viewModel.isComparing {
                    loadingSection
                } else if !viewModel.comparisonResults.isEmpty {
                    comparisonResultsSection
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Method Comparison")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 36))
                .foregroundColor(.blue)

            Text("Pitch Detection Methods")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Compare FFT, Autocorrelation, YIN, and Cepstrum")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var recordingControlsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Circle()
                    .fill(viewModel.isRecording ? Color.red : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 12)

                Text(viewModel.isRecording ? "Recording..." : "Ready")
                    .font(.headline)
            }

            Button(action: {
                Task {
                    if viewModel.isRecording {
                        await viewModel.stopRecordingAndCompare()
                    } else {
                        await viewModel.startRecording()
                    }
                }
            }) {
                HStack {
                    Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "record.circle")
                        .font(.title2)
                    Text(viewModel.isRecording ? "Stop & Compare" : "Start Recording")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.isRecording ? Color.red : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(viewModel.isComparing)

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

    private var loadingSection: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Comparing detection methods...")
                .font(.subheadline)

            Text("This may take a few seconds")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 20)
    }

    private var comparisonResultsSection: some View {
        VStack(spacing: 12) {
            Text("Comparison Results")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Summary comparison
            summaryComparisonTable

            // Detailed results for each method
            ForEach(viewModel.comparisonResults.indices, id: \.self) { index in
                let result = viewModel.comparisonResults[index]
                MethodResultCard(
                    result: result,
                    isExpanded: viewModel.expandedMethods.contains(result.method),
                    onToggle: {
                        viewModel.toggleExpanded(result.method)
                    }
                )
            }

            // Best method recommendation
            if let bestMethod = viewModel.bestMethod {
                recommendationCard(method: bestMethod)
            }
        }
    }

    private var summaryComparisonTable: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Text("Method")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fontWeight(.bold)
                Text("Time")
                    .frame(width: 70, alignment: .trailing)
                    .fontWeight(.bold)
                Text("Rate")
                    .frame(width: 70, alignment: .trailing)
                    .fontWeight(.bold)
                Text("Conf")
                    .frame(width: 70, alignment: .trailing)
                    .fontWeight(.bold)
            }
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(Color.blue)

            // Rows
            ForEach(viewModel.comparisonResults.indices, id: \.self) { index in
                let result = viewModel.comparisonResults[index]
                HStack(spacing: 8) {
                    Text(result.method.rawValue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                    Text(String(format: "%.2fs", result.processingTime))
                        .frame(width: 70, alignment: .trailing)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.black)
                    Text(String(format: "%.0f%%", result.detectionRate * 100))
                        .frame(width: 70, alignment: .trailing)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.black)
                    Text(String(format: "%.2f", result.averageConfidence))
                        .frame(width: 70, alignment: .trailing)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.black)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(index % 2 == 0 ? Color.white : Color(white: 0.95))
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.5), lineWidth: 2)
        )
        .shadow(radius: 2)
    }

    private func recommendationCard(method: PitchDetectionMethod) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.title3)
                    .foregroundColor(.yellow)
                Text("Recommended Method")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
            }

            Text(method.rawValue)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.blue)

            Text(method.description)
                .font(.subheadline)
                .foregroundColor(Color(white: 0.3))

            Text(viewModel.getRecommendationReason(method))
                .font(.subheadline)
                .foregroundColor(.black)
                .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.15))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue, lineWidth: 2)
        )
    }
}

// MARK: - Method Result Card

struct MethodResultCard: View {
    let result: PitchComparisonResult
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            Button(action: onToggle) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.method.rawValue)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                        Text(result.method.description)
                            .font(.subheadline)
                            .foregroundColor(Color(white: 0.4))
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.body)
                        .foregroundColor(.blue)
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Quick stats
            HStack(spacing: 12) {
                StatBadge(title: "Speed", value: String(format: "%.2fs", result.processingTime), color: .blue)
                StatBadge(title: "Detection", value: String(format: "%.0f%%", result.detectionRate * 100), color: .green)
                StatBadge(title: "Confidence", value: String(format: "%.2f", result.averageConfidence), color: .orange)
            }

            // Expanded details
            if isExpanded {
                Divider()
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Detailed Statistics")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)

                    DetailRow(label: "Detected Points", value: "\(result.pitchData.count)")
                    DetailRow(label: "Processing Time", value: String(format: "%.3f seconds", result.processingTime))
                    DetailRow(label: "Detection Rate", value: String(format: "%.1f%%", result.detectionRate * 100))
                    DetailRow(label: "Average Confidence", value: String(format: "%.3f", result.averageConfidence))

                    if !result.pitchData.isEmpty {
                        let avgFreq = result.pitchData.reduce(0.0) { $0 + $1.frequency } / Double(result.pitchData.count)
                        DetailRow(label: "Average Frequency", value: String(format: "%.1f Hz", avgFreq))
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct StatBadge: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.black)
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color == .blue ? Color.blue : (color == .green ? Color.green : Color.orange))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.15))
        .cornerRadius(8)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(Color(white: 0.4))
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.black)
        }
    }
}

// MARK: - ViewModel

@MainActor
class ComparisonViewModel: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isComparing = false
    @Published var comparisonResults: [PitchComparisonResult] = []
    @Published var errorMessage: String?
    @Published var expandedMethods: Set<PitchDetectionMethod> = []

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private let detector = MultiMethodPitchDetector()

    var bestMethod: PitchDetectionMethod? {
        guard !comparisonResults.isEmpty else { return nil }

        // Score each method based on multiple factors
        let scored = comparisonResults.map { result -> (PitchDetectionMethod, Double) in
            let speedScore = 1.0 / result.processingTime  // Faster is better
            let detectionScore = result.detectionRate * 2.0  // Higher detection rate is better
            let confidenceScore = result.averageConfidence * 1.5  // Higher confidence is better

            let totalScore = speedScore + detectionScore + confidenceScore
            return (result.method, totalScore)
        }

        return scored.max(by: { $0.1 < $1.1 })?.0
    }

    func startRecording() async {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = "comparison_\(Date().timeIntervalSince1970).m4a"
            recordingURL = documentsPath.appendingPathComponent(fileName)

            guard let url = recordingURL else { return }

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()

            isRecording = true
            errorMessage = nil

        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }

    func stopRecordingAndCompare() async {
        audioRecorder?.stop()
        isRecording = false

        guard let url = recordingURL else { return }

        isComparing = true
        errorMessage = nil

        do {
            comparisonResults = try await detector.compareAll(audioFile: url)
        } catch {
            errorMessage = "Failed to compare: \(error.localizedDescription)"
        }

        isComparing = false
    }

    func toggleExpanded(_ method: PitchDetectionMethod) {
        if expandedMethods.contains(method) {
            expandedMethods.remove(method)
        } else {
            expandedMethods.insert(method)
        }
    }

    func getRecommendationReason(_ method: PitchDetectionMethod) -> String {
        guard let result = comparisonResults.first(where: { $0.method == method }) else {
            return ""
        }

        switch method {
        case .fft:
            return "Best for: Real-time applications, frequency visualization. Fast processing with good accuracy."
        case .autocorrelation:
            return "Best for: Simple implementation, balanced performance. Good for voice pitch detection."
        case .yin:
            return "Best for: High accuracy requirements. Excellent for musical applications despite slower speed."
        case .cepstrum:
            return "Best for: Formant analysis, voice characterization. Useful for detailed voice analysis."
        }
    }
}

extension ComparisonViewModel: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("Recording finished: \(flag)")
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ComparisonView()
    }
}
