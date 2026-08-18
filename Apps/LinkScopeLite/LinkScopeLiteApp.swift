import AppKit
import LinkScopeCore
import LinkScopeUI
import SwiftUI

@main
struct LinkScopeLiteApp: App {
    @NSApplicationDelegateAdaptor(LinkScopeAppDelegate.self) private var appDelegate
    @State private var model = LinkScopeApplicationModel(edition: .lite)

    var body: some Scene {
        WindowGroup("LinkScope Lite", id: "main") {
            LinkScopeRootView(model: model)
                .frame(minWidth: 820, minHeight: 540)
        }
        .defaultSize(width: 1_120, height: 720)

        MenuBarExtra {
            LinkScopeMenuBarView(model: model)
        } label: {
            Label("LinkScope Lite", systemImage: "scope")
        }

        Settings {
            LinkScopeSettingsView(edition: .lite)
        }
    }
}

