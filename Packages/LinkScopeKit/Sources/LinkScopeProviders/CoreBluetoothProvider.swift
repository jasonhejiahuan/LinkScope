@preconcurrency import CoreBluetooth
import Foundation
import LinkScopeCore

public final class CoreBluetoothProvider: NSObject, @unchecked Sendable, AccessoryProvider, CBCentralManagerDelegate {
    public let descriptor = ProviderDescriptor(
        id: PublicProviderIDs.coreBluetooth,
        displayName: "CoreBluetooth",
        transportKind: .coreBluetooth,
        capabilities: [
            ProviderCapability(id: "corebluetooth.state.observe", operation: .observe),
            ProviderCapability(id: "corebluetooth.known-services.read", operation: .read)
        ]
    )

    private let emitter = ProviderEventEmitter()
    private var central: CBCentralManager?

    public override init() {
        super.init()
    }

    public func events() async -> AsyncStream<ProviderEvent> {
        emitter.stream()
    }

    public func start() async {
        emitter.yield(.status(ProviderStatus(providerID: descriptor.id, state: .starting)))
        await MainActor.run {
            guard self.central == nil else { return }
            self.central = CBCentralManager(
                delegate: self,
                queue: .main,
                options: [CBCentralManagerOptionShowPowerAlertKey: false]
            )
        }
    }

    public func stop() async {
        await MainActor.run {
            self.central?.stopScan()
            self.central = nil
        }
        emitter.yield(.status(ProviderStatus(providerID: descriptor.id, state: .stopped)))
        emitter.finish()
    }

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let transport = TransportIdentity(
            providerID: descriptor.id,
            kind: .system,
            rawIdentifier: "this-mac-corebluetooth",
            displayName: "This Mac"
        )
        emitter.yield(ProviderObservationFactory.available(
            transport: transport,
            path: "bluetooth.controllerState",
            value: .string(stateName(central.state))
        ))

        switch central.state {
        case .poweredOn:
            emitter.yield(.status(ProviderStatus(
                providerID: descriptor.id,
                state: .running,
                message: "Event-driven state only; no continuous BLE scan"
            )))
            emitter.yield(ProviderObservationFactory.unavailable(
                transport: transport,
                path: "bluetooth.arbitraryConnectedPeripherals",
                availability: .notExposed(
                    detail: "CoreBluetooth only retrieves connected peripherals for service UUIDs already known to the app"
                )
            ))
        case .unauthorized:
            emitter.yield(.status(ProviderStatus(
                providerID: descriptor.id,
                state: .permissionDenied,
                message: "Bluetooth permission denied"
            )))
        case .unsupported:
            emitter.yield(.status(ProviderStatus(
                providerID: descriptor.id,
                state: .unsupported,
                message: "CoreBluetooth is unsupported on this Mac"
            )))
        case .poweredOff, .resetting, .unknown:
            emitter.yield(.status(ProviderStatus(
                providerID: descriptor.id,
                state: .running,
                message: "Bluetooth state: \(stateName(central.state))"
            )))
        @unknown default:
            emitter.yield(.status(ProviderStatus(
                providerID: descriptor.id,
                state: .failed,
                message: "Unknown CoreBluetooth manager state"
            )))
        }
    }

    private func stateName(_ state: CBManagerState) -> String {
        switch state {
        case .unknown: "unknown"
        case .resetting: "resetting"
        case .unsupported: "unsupported"
        case .unauthorized: "unauthorized"
        case .poweredOff: "poweredOff"
        case .poweredOn: "poweredOn"
        @unknown default: "future(\(state.rawValue))"
        }
    }
}
