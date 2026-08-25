import AppIntents
import LinkScopeCore

enum LinkScopeIntentError: Error, CustomLocalizedStringResourceConvertible {
    case noDiagnosticSources

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noDiagnosticSources:
            "No sample-capable diagnostic sources are currently available."
        }
    }
}

struct StartLinkScopeDiagnosticIntent: AppIntent {
    static let title: LocalizedStringResource = "Start LinkScope Diagnostic"
    static let description = IntentDescription("Starts an explicit, time-limited diagnostic session.")

    @Parameter(title: "Name", default: "Shortcut Diagnostic")
    var name: String

    @Parameter(title: "Duration in Minutes", default: 5, inclusiveRange: (1, 60))
    var durationMinutes: Int

    @Dependency private var model: LinkScopeApplicationModel

    static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$name) for \(\.$durationMinutes) minutes")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        await model.start()
        if model.diagnosticSources.isEmpty {
            try await Task.sleep(for: .milliseconds(500))
        }
        let sources = Set(model.diagnosticSources.map(\.id))
        guard !sources.isEmpty else { throw LinkScopeIntentError.noDiagnosticSources }
        try await model.startDiagnostic(
            name: name,
            purpose: "Started from Shortcuts",
            sourceIDs: sources,
            duration: TimeInterval(durationMinutes * 60),
            samplingPolicy: .fixedInterval(seconds: 5)
        )
        return .result(dialog: "The diagnostic session has started.")
    }
}

struct StopLinkScopeDiagnosticIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop LinkScope Diagnostic"
    static let description = IntentDescription("Stops the active diagnostic session, if any.")

    @Dependency private var model: LinkScopeApplicationModel

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard model.activeDiagnostic != nil else {
            return .result(dialog: "No diagnostic session is running.")
        }
        await model.stopDiagnostic()
        return .result(dialog: "The diagnostic session has stopped.")
    }
}

struct LinkScopeDiagnosticStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Get LinkScope Diagnostic Status"
    static let description = IntentDescription("Reports the current LinkScope diagnostic status.")

    @Dependency private var model: LinkScopeApplicationModel

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        if let run = model.activeDiagnostic {
            return .result(dialog: "The \(run.name) session is running with \(run.sampleCount) samples and \(run.gapCount) gaps.")
        }
        return .result(dialog: "No diagnostic session is running.")
    }
}

struct CaptureLinkScopeSnapshotIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture LinkScope Snapshot"
    static let description = IntentDescription("Captures a read-only LinkScope snapshot.")

    @Dependency private var model: LinkScopeApplicationModel

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        await model.start()
        await model.captureSnapshot(name: "Shortcut Snapshot")
        return .result(dialog: "The LinkScope snapshot was captured.")
    }
}

public struct LinkScopeShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartLinkScopeDiagnosticIntent(),
            phrases: ["Start a diagnostic in \(.applicationName)"],
            shortTitle: "Start Diagnostic",
            systemImageName: "waveform.path.ecg"
        )
        AppShortcut(
            intent: StopLinkScopeDiagnosticIntent(),
            phrases: ["Stop the diagnostic in \(.applicationName)"],
            shortTitle: "Stop Diagnostic",
            systemImageName: "stop.circle"
        )
        AppShortcut(
            intent: LinkScopeDiagnosticStatusIntent(),
            phrases: ["Get diagnostic status in \(.applicationName)"],
            shortTitle: "Diagnostic Status",
            systemImageName: "info.circle"
        )
        AppShortcut(
            intent: CaptureLinkScopeSnapshotIntent(),
            phrases: ["Capture a snapshot in \(.applicationName)"],
            shortTitle: "Capture Snapshot",
            systemImageName: "camera"
        )
    }
}
