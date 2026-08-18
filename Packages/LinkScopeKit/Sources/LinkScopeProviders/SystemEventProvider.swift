@preconcurrency import AppKit
import Foundation
import LinkScopeCore

public final class SystemEventProvider: @unchecked Sendable, AccessoryProvider {
    public let descriptor = ProviderDescriptor(
        id: PublicProviderIDs.systemEvents,
        displayName: "Workspace, Power & Thermal",
        transportKind: .system,
        capabilities: [
            ProviderCapability(id: "system.state.read", operation: .read),
            ProviderCapability(id: "system.lifecycle.observe", operation: .observe)
        ]
    )

    private let emitter = ProviderEventEmitter()
    private var workspaceTokens: [NSObjectProtocol] = []
    private var processTokens: [NSObjectProtocol] = []

    public init() {}

    public func events() async -> AsyncStream<ProviderEvent> {
        emitter.stream()
    }

    public func start() async {
        emitter.yield(.status(ProviderStatus(providerID: descriptor.id, state: .starting)))
        emitCurrentState()
        await MainActor.run {
            let workspaceCenter = NSWorkspace.shared.notificationCenter
            self.workspaceTokens.append(workspaceCenter.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in self?.emitLifecycle(kind: .systemSleep, message: "Mac will sleep") })
            self.workspaceTokens.append(workspaceCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.emitLifecycle(kind: .systemWake, message: "Mac woke from sleep")
                self?.emitCurrentState()
            })

            let processCenter = NotificationCenter.default
            for name in [
                Notification.Name("NSProcessInfoThermalStateDidChangeNotification"),
                Notification.Name("NSProcessInfoPowerStateDidChangeNotification")
            ] {
                self.processTokens.append(processCenter.addObserver(
                    forName: name,
                    object: ProcessInfo.processInfo,
                    queue: .main
                ) { [weak self] _ in self?.emitCurrentState() })
            }
        }
        emitter.yield(.status(ProviderStatus(providerID: descriptor.id, state: .running)))
    }

    public func stop() async {
        await MainActor.run {
            self.workspaceTokens.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
            self.processTokens.forEach(NotificationCenter.default.removeObserver)
            self.workspaceTokens.removeAll()
            self.processTokens.removeAll()
        }
        emitter.yield(.status(ProviderStatus(providerID: descriptor.id, state: .stopped)))
        emitter.finish()
    }

    private func emitCurrentState() {
        let transport = TransportIdentity(
            providerID: descriptor.id,
            kind: .system,
            rawIdentifier: "this-mac-system",
            displayName: Host.current().localizedName ?? "This Mac"
        )
        let process = ProcessInfo.processInfo
        emitter.yield(ProviderObservationFactory.available(
            transport: transport,
            path: "system.operatingSystemVersion",
            value: .string(process.operatingSystemVersionString)
        ))
        emitter.yield(ProviderObservationFactory.available(
            transport: transport,
            path: "power.lowPowerModeEnabled",
            value: .bool(process.isLowPowerModeEnabled)
        ))
        emitter.yield(ProviderObservationFactory.available(
            transport: transport,
            path: "thermal.state",
            value: .string(thermalStateName(process.thermalState))
        ))
        emitter.yield(.timeline(TimelineEvent(
            providerID: descriptor.id,
            kind: .thermalChanged,
            message: "Thermal state: \(thermalStateName(process.thermalState)); low power: \(process.isLowPowerModeEnabled)"
        )))
    }

    private func emitLifecycle(kind: TimelineEvent.Kind, message: String) {
        emitter.yield(.timeline(TimelineEvent(
            providerID: descriptor.id,
            kind: kind,
            message: message
        )))
    }

    private func thermalStateName(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "future"
        }
    }
}

