import SwiftUI
import VocalisDomain

/// Audio output settings configuration view (volumes and scale sound type)
struct AudioOutputSettingsView: View {

    @StateObject private var viewModel: AudioOutputSettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showResetAlert = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""

    init(viewModel: AudioOutputSettingsViewModel) {
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

                // Scale Sound Type Section
                Section {
                    Picker("音源", selection: $viewModel.scaleSoundType) {
                        ForEach(ScaleSoundType.allCases, id: \.self) { soundType in
                            HStack {
                                Text(soundType.icon)
                                Text(soundType.displayName)
                            }
                            .tag(soundType)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("スケール再生音")
                } footer: {
                    if let description = viewModel.scaleSoundType.description as String? {
                        Text(description)
                    }
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
            .navigationTitle("出力設定")
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
                Text("出力設定をデフォルト値に戻しますか?")
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
    AudioOutputSettingsView(
        viewModel: AudioOutputSettingsViewModel(
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
