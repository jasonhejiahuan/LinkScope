@preconcurrency import CoreFoundation
#if canImport(CoreHID)
@preconcurrency import CoreHID
#endif
import Foundation
@preconcurrency import IOKit.hid
import LinkScopeCore

public final class CoreHIDProvider: @unchecked Sendable, AccessoryProvider {
    public let descriptor = ProviderDescriptor(
        id: PublicProviderIDs.coreHID,
        displayName: "CoreHID / IOHID",
        transportKind: .coreHID,
        capabilities: [
            ProviderCapability(id: "corehid.devices.read", operation: .read),
            ProviderCapability(id: "corehid.devices.observe", operation: .observe)
        ]
    )

    private let emitter = ProviderEventEmitter()
    private var manager: IOHIDManager?

    public init() {}

    public func events() async -> AsyncStream<ProviderEvent> {
        emitter.stream()
    }

    public func start() async {
        emitter.yield(.status(ProviderStatus(providerID: descriptor.id, state: .starting)))
        await MainActor.run {
            guard manager == nil else { return }
            let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
            self.manager = manager
            let context = Unmanaged.passUnretained(self).toOpaque()
            IOHIDManagerSetDeviceMatching(manager, nil)
            IOHIDManagerRegisterDeviceMatchingCallback(manager, linkScopeHIDMatched, context)
            IOHIDManagerRegisterDeviceRemovalCallback(manager, linkScopeHIDRemoved, context)
            IOHIDManagerScheduleWithRunLoop(
                manager,
                CFRunLoopGetMain(),
                CFRunLoopMode.defaultMode.rawValue
            )
            // Device matching and removal notifications do not require LinkScope
            // to open input reports. Avoiding IOHIDManagerOpen keeps this public
            // inspector outside Input Monitoring permission and high-frequency
            // input delivery.
            self.emitter.yield(.status(ProviderStatus(
                providerID: self.descriptor.id,
                state: .running,
                message: "Device lifecycle and properties only; input reports remain unopened"
            )))
            #if canImport(CoreHID)
            self.emitter.yield(self.systemObservation(path: "framework.coreHIDAvailable", value: .bool(true)))
            #else
            self.emitter.yield(self.systemUnavailable(
                path: "framework.coreHIDAvailable",
                availability: .unsupported(detail: "CoreHID is not present in this SDK")
            ))
            #endif
        }
    }

    public func stop() async {
        await MainActor.run {
            guard let manager else { return }
            IOHIDManagerUnscheduleFromRunLoop(
                manager,
                CFRunLoopGetMain(),
                CFRunLoopMode.defaultMode.rawValue
            )
            self.manager = nil
        }
        emitter.yield(.status(ProviderStatus(providerID: descriptor.id, state: .stopped)))
        emitter.finish()
    }

    fileprivate func deviceMatched(_ device: IOHIDDevice) {
        let transport = transportIdentity(for: device)
        emitDeviceProperties(device, transport: transport)
        emitter.yield(.timeline(TimelineEvent(
            providerID: descriptor.id,
            kind: .deviceConnected,
            message: "HID device appeared: \(transport.displayName ?? "Unknown HID device")"
        )))
    }

    fileprivate func deviceRemoved(_ device: IOHIDDevice) {
        let transport = transportIdentity(for: device)
        emitter.yield(ProviderObservationFactory.available(
            transport: transport,
            path: "connection.present",
            value: .bool(false)
        ))
        if transport.connectionProtocol == .bluetooth {
            emitter.yield(ProviderObservationFactory.available(
                transport: transport,
                path: "connection.connected",
                value: .bool(false)
            ))
        }
        emitter.yield(.timeline(TimelineEvent(
            providerID: descriptor.id,
            kind: .deviceDisconnected,
            message: "HID device disappeared: \(transport.displayName ?? "Unknown HID device")"
        )))
    }

