import AppKit

@MainActor
public final class LinkScopeAppDelegate: NSObject, NSApplicationDelegate {
    private weak var applicationModel: LinkScopeApplicationModel?
    private var terminationTask: Task<Void, Never>?

    public override init() {
        super.init()
    }

    public func installApplicationModel(_ model: LinkScopeApplicationModel) {
        applicationModel = model
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    public func applicationShouldTerminate(
        _ sender: NSApplication
    ) -> NSApplication.TerminateReply {
        guard let applicationModel else { return .terminateNow }
        guard terminationTask == nil else { return .terminateLater }

        terminationTask = Task { [weak self, weak sender] in
            await applicationModel.stop()
            sender?.reply(toApplicationShouldTerminate: true)
            self?.terminationTask = nil
        }
        return .terminateLater
    }
}
