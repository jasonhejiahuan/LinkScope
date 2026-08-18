@preconcurrency import CoreAudio
import Foundation
import LinkScopeCore

public final class CoreAudioProvider: @unchecked Sendable, AccessoryProvider {
    public let descriptor = ProviderDescriptor(
        id: PublicProviderIDs.coreAudio,
        displayName: "Core Audio",
        transportKind: .coreAudio,
        capabilities: [
            ProviderCapability(id: "coreaudio.devices.read", operation: .read),
            ProviderCapability(id: "coreaudio.devices.observe", operation: .observe)
        ]
    )

    private let emitter = ProviderEventEmitter()
    private let queue = DispatchQueue(label: "cc.jasonstu.linkscope.coreaudio", qos: .utility)
    private var listener: AudioObjectPropertyListenerBlock?

    public init() {}

    public func events() async -> AsyncStream<ProviderEvent> {
        emitter.stream()
    }

    public func start() async {
        emitter.yield(.status(ProviderStatus(providerID: descriptor.id, state: .starting)))
        enumerateDevices()

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.enumerateDevices()
        }
        self.listener = listener
        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            queue,
            listener
        )
        if status == noErr {
            emitter.yield(.status(ProviderStatus(providerID: descriptor.id, state: .running)))
        } else {
            emitter.yield(.status(ProviderStatus(
                providerID: descriptor.id,
                state: .failed,
                message: "AudioObjectAddPropertyListenerBlock returned \(status)"
            )))
        }
    }

    public func stop() async {
        if let listener {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                queue,
                listener
            )
        }
        listener = nil
        emitter.yield(.status(ProviderStatus(providerID: descriptor.id, state: .stopped)))
        emitter.finish()
    }

    private func enumerateDevices() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size
        ) == noErr else {
            emitter.yield(.status(ProviderStatus(
                providerID: descriptor.id,
                state: .failed,
                message: "Unable to read Core Audio device-list size"
            )))
            return
        }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &devices
        ) == noErr else { return }

        let defaultOutput = defaultDevice(selector: kAudioHardwarePropertyDefaultOutputDevice)
        let defaultInput = defaultDevice(selector: kAudioHardwarePropertyDefaultInputDevice)
        for device in devices {
            emit(device, defaultOutput: defaultOutput, defaultInput: defaultInput)
        }
    }

    private func emit(
        _ device: AudioDeviceID,
        defaultOutput: AudioDeviceID?,
        defaultInput: AudioDeviceID?
    ) {
        let name = stringProperty(device, selector: kAudioObjectPropertyName) ?? "Audio Device \(device)"
        let uid = stringProperty(device, selector: kAudioDevicePropertyDeviceUID) ?? "audio-device:\(device)"
        let transportType = uint32Property(device, selector: kAudioDevicePropertyTransportType)
        let connectionProtocol = connectionProtocol(for: transportType)
        let bluetoothIdentifier = connectionProtocol == .bluetooth
            ? normalizedBluetoothIdentifier(fromAudioUID: uid)
            : nil
        let transport = TransportIdentity(
            providerID: descriptor.id,
            kind: .coreAudio,
            rawIdentifier: uid,
            displayName: name,
            physicalGroupIdentifier: physicalGroupIdentifier(
                uid: uid,
                connectionProtocol: connectionProtocol
            ),
            correlationDomain: connectionProtocol == .bluetooth
                ? "bluetooth-accessory"
                : nil,
            crossProviderIdentifier: bluetoothIdentifier,
            connectionProtocol: connectionProtocol
        )
        emitter.yield(ProviderObservationFactory.available(
            transport: transport,
            path: "identity.name",
            value: .string(name)
        ))
        emitter.yield(ProviderObservationFactory.available(
            transport: transport,
            path: "audio.deviceUID",
            value: .string(uid),
            sensitivity: .deviceIdentifier
        ))
        if let manufacturer = stringProperty(device, selector: kAudioObjectPropertyManufacturer) {
            emitter.yield(ProviderObservationFactory.available(
                transport: transport,
                path: "identity.manufacturer",
                value: .string(manufacturer)
            ))
        } else {
            emitter.yield(ProviderObservationFactory.unavailable(
                transport: transport,
                path: "identity.manufacturer",
                availability: .notReported(detail: "Core Audio did not report a manufacturer")
            ))
        }
        if let transportType {
            emitter.yield(ProviderObservationFactory.available(
                transport: transport,
                path: "audio.transportType",
                value: .unsignedInt(UInt64(transportType))
            ))
            emitter.yield(ProviderObservationFactory.available(
                transport: transport,
                path: "audio.transportProtocol",
                value: .string(connectionProtocol.rawValue)
            ))
        }
        if let alive = uint32Property(device, selector: kAudioDevicePropertyDeviceIsAlive) {
            emitter.yield(ProviderObservationFactory.available(
                transport: transport,
                path: "audio.deviceAlive",
                value: .bool(alive != 0)
            ))
        }
        let isDefaultAudioRoute = device == defaultOutput || device == defaultInput
        if connectionProtocol == .bluetooth {
            emitter.yield(ProviderObservationFactory.available(
                transport: transport,
                path: "connection.connected",
                value: .bool(isDefaultAudioRoute)
            ))
        } else {
            emitter.yield(ProviderObservationFactory.unavailable(
                transport: transport,
                path: "connection.connected",
                availability: .notExposed(
                    detail: "Core Audio DeviceIsAlive describes the audio object, not a verified accessory connection"
                )
            ))
        }
        emitter.yield(ProviderObservationFactory.available(
            transport: transport,
            path: "audio.defaultOutput",
            value: .bool(device == defaultOutput)
        ))
        emitter.yield(ProviderObservationFactory.available(
            transport: transport,
            path: "audio.defaultInput",
            value: .bool(device == defaultInput)
        ))
    }

    private func defaultDevice(selector: AudioObjectPropertySelector) -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &value
        )
        return status == noErr ? value : nil
    }

    private func stringProperty(
        _ object: AudioObjectID,
        selector: AudioObjectPropertySelector
    ) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, pointer)
        }
        return status == noErr ? value as String : nil
    }

    private func uint32Property(
        _ object: AudioObjectID,
        selector: AudioObjectPropertySelector
    ) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value)
        return status == noErr ? value : nil
    }

    private func connectionProtocol(for transportType: UInt32?) -> ConnectionProtocol {
        guard let transportType else { return .unknown }
        switch transportType {
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            return .bluetooth
        case kAudioDeviceTransportTypeUSB:
            return .usb
        case kAudioDeviceTransportTypeBuiltIn:
            return .builtIn
        case kAudioDeviceTransportTypeAirPlay:
            return .network
        case kAudioDeviceTransportTypeVirtual, kAudioDeviceTransportTypeAggregate:
            return .virtual
        default:
            return .unknown
        }
    }

    private func physicalGroupIdentifier(
        uid: String,
        connectionProtocol: ConnectionProtocol
    ) -> String? {
        guard connectionProtocol == .bluetooth else { return nil }
        let base = uid.components(separatedBy: "::").first ?? uid
        guard !base.isEmpty else { return nil }
        return "bluetooth-endpoints:\(base)"
    }
}

private func normalizedBluetoothIdentifier(fromAudioUID uid: String) -> String? {
    let base = uid.components(separatedBy: "::").first ?? uid
    let hex = base.lowercased().filter(\.isHexDigit)
    guard hex.count == 12,
          base.allSatisfy({ $0.isHexDigit || $0 == ":" || $0 == "-" }) else {
        return nil
    }
    return "bluetooth-address:\(hex)"
}
