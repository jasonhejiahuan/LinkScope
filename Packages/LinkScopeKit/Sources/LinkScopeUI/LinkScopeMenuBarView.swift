import AppKit
import SwiftUI

public struct LinkScopeMenuBarView: View {
    public let model: LinkScopeApplicationModel
    @Environment(\.openWindow) private var openWindow
    @AppStorage("LinkScope.uiLanguage") private var languageCode = AppLanguage.defaultLanguage.rawValue

    public init(model: LinkScopeApplicationModel) {
        self.model = model
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .english
    }

    public var body: some View {
        Group {
            VStack(alignment: .leading, spacing: 3) {
                Text("LinkScope").font(.headline)
                Text(L10n.formatted(
                    "menubar.summary",
                    language: language,
                    model.connectedAccessoryCount,
                    model.runningProviderCount
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Divider()
            Button(L10n.string("menubar.open", language: language)) {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            Button(L10n.string("menubar.snapshot", language: language)) {
                Task { await model.captureSnapshot() }
            }
            SettingsLink {
                Text(L10n.string("menubar.settings", language: language))
            }
            Divider()
            Button(L10n.string("menubar.quit", language: language)) {
                NSApplication.shared.terminate(nil)
            }
        }
        .environment(\.linkScopeLanguage, language)
        .task { await model.start() }
    }
}

