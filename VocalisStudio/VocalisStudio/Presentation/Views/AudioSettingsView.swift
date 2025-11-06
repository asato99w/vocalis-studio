import SwiftUI
import VocalisDomain

/// Audio settings configuration view
struct AudioSettingsView: View {

    @StateObject private var viewModel: AudioSettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showResetAlert = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""

    init(viewModel: AudioSettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationView {
            Form {
                // Volume Settings Section
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        // Scale Playback Volume
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("スケール再生音量")
                                    .font(.body)
                                Spacer()
                                Text("\(Int(viewModel.scalePlaybackVolume * 100))%")
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $viewModel.scalePlaybackVolume, in: 0...1, step: 0.05)
                        }

                        // Recording Playback Volume
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("録音再生音量")
                                    .font(.body)
                                Spacer()
                                Text("\(Int(viewModel.recordingPlaybackVolume * 100))%")
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $viewModel.recordingPlaybackVolume, in: 0...1, step: 0.05)
                        }
                    }
                } header: {
                    Text("音量設定")
                } footer: {
                    Text("スケール再生音量と録音再生音量を個別に調整できます")
                }

                // Detection Sensitivity Section
                Section {
                    Picker("検出感度", selection: $viewModel.detectionSensitivity) {
                        Text("低").tag(AudioDetectionSettings.DetectionSensitivity.low)
                        Text("標準").tag(AudioDetectionSettings.DetectionSensitivity.normal)
                        Text("高").tag(AudioDetectionSettings.DetectionSensitivity.high)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("ピッチ検出感度")
                } footer: {
                    Text("低: 大きい音のみ検出\n標準: バランスの取れた検出\n高: 小さい音も検出")
                }

                // Confidence Threshold Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("検出精度")
                                .font(.body)
                            Spacer()
                            Text("\(Int(viewModel.confidenceThreshold * 100))%")
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $viewModel.confidenceThreshold, in: 0.1...1.0, step: 0.05)
                    }
                } header: {
                    Text("ピッチ検出精度")
                } footer: {
                    Text("検出結果の信頼度閾値。高いほど正確なピッチのみ表示")
                }

                // Reset Button Section
                Section {
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("デフォルトに戻す")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("オーディオ設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveSettings()
                    }
                    .disabled(!viewModel.hasChanges)
                }
            }
            .alert("デフォルトに戻す", isPresented: $showResetAlert) {
                Button("キャンセル", role: .cancel) { }
                Button("リセット", role: .destructive) {
                    resetSettings()
                }
            } message: {
                Text("すべての設定をデフォルト値に戻しますか?")
            }
            .alert("保存エラー", isPresented: $showSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveErrorMessage)
            }
        }
    }

    // MARK: - Private Methods

    private func saveSettings() {
        do {
            try viewModel.saveSettings()
            dismiss()
        } catch {
            saveErrorMessage = "設定の保存に失敗しました: \(error.localizedDescription)"
            showSaveError = true
        }
    }

    private func resetSettings() {
        do {
            try viewModel.resetSettings()
        } catch {
            saveErrorMessage = "設定のリセットに失敗しました: \(error.localizedDescription)"
            showSaveError = true
        }
    }
}

// MARK: - Preview

#Preview {
    AudioSettingsView(
        viewModel: AudioSettingsViewModel(
            repository: PreviewAudioSettingsRepository()
        )
    )
}

/// Preview用のリポジトリ実装
private class PreviewAudioSettingsRepository: AudioSettingsRepositoryProtocol {
    func get() -> AudioDetectionSettings {
        .default
    }

    func save(_ settings: AudioDetectionSettings) throws {
        // Preview用なので何もしない
    }

    func reset() throws {
        // Preview用なので何もしない
    }
}
