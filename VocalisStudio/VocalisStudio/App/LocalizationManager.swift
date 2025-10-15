import Foundation
import SwiftUI

/// Manager for handling app localization
@MainActor
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "appLanguage")
            // Force bundle refresh
            Bundle.setLanguage(currentLanguage)
        }
    }
    
    private init() {
        // Load saved language or use system default
        if let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage") {
            self.currentLanguage = savedLanguage
            Bundle.setLanguage(savedLanguage)
        } else {
            // Use system language
            let systemLanguage = Locale.preferredLanguages.first ?? "en"
            self.currentLanguage = systemLanguage.hasPrefix("ja") ? "ja" : "en"
        }
    }
    
    func changeLanguage(_ language: String) {
        currentLanguage = language
    }
}

// MARK: - Bundle Extension for Language Switching

private var bundleKey: UInt8 = 0

extension Bundle {
    static func setLanguage(_ language: String) {
        defer {
            // Force SwiftUI to refresh
            object_setClass(Bundle.main, PrivateBundle.self)
        }
        objc_setAssociatedObject(Bundle.main, &bundleKey, Bundle(path: Bundle.main.path(forResource: language, ofType: "lproj") ?? ""), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    class PrivateBundle: Bundle {
        override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
            guard let bundle = objc_getAssociatedObject(self, &bundleKey) as? Bundle else {
                return super.localizedString(forKey: key, value: value, table: tableName)
            }
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
    }
}

// MARK: - SwiftUI Localization Helpers

extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    func localized(with arguments: CVarArg...) -> String {
        return String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}
