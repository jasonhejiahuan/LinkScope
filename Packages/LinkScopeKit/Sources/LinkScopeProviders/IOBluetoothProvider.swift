@preconcurrency import CoreBluetooth
import Foundation
@preconcurrency import IOBluetooth
import LinkScopeCore

public final class IOBluetoothProvider: NSObject, @unchecked Sendable, AccessoryProvider {
    public let descriptor = ProviderDescriptor(
        id: PublicProviderIDs.ioBluetooth,
        displayName: "IOBluetooth",
        transportKind: .ioBluetooth,
        capabilities: [
            ProviderCapability(id: "iobluetooth.paired.read", operation: .read),
            ProviderCapability(id: "iobluetooth.connections.observe", operation: .observe),
            ProviderCapability(id: "iobluetooth.rssi.sample", operation: .sample, parameterPath: "radio.rssi")
        ]
    )

    private let emitter = ProviderEventEmitter()
    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotifications: [String: IOBluetoothUserNotification] = [:]
    private var isStarted = false

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

        let didStart = await MainActor.run {
            guard !self.isStarted else { return false }
            self.isStarted = true
            self.emitter.yield(.status(ProviderStatus(providerID: self.descriptor.id, state: .starting)))
            self.connectNotification = IOBluetoothDevice.register(
                forConnectNotifications: self,
                selector: #selector(self.deviceConnected(_:device:))
            )
            let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
            for device in paired {
                self.emit(device, event: "initial")
                self.registerDisconnect(for: device)
            }
            return true
        }
        if didStart {
            emitter.yield(.status(ProviderStatus(providerID: descriptor.id, state: .running)))
        }
    }

    public func stop() async {
        await MainActor.run {
            self.connectNotification?.unregister()
            self.connectNotification = nil
            self.disconnectNotifications.values.forEach { $0.unregister() }
            self.disconnectNotifications.removeAll()
            self.isStarted = false
        }
        emitter.yield(.status(ProviderStatus(providerID: descriptor.id, state: .stopped)))
        emitter.finish()
    }

    public func sample(_ request: ProviderSampleRequest) async -> AccessoryObservation? {
        guard CBManager.authorization == .allowedAlways else { return nil }
        guard request.parameterPath.rawValue == "radio.rssi" else { return nil }
        return await MainActor.run {
            let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
            guard let device = paired.first(where: {
                ($0.addressString ?? "") == request.transport.rawIdentifier
            }) else { return nil }
            let transport = transportIdentity(for: device)
            guard device.isConnected() else {
                return AccessoryObservation(
                    transportIdentity: transport,
                    parameterPath: request.parameterPath,
                    value: nil,
                    availability: .notReported(
                        detail: "RSSI is only readable while the Bluetooth device is connected"
                    ),
                    sessionID: request.sessionID
                )
            }
            guard device.classOfDevice != 0 else {
                return AccessoryObservation(
                    transportIdentity: transport,
                    parameterPath: request.parameterPath,
                    value: nil,
                    availability: .notReported(
                        detail: "RSSI is not sampled for a background, non-user-visible Bluetooth link"
                    ),
                    sessionID: request.sessionID
                )
            }
            let rssi = Int64(device.rawRSSI())
            return AccessoryObservation(
                transportIdentity: transport,
                parameterPath: request.parameterPath,
                value: rssi == 127 ? nil : .signedInt(rssi),
                availability: rssi == 127
                    ? .notReported(detail: "The controller returned the RSSI unavailable sentinel")
                    : .available,
                sessionID: request.sessionID
            )
        }
    }

    @objc private func deviceConnected(
        _ notification: IOBluetoothUserNotification,
        device: IOBluetoothDevice
    ) {
        emit(device, event: "connected")
        registerDisconnect(for: device)
        emitter.yield(.timeline(TimelineEvent(
            providerID: descriptor.id,
            kind: .deviceConnected,
            message: "Bluetooth device connected: \(deviceName(device))"
        )))
    }

    @objc private func deviceDisconnected(
        _ notification: IOBluetoothUserNotification,
        device: IOBluetoothDevice
    ) {
        let transport = transportIdentity(for: device)
        emitter.yield(ProviderObservationFactory.available(
            transport: transport,
            path: "connection.connected",
            value: .bool(false)
        ))
        emitter.yield(.timeline(TimelineEvent(
            providerID: descriptor.id,
            kind: .deviceDisconnected,
            message: "Bluetooth device disconnected: \(deviceName(device))"
        )))
    }

    private func registerDisconnect(for device: IOBluetoothDevice) {
        let key = device.addressString ?? "object:\(ObjectIdentifier(device).hashValue)"
        guard disconnectNotifications[key] == nil else { return }
        disconnectNotifications[key] = device.register(
            forDisconnectNotification: self,
            selector: #selector(deviceDisconnected(_:device:))
        )
    }

    private func emit(_ device: IOBluetoothDevice, event: String) {
        let transport = transportIdentity(for: device)
        let basebandConnected = device.isConnected()
        let classOfDevice = device.classOfDevice
        // A class-zero Apple BLE companion link can stay up for metadata such
        // as battery reporting while no user-facing HID or audio service is
        // active. Keep the baseband fact inspectable, but do not promote that
        // background link to LinkScope's user-visible Connected state.
        let userVisibleConnected = basebandConnected && classOfDevice != 0
        emitter.yield(ProviderObservationFactory.available(
            transport: transport,
            path: "connection.connected",
            value: .bool(userVisibleConnected)
        ))
        emitter.yield(ProviderObservationFactory.available(
            transport: transport,
            path: "bluetooth.basebandConnected",
            value: .bool(basebandConnected)
        ))
        emitter.yield(ProviderObservationFactory.available(
            transport: transport,
            path: "identity.name",
            value: .string(deviceName(device))
        ))
        if let address = device.addressString {
            emitter.yield(ProviderObservationFactory.available(
                transport: transport,
                path: "bluetooth.address",
                value: .string(address),
                sensitivity: .deviceIdentifier
            ))
        } else {
            emitter.yield(ProviderObservationFactory.unavailable(
                transport: transport,
                path: "bluetooth.address",
                availability: .notReported(detail: "IOBluetooth did not report an address"),
                sensitivity: .deviceIdentifier
            ))
        }
        emitter.yield(ProviderObservationFactory.available(
            transport: transport,
            path: "bluetooth.paired",
            value: .bool(true)
        ))
        emitter.yield(ProviderObservationFactory.available(
            transport: transport,
            path: "bluetooth.classOfDevice",
            value: .unsignedInt(UInt64(classOfDevice))
        ))
        if userVisibleConnected {
            let rssi = Int64(device.rawRSSI())
            if rssi == 127 {
                emitter.yield(ProviderObservationFactory.unavailable(
                    transport: transport,
                    path: "radio.rssi",
                    availability: .notReported(detail: "The controller returned the Bluetooth RSSI unavailable sentinel")
                ))
            } else {
                emitter.yield(ProviderObservationFactory.available(
                    transport: transport,
                    path: "radio.rssi",
                    value: .signedInt(rssi)
                ))
            }
        } else if basebandConnected {
            emitter.yield(ProviderObservationFactory.unavailable(
                transport: transport,
                path: "radio.rssi",
                availability: .notReported(
                    detail: "RSSI is not sampled for a background, non-user-visible Bluetooth link"
                )
            ))
        } else {
            emitter.yield(ProviderObservationFactory.unavailable(
                transport: transport,
                path: "radio.rssi",
                availability: .notReported(detail: "RSSI is only readable while the classic Bluetooth device is connected")
            ))
        }
        emitter.yield(ProviderObservationFactory.unavailable(
            transport: transport,
            path: "battery.level",
            availability: .notExposed(detail: "IOBluetooth does not expose a general accessory battery property")
        ))
        _ = event
    }

    private func transportIdentity(for device: IOBluetoothDevice) -> TransportIdentity {
        let address = device.addressString
        return TransportIdentity(
            providerID: descriptor.id,
            kind: .ioBluetooth,
            rawIdentifier: address ?? "object:\(ObjectIdentifier(device).hashValue)",
            displayName: deviceName(device),
            correlationDomain: "bluetooth-accessory",
            crossProviderIdentifier: address.flatMap(normalizedBluetoothIdentifier),
            connectionProtocol: .bluetooth
        )
    }

    private func deviceName(_ device: IOBluetoothDevice) -> String {
        device.nameOrAddress ?? device.addressString ?? "Bluetooth Device"
    }
}

private func normalizedBluetoothIdentifier(_ value: String) -> String? {
    let hex = value.lowercased().filter(\.isHexDigit)
    guard hex.count == 12 else { return nil }
    return "bluetooth-address:\(hex)"
}
