import SwiftUI

/// Settings screen - language selection and app information
public struct SettingsView: View {
    @AppStorage("appLanguage") private var language = "ja"

    public init() {}

    public var body: some View {
        Form {
            Section("言語設定") {
                Picker("言語", selection: $language) {
                    Text("日本語").tag("ja")
                    Text("English").tag("en")
                }
                .pickerStyle(.inline)
            }

            Section("情報") {
                HStack {
                    Text("バージョン")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.large)
        .onChange(of: language) {
            // TODO: Update localization when implemented
            print("Language changed to: \(language)")
        }
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
