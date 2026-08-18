import Foundation
@preconcurrency import GameController
import LinkScopeCore

public final class GameControllerProvider: @unchecked Sendable, AccessoryProvider {
    public let descriptor = ProviderDescriptor(
        id: PublicProviderIDs.gameController,
        displayName: "Game Controller",
        transportKind: .gameController,
        capabilities: [
            ProviderCapability(id: "gamecontroller.devices.read", operation: .read),
            ProviderCapability(id: "gamecontroller.connections.observe", operation: .observe),
            ProviderCapability(id: "gamecontroller.battery.observe", operation: .observe, parameterPath: "battery.level")
        ]
    )

    private let emitter = ProviderEventEmitter()
    private var tokens: [NSObjectProtocol] = []

    public init() {}

    public func events() async -> AsyncStream<ProviderEvent> {
        emitter.stream()
    }

    public func start() async {
        emitter.yield(.status(ProviderStatus(providerID: descriptor.id, state: .starting)))
        await MainActor.run {
            let center = NotificationCenter.default
            self.tokens.append(center.addObserver(
                forName: .GCControllerDidConnect,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let controller = notification.object as? GCController else { return }
                self?.emit(controller, connected: true)
            })
            self.tokens.append(center.addObserver(
                forName: .GCControllerDidDisconnect,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let controller = notification.object as? GCController else { return }
                self?.emit(controller, connected: false)
            })
            for controller in GCController.controllers() {
                self.emit(controller, connected: true)
            }
        }
        emitter.yield(.status(ProviderStatus(providerID: descriptor.id, state: .running)))
    }

    public func stop() async {
        await MainActor.run {
            self.tokens.forEach(NotificationCenter.default.removeObserver)
            self.tokens.removeAll()
        }
        emitter.yield(.status(ProviderStatus(providerID: descriptor.id, state: .stopped)))
        emitter.finish()
    }

    private func emit(_ controller: GCController, connected: Bool) {
        let rawIdentifier = controller.vendorName.map { "vendor:\($0)|player:\(controller.playerIndex.rawValue)" }
            ?? "controller:\(ObjectIdentifier(controller).hashValue)"
        let transport = TransportIdentity(
            providerID: descriptor.id,
            kind: .gameController,
            rawIdentifier: rawIdentifier,
            displayName: controller.vendorName ?? "Game Controller"
        )
        emitter.yield(ProviderObservationFactory.available(
            transport: transport,
            path: "connection.connected",
            value: .bool(connected)
        ))
        emitter.yield(ProviderObservationFactory.available(
            transport: transport,
            path: "identity.name",
            value: .string(controller.vendorName ?? "Game Controller")
        ))
        if let battery = controller.battery {
            emitter.yield(ProviderObservationFactory.available(
                transport: transport,
                path: "battery.level",
                value: .double(Double(battery.batteryLevel))
            ))
            emitter.yield(ProviderObservationFactory.available(
                transport: transport,
                path: "battery.state",
                value: .string(batteryStateName(battery.batteryState))
            ))
        } else {
            emitter.yield(ProviderObservationFactory.unavailable(
                transport: transport,
                path: "battery.level",
                availability: .notReported(detail: "The controller did not expose a battery object")
            ))
        }
        emitter.yield(.timeline(TimelineEvent(
            providerID: descriptor.id,
            kind: connected ? .deviceConnected : .deviceDisconnected,
            message: "Game controller \(connected ? "connected" : "disconnected"): \(controller.vendorName ?? "Unknown")"
        )))
    }

    private func batteryStateName(_ state: GCDeviceBattery.State) -> String {
        switch state {
        case .unknown: "unknown"
        case .discharging: "discharging"
        case .charging: "charging"
        case .full: "full"
        @unknown default: "future"
        }
    }
}

