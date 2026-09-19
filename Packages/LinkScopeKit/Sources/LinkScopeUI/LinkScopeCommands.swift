import AppKit
import SwiftUI

public struct LinkScopeCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    private let model: LinkScopeApplicationModel

    public init(model: LinkScopeApplicationModel) {
        self.model = model
    }

    public var body: some Commands {
        CommandGroup(after: .newItem) {
            Button(L10n.string("menubar.snapshot")) {
                Task { await model.captureSnapshot() }
            }
            .keyboardShortcut("s", modifiers: [.command, .option])
        }

        CommandGroup(after: .windowArrangement) {
            Button(L10n.string("menubar.open")) {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            .keyboardShortcut("1", modifiers: .command)
        }
    }
}
