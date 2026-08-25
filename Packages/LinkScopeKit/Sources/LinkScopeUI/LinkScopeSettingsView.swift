import LinkScopeCore
import ServiceManagement
import SwiftUI

public struct LinkScopeSettingsView: View {
    public let model: LinkScopeApplicationModel
    @AppStorage("LinkScope.uiLanguage") private var languageCode = AppLanguage.defaultLanguage.rawValue
    @State private var loginItemEnabled = SMAppService.mainApp.status == .enabled
    @State private var loginItemError: String?
    @AppStorage("LinkScope.historyRetentionDays") private var retentionDays = 0
    @State private var confirmingRetention = false

    public init(model: LinkScopeApplicationModel) {
        self.model = model
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
                    Text(model.edition == .full ? "LinkScope" : "LinkScope Lite")
                }
                LabeledContent(L10n.string("settings.version", language: language)) {
                    Text(versionDescription)
                }
                LabeledContent(L10n.string("settings.history", language: language)) {
                    Picker("", selection: $retentionDays) {
                        Text(L10n.string("settings.history.unlimited", language: language)).tag(0)
                        Text(L10n.string("settings.history.30days", language: language)).tag(30)
                        Text(L10n.string("settings.history.90days", language: language)).tag(90)
                        Text(L10n.string("settings.history.1year", language: language)).tag(365)
                    }
                    .labelsHidden()
                }
                if retentionDays > 0 {
                    Button(L10n.string("settings.history.preview", language: language)) {
                        Task {
                            await model.previewRetention(days: retentionDays)
                            confirmingRetention = model.retentionCandidateCount > 0
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label(L10n.string("settings.storage", language: language), systemImage: "internaldrive")
            }

            PermissionManagementView(model: model)
            .tabItem {
                Label(L10n.string("settings.permissions", language: language), systemImage: "checkmark.shield")
            }
        }
        .environment(\.linkScopeLanguage, language)
        .frame(width: 620, height: 440)
        .task { await model.refreshPermissionStatuses() }
        .alert(
            L10n.string("settings.history.confirmTitle", language: language),
            isPresented: $confirmingRetention
        ) {
            Button(L10n.string("common.cancel", language: language), role: .cancel) {}
            Button(L10n.string("settings.history.delete", language: language), role: .destructive) {
                Task { await model.applyRetention(days: retentionDays) }
            }
        } message: {
            Text(L10n.formatted(
                "settings.history.confirmMessage",
                language: language,
                model.retentionCandidateCount
            ))
        }
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
