import AppKit
import AppIntents
import LinkScopeCore
import LinkScopeUI
import SwiftUI

@main
struct LinkScopeApp: App {
    @NSApplicationDelegateAdaptor(LinkScopeAppDelegate.self) private var appDelegate
    @State private var model: LinkScopeApplicationModel

    init() {
        let model = LinkScopeApplicationModel(edition: .full)
        _model = State(initialValue: model)
        AppDependencyManager.shared.add(dependency: model)
        LinkScopeShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup("LinkScope", id: "main") {
            LinkScopeRootView(model: model)
                .frame(minWidth: 820, minHeight: 540)
                .onAppear {
                    appDelegate.installApplicationModel(model)
                }
        }
        .defaultSize(width: 1_120, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            LinkScopeCommands(model: model)
        }

        MenuBarExtra {
            LinkScopeMenuBarView(model: model)
        } label: {
            Label("LinkScope", systemImage: "scope")
        }

        Settings {
            LinkScopeSettingsView(model: model)
        }
        .windowResizability(.contentSize)
    }
}