    private func emitDeviceProperties(_ device: IOHIDDevice, transport: TransportIdentity) {
        emitter.yield(ProviderObservationFactory.available(
            transport: transport,
            path: "connection.present",
            value: .bool(true)
        ))
        if transport.connectionProtocol == .bluetooth {
            emitter.yield(ProviderObservationFactory.available(
                transport: transport,
                path: "connection.connected",
                value: .bool(true)
            ))
        } else {
            emitter.yield(ProviderObservationFactory.unavailable(
                transport: transport,
                path: "connection.connected",
                availability: .notExposed(
                    detail: "HID presence does not prove an active wireless connection for this transport"
                )
            ))
        }

        let properties: [(String, String, DataSensitivity)] = [
            (kIOHIDProductKey as String, "identity.product", .ordinary),
            (kIOHIDManufacturerKey as String, "identity.manufacturer", .ordinary),
            (kIOHIDSerialNumberKey as String, "identity.serialNumber", .deviceIdentifier),
            (kIOHIDTransportKey as String, "transport.name", .ordinary),
            (kIOHIDVendorIDKey as String, "usb.vendorID", .ordinary),
            (kIOHIDProductIDKey as String, "usb.productID", .ordinary),
            (kIOHIDLocationIDKey as String, "registry.locationID", .deviceIdentifier),
            (kIOHIDBuiltInKey as String, "device.builtIn", .ordinary),
            (kIOHIDPrimaryUsagePageKey as String, "hid.primaryUsagePage", .ordinary),
            (kIOHIDPrimaryUsageKey as String, "hid.primaryUsage", .ordinary),
            (kIOHIDReportIntervalKey as String, "hid.reportInterval", .ordinary)
        ]

        for (key, path, sensitivity) in properties {
            if let value = IOHIDDeviceGetProperty(device, key as CFString) {
                emitter.yield(ProviderObservationFactory.available(
                    transport: transport,
                    path: path,
                    value: RawValue.from(propertyListValue: value),
                    sensitivity: sensitivity
                ))
            } else {
                emitter.yield(ProviderObservationFactory.unavailable(
                    transport: transport,
                    path: path,
                    availability: .notReported(detail: "IOHID did not report property \(key)"),
                    sensitivity: sensitivity
                ))
            }
        }
    }

    private func transportIdentity(for device: IOHIDDevice) -> TransportIdentity {
        let service = IOHIDDeviceGetService(device)
        var registryID: UInt64 = 0
        IORegistryEntryGetRegistryEntryID(service, &registryID)

        let physicalUniqueID = propertyString(device, key: kIOHIDPhysicalDeviceUniqueIDKey as String)
        let uniqueID = propertyString(device, key: kIOHIDUniqueIDKey as String)
        let serial = propertyString(device, key: kIOHIDSerialNumberKey as String)
        let product = propertyString(device, key: kIOHIDProductKey as String) ?? "HID Device"
        let transportName = propertyString(device, key: kIOHIDTransportKey as String)
        let locationID = propertyUInt64(device, key: kIOHIDLocationIDKey as String)
        let builtIn = propertyBool(device, key: kIOHIDBuiltInKey as String)
        let connectionProtocol = connectionProtocol(
            transportName: transportName,
            builtIn: builtIn
        )
        let rawIdentifier = registryID == 0
            ? (uniqueID ?? serial ?? physicalUniqueID ?? "object:\(ObjectIdentifier(device).hashValue)")
            : "registry:\(registryID)"

        return TransportIdentity(
            providerID: descriptor.id,
            kind: .coreHID,
            rawIdentifier: rawIdentifier,
            displayName: product,
            registryAncestryID: physicalAncestorID(for: service),
            vendorID: propertyUInt64(device, key: kIOHIDVendorIDKey as String),
            productID: propertyUInt64(device, key: kIOHIDProductIDKey as String),
            serialNumber: serial,
            physicalGroupIdentifier: physicalGroupIdentifier(
                physicalUniqueID: physicalUniqueID,
                serialNumber: serial,
                builtIn: builtIn,
                locationID: locationID,
                transportName: transportName,
                product: product
            ),
            correlationDomain: connectionProtocol == .bluetooth
                ? "bluetooth-accessory"
                : nil,
            connectionProtocol: connectionProtocol
        )
    }

    private func propertyString(_ device: IOHIDDevice, key: String) -> String? {
        IOHIDDeviceGetProperty(device, key as CFString) as? String
    }

