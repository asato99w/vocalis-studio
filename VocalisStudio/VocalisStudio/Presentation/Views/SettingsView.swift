import SwiftUI

/// Settings screen - language selection and app information
public struct SettingsView: View {
    @StateObject private var localization = LocalizationManager.shared

    public init() {}

    public var body: some View {
        Form {
            Section("settings.language_section".localized) {
                Picker("settings.language_label".localized, selection: $localization.currentLanguage) {
                    Text("settings.language_japanese".localized).tag("ja")
                    Text("settings.language_english".localized).tag("en")
                }
                .pickerStyle(.inline)
            }

            Section("settings.info_section".localized) {
                HStack {
                    Text("settings.version_label".localized)
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("settings.title".localized)
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Preview

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SettingsView()
        }
    }
}
#endif
