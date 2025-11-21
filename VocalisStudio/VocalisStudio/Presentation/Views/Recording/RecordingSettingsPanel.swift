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
                        .foregroundColor(ColorPalette.text.opacity(0.6))

                    Picker("recording.scale_label".localized, selection: $viewModel.scaleType) {
                        Text("recording.scale_five_tone".localized).tag(ScaleType.fiveTone)
                        Text("recording.scale_octave_repeat".localized).tag(ScaleType.octaveRepeat)
                        Text("recording.scale_off".localized).tag(ScaleType.off)
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("ScaleTypePicker")
                }

                // Start pitch
                VStack(alignment: .leading, spacing: 6) {
                    Text("recording.start_pitch_label".localized)
                        .font(.caption)
                        .foregroundColor(ColorPalette.text.opacity(0.6))

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
                        .foregroundColor(ColorPalette.text.opacity(0.6))

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
                            .foregroundColor(ColorPalette.text.opacity(0.6))
                    }
                    .disabled(!viewModel.isSettingsEnabled)
                }

                // Key progression pattern
                VStack(alignment: .leading, spacing: 6) {
                    Text("recording.pattern_label".localized)
                        .font(.caption)
                        .foregroundColor(ColorPalette.text.opacity(0.6))

                    Picker("recording.pattern_label".localized, selection: $viewModel.keyProgressionPattern) {
                        Text("recording.pattern_ascending_only".localized).tag(KeyProgressionPattern.ascendingOnly)
                        Text("recording.pattern_descending_only".localized).tag(KeyProgressionPattern.descendingOnly)
                        Text("recording.pattern_ascending_then_descending".localized).tag(KeyProgressionPattern.ascendingThenDescending)
                        Text("recording.pattern_descending_then_ascending".localized).tag(KeyProgressionPattern.descendingThenAscending)
                    }
                    .pickerStyle(.menu)
                    .disabled(!viewModel.isSettingsEnabled)
                    .accessibilityIdentifier("KeyProgressionPatternPicker")
                }

                // Ascending key count
                if viewModel.showsAscendingKeyCount {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("recording.key_ascending_count".localized)
                            .font(.caption)
                            .foregroundColor(ColorPalette.text.opacity(0.6))

                        Picker("recording.key_ascending_count".localized, selection: $viewModel.ascendingKeyCount) {
                            ForEach(1...12, id: \.self) { count in
                                Text("\(count) " + "recording.key_count_unit".localized).tag(count)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(!viewModel.isSettingsEnabled)
                        .accessibilityIdentifier("AscendingKeyCountPicker")
                    }
                }

                // Descending key count
                if viewModel.showsDescendingKeyCount {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("recording.key_descending_count".localized)
                            .font(.caption)
                            .foregroundColor(ColorPalette.text.opacity(0.6))

                        Picker("recording.key_descending_count".localized, selection: $viewModel.descendingKeyCount) {
                            ForEach(1...12, id: \.self) { count in
                                Text("\(count) " + "recording.key_count_unit".localized).tag(count)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(!viewModel.isSettingsEnabled)
                        .accessibilityIdentifier("DescendingKeyCountPicker")
                    }
                }
            }
            .padding(12)
        }
        .background(ColorPalette.secondary)
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
                    Text("recording.scale_octave_repeat".localized).tag(ScaleType.octaveRepeat)
                    Text("recording.scale_off".localized).tag(ScaleType.off)
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("ScaleTypePicker")
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
                    Text("recording.pattern_label".localized + ":")
                    Picker("", selection: $viewModel.keyProgressionPattern) {
                        Text("recording.pattern_ascending_only".localized).tag(KeyProgressionPattern.ascendingOnly)
                        Text("recording.pattern_descending_only".localized).tag(KeyProgressionPattern.descendingOnly)
                        Text("recording.pattern_ascending_then_descending".localized).tag(KeyProgressionPattern.ascendingThenDescending)
                        Text("recording.pattern_descending_then_ascending".localized).tag(KeyProgressionPattern.descendingThenAscending)
                    }
                    .pickerStyle(.menu)
                }

                if viewModel.showsAscendingKeyCount {
                    HStack {
                        Text("recording.key_ascending_count".localized + ":")
                        Picker("", selection: $viewModel.ascendingKeyCount) {
                            ForEach(1...12, id: \.self) { count in
                                Text("\(count) " + "recording.key_count_unit".localized).tag(count)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                if viewModel.showsDescendingKeyCount {
                    HStack {
                        Text("recording.key_descending_count".localized + ":")
                        Picker("", selection: $viewModel.descendingKeyCount) {
                            ForEach(1...12, id: \.self) { count in
                                Text("\(count) " + "recording.key_count_unit".localized).tag(count)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
        }
        .padding()
        .background(ColorPalette.secondary)
        .cornerRadius(12)
    }
}
