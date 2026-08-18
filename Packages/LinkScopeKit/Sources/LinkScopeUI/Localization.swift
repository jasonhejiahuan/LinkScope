import Foundation
import SwiftUI

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    public var id: String { rawValue }

    public static var defaultLanguage: AppLanguage {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true ? .simplifiedChinese : .english
    }

    public var nativeName: String {
        switch self {
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        }
    }
}

private struct LinkScopeLanguageKey: EnvironmentKey {
    static let defaultValue = AppLanguage.defaultLanguage
}

extension EnvironmentValues {
    var linkScopeLanguage: AppLanguage {
        get { self[LinkScopeLanguageKey.self] }
        set { self[LinkScopeLanguageKey.self] = newValue }
    }
}

enum L10n {
    static func string(_ key: String, language: AppLanguage) -> String {
        guard let path = Bundle.module.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.module.localizedString(forKey: key, value: key, table: nil)
        }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func formatted(
        _ key: String,
        language: AppLanguage,
        _ arguments: CVarArg...
    ) -> String {
        String(format: string(key, language: language), locale: Locale(identifier: language.rawValue), arguments: arguments)
    }
}

struct LText: View {
    @Environment(\.linkScopeLanguage) private var language
    let key: String

    init(_ key: String) {
        self.key = key
    }

    var body: some View {
        Text(L10n.string(key, language: language))
    }
}

