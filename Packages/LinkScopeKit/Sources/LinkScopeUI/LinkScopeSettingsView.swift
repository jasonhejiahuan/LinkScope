import LinkScopeCore
import ServiceManagement
import SwiftUI

public struct LinkScopeSettingsView: View {
    public let edition: LinkScopeEdition
    @AppStorage("LinkScope.uiLanguage") private var languageCode = AppLanguage.defaultLanguage.rawValue
    @State private var loginItemEnabled = SMAppService.mainApp.status == .enabled
    @State private var loginItemError: String?

    public init(edition: LinkScopeEdition) {
        self.edition = edition
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .english
    }

    public var body: some View {
        TabView {
            Form {
                Picker(L10n.string("settings.language", language: language), selection: $languageCode) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.nativeName).tag(language.rawValue)
                    }
                }
                Toggle(
                    L10n.string("settings.launchAtLogin", language: language),
                    isOn: Binding(
                        get: { loginItemEnabled },
                        set: updateLoginItem
                    )
                )
                if let loginItemError {
                    Text(loginItemError).font(.caption).foregroundStyle(.red)
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label(L10n.string("settings.general", language: language), systemImage: "gearshape")
            }

            Form {
                LabeledContent(L10n.string("settings.edition", language: language)) {
                    Text(edition == .full ? "LinkScope" : "LinkScope Lite")
                }
                LabeledContent(L10n.string("settings.version", language: language)) {
                    Text(versionDescription)
                }
                LabeledContent(L10n.string("settings.history", language: language)) {
                    Text(L10n.string("settings.history.unlimited", language: language))
                }
                Text(L10n.string("settings.readOnly", language: language))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .formStyle(.grouped)
            .tabItem {
                Label(L10n.string("settings.privacy", language: language), systemImage: "lock.shield")
            }
        }
        .environment(\.linkScopeLanguage, language)
        .frame(width: 520, height: 320)
    }

    private func updateLoginItem(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemEnabled = enabled
            loginItemError = nil
        } catch {
            loginItemEnabled = SMAppService.mainApp.status == .enabled
            loginItemError = error.localizedDescription
        }
    }

    private var versionDescription: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "—"
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "—"
        return "\(version) (\(build))"
    }
}
