import SwiftUI

/// Settings screen view
struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    
    init(viewModel: SettingsViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationView {
            Form {
                languageSection
            }
            .navigationTitle("settings.title".localized)
            .alert("alert.language.changed.title".localized, isPresented: $viewModel.showLanguageChangeAlert) {
                Button("alert.language.changed.ok".localized) {
                    viewModel.dismissLanguageChangeAlert()
                }
            } message: {
                Text("alert.language.changed.message".localized(with: viewModel.selectedLanguage.displayName))
            }
        }
    }
    
    private var languageSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("settings.language.title".localized)
                    .font(.headline)
                
                Text("settings.language.description".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("settings.language.title".localized, selection: $viewModel.selectedLanguage) {
                    ForEach(viewModel.languageSettings.availableLanguages) { language in
                        Text(language.displayName)
                            .tag(language)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Preview
#Preview {
    let mockRepository = MockLanguageSettingsRepository()
    let getUseCase = GetLanguageSettingsUseCase(repository: mockRepository)
    let changeUseCase = ChangeLanguageUseCase(repository: mockRepository)
    let viewModel = SettingsViewModel(
        getLanguageSettingsUseCase: getUseCase,
        changeLanguageUseCase: changeUseCase
    )
    
    return SettingsView(viewModel: viewModel)
}