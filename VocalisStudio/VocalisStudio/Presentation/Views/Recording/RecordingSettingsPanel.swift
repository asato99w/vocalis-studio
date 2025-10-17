import SwiftUI
import VocalisDomain

/// Full recording settings panel for landscape layout
struct RecordingSettingsPanel: View {
    @ObservedObject var viewModel: RecordingSettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("recording.settings_title".localized)
                    .font(.headline)
                    .padding(.bottom, 4)

                // Scale selection
                VStack(alignment: .leading, spacing: 6) {
                    Text("recording.scale_label".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("recording.scale_label".localized, selection: $viewModel.scaleType) {
                        Text("recording.scale_five_tone".localized).tag(ScaleType.fiveTone)
                        Text("recording.scale_off".localized).tag(ScaleType.off)
                    }
                    .pickerStyle(.segmented)
                }

                // Start pitch
                VStack(alignment: .leading, spacing: 6) {
                    Text("recording.start_pitch_label".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("recording.start_pitch_label".localized, selection: $viewModel.startPitchIndex) {
                        ForEach(0..<viewModel.availablePitches.count, id: \.self) { index in
                            Text(viewModel.availablePitches[index]).tag(index)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(!viewModel.isSettingsEnabled)
                }

                // Tempo
                VStack(alignment: .leading, spacing: 6) {
                    Text("recording.tempo_label".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Text("\(viewModel.tempo)")
                            .font(.callout)
                            .monospacedDigit()
                            .frame(width: 50, alignment: .leading)

                        Slider(value: Binding(
                            get: { Double(viewModel.tempo) },
                            set: { viewModel.tempo = Int($0) }
                        ), in: 60...180, step: 1)

                        Text("recording.tempo_unit".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .disabled(!viewModel.isSettingsEnabled)
                }

                // Ascending count
                VStack(alignment: .leading, spacing: 6) {
                    Text("recording.ascending_count_label".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("recording.ascending_count_label".localized, selection: $viewModel.ascendingCount) {
                        ForEach(1...10, id: \.self) { count in
                            Text("\(count) " + "recording.ascending_count_unit".localized).tag(count)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(!viewModel.isSettingsEnabled)
                }
            }
            .padding(12)
        }
        .background(Color(.systemGray6))
    }
}

/// Compact recording settings panel for portrait layout
struct RecordingSettingsCompact: View {
    @ObservedObject var viewModel: RecordingSettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("recording.settings_title".localized)
                .font(.headline)

            HStack {
                Text("recording.scale_label".localized + ":")
                Picker("", selection: $viewModel.scaleType) {
                    Text("recording.scale_five_tone".localized).tag(ScaleType.fiveTone)
                    Text("recording.scale_off".localized).tag(ScaleType.off)
                }
                .pickerStyle(.segmented)
            }

            if viewModel.isSettingsEnabled {
                HStack {
                    Text("recording.start_pitch_label".localized + ":")
                    Picker("", selection: $viewModel.startPitchIndex) {
                        ForEach(0..<viewModel.availablePitches.count, id: \.self) { index in
                            Text(viewModel.availablePitches[index]).tag(index)
                        }
                    }
                    .pickerStyle(.menu)
                }

                VStack(alignment: .leading) {
                    Text("recording.tempo_label".localized + ": \(viewModel.tempo) " + "recording.tempo_unit".localized)
                    Slider(value: Binding(
                        get: { Double(viewModel.tempo) },
                        set: { viewModel.tempo = Int($0) }
                    ), in: 60...180, step: 1)
                }

                HStack {
                    Text("recording.ascending_count_label".localized + ":")
                    Picker("", selection: $viewModel.ascendingCount) {
                        ForEach(1...10, id: \.self) { count in
                            Text("\(count) " + "recording.ascending_count_unit".localized).tag(count)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