    private func propertyUInt64(_ device: IOHIDDevice, key: String) -> UInt64? {
        (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.uint64Value
    }

    private func propertyBool(_ device: IOHIDDevice, key: String) -> Bool {
        (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.boolValue ?? false
    }

    private func connectionProtocol(
        transportName: String?,
        builtIn: Bool
    ) -> ConnectionProtocol {
        let value = transportName?.lowercased() ?? ""
        if value.contains("bluetooth") {
            return .bluetooth
        }
        if value.contains("usb") {
            return .usb
        }
        if builtIn || ["fifo", "spi", "i2c"].contains(where: value.contains) {
            return .builtIn
        }
        return .unknown
    }

    private func physicalGroupIdentifier(
        physicalUniqueID: String?,
        serialNumber: String?,
        builtIn: Bool,
        locationID: UInt64?,
        transportName: String?,
        product: String
    ) -> String? {
        if let physicalUniqueID, !physicalUniqueID.isEmpty {
            return "physical:\(physicalUniqueID)"
        }
        if let serialNumber, !serialNumber.isEmpty {
            return "serial:\(serialNumber)"
        }
        if builtIn, let locationID {
            return "built-in:\(transportName ?? "unknown"):\(locationID):\(product)"
        }
        return nil
    }

    private func physicalAncestorID(for service: io_service_t) -> String? {
        var current = service
        var ownsCurrent = false
        defer {
            if ownsCurrent {
                IOObjectRelease(current)
            }
        }

        for _ in 0..<6 {
            var parent: io_registry_entry_t = 0
            guard IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent) == KERN_SUCCESS,
                  parent != 0 else {
                return nil
            }
            if ownsCurrent {
                IOObjectRelease(current)
            }
            current = parent
            ownsCurrent = true

            if isPhysicalHIDContainer(current) {
                var registryID: UInt64 = 0
                if IORegistryEntryGetRegistryEntryID(current, &registryID) == KERN_SUCCESS,
                   registryID != 0 {
                    return "ioregistry:\(registryID)"
                }
            }
        }
        return nil
    }

    private func isPhysicalHIDContainer(_ entry: io_registry_entry_t) -> Bool {
        let classes = [
            "AppleHIDTransportDevice",
            "IOUSBHostDevice",
            "IOUSBDevice",
            "IOBluetoothHIDDriver",
            "IOBluetoothHIDDevice",
            "BTHIDDevice"
        ]
        if classes.contains(where: { IOObjectConformsTo(entry, $0) != 0 }) {
            return true
        }
        let identityKeys = [
            kIOHIDPhysicalDeviceUniqueIDKey as String,
            "BluetoothDeviceAddress",
            "USB Serial Number"
        ]
        return identityKeys.contains { key in
            guard let value = IORegistryEntryCreateCFProperty(
                entry,
                key as CFString,
                kCFAllocatorDefault,
                0
            ) else {
                return false
            }
            value.release()
            return true
        }
    }

    private func systemTransport() -> TransportIdentity {
        TransportIdentity(
            providerID: descriptor.id,
            kind: .system,
            rawIdentifier: "this-mac-corehid",
            displayName: "This Mac"
        )
    }

    private func systemObservation(path: String, value: RawValue) -> ProviderEvent {
        ProviderObservationFactory.available(transport: systemTransport(), path: path, value: value)
    }

    private func systemUnavailable(
        path: String,
        availability: ParameterAvailability
    ) -> ProviderEvent {
        ProviderObservationFactory.unavailable(
            transport: systemTransport(),
            path: path,
            availability: availability
        )
    }
}

private let linkScopeHIDMatched: IOHIDDeviceCallback = { context, _, _, device in
    guard let context else { return }
    Unmanaged<CoreHIDProvider>.fromOpaque(context).takeUnretainedValue().deviceMatched(device)
}

private let linkScopeHIDRemoved: IOHIDDeviceCallback = { context, _, _, device in
    guard let context else { return }
    Unmanaged<CoreHIDProvider>.fromOpaque(context).takeUnretainedValue().deviceRemoved(device)
}
