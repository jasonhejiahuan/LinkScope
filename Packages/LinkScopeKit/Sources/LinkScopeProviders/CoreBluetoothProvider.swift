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
    private var authorizationContinuations: [CheckedContinuation<CBManagerAuthorization, Never>] = []

    public override init() {
        super.init()
    }

    public func events() async -> AsyncStream<ProviderEvent> {
        emitter.stream()
    }

    public func start() async {
        switch CBManager.authorization {
        case .notDetermined:
            emitter.yield(.status(ProviderStatus(
                providerID: descriptor.id,
                state: .idle,
                message: "Bluetooth access has not been requested"
            )))
            return
        case .denied, .restricted:
            emitter.yield(.status(ProviderStatus(
                providerID: descriptor.id,
                state: .permissionDenied,
                message: "Bluetooth permission denied"
            )))
            return
        case .allowedAlways:
            break
        @unknown default:
            emitter.yield(.status(ProviderStatus(
                providerID: descriptor.id,
                state: .failed,
                message: "Unknown Bluetooth authorization state"
            )))
            return
        }

        let alreadyStarted = await MainActor.run { self.central != nil }
        guard !alreadyStarted else { return }
        emitter.yield(.status(ProviderStatus(providerID: descriptor.id, state: .starting)))
        await MainActor.run {
            self.central = CBCentralManager(
                delegate: self,
                queue: .main,
                options: [CBCentralManagerOptionShowPowerAlertKey: false]
            )
        }
    }

    /// Creates the CoreBluetooth manager only in response to an explicit user
    /// action, then waits for the authorization decision delivered to the
    /// manager delegate. Ordinary provider startup never enters this path.
    public func requestAuthorization() async -> CBManagerAuthorization {
        let current = CBManager.authorization
        guard current == .notDetermined else {
            await start()
            return current
        }

        emitter.yield(.status(ProviderStatus(providerID: descriptor.id, state: .starting)))
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                self.authorizationContinuations.append(continuation)
                if self.central == nil {
                    self.central = CBCentralManager(
                        delegate: self,
                        queue: .main,
                        options: [CBCentralManagerOptionShowPowerAlertKey: false]
                    )
                }
            }
        }
    }

    public func stop() async {
        let pending = await MainActor.run {
            self.central?.stopScan()
            self.central = nil
            let pending = self.authorizationContinuations
            self.authorizationContinuations.removeAll()
            return pending
        }
        let authorization = CBManager.authorization
        pending.forEach { $0.resume(returning: authorization) }
        emitter.yield(.status(ProviderStatus(providerID: descriptor.id, state: .stopped)))
        emitter.finish()
    }

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let authorization = CBManager.authorization
        if authorization != .notDetermined {
            let pending = authorizationContinuations
            authorizationContinuations.removeAll()
            pending.forEach { $0.resume(returning: authorization) }
        }

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
