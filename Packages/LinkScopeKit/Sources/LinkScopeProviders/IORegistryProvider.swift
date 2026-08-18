import Foundation
@preconcurrency import IOKit
import LinkScopeCore

public final class IORegistryProvider: @unchecked Sendable, AccessoryProvider {
    public let descriptor = ProviderDescriptor(
        id: PublicProviderIDs.ioRegistry,
        displayName: "IORegistry (Public)",
        transportKind: .ioRegistry,
        capabilities: [
            ProviderCapability(id: "ioregistry.bluetooth-controller.read", operation: .read)
        ]
    )

    private let emitter = ProviderEventEmitter()

    public init() {}

    public func events() async -> AsyncStream<ProviderEvent> {
        emitter.stream()
    }

    public func start() async {
        emitter.yield(.status(ProviderStatus(providerID: descriptor.id, state: .starting)))
        readBluetoothControllers()
        emitter.yield(.status(ProviderStatus(
            providerID: descriptor.id,
            state: .running,
            message: "Bounded initial public IORegistry read; no polling"
        )))
    }

    public func stop() async {
        emitter.yield(.status(ProviderStatus(providerID: descriptor.id, state: .stopped)))
        emitter.finish()
    }

    private func readBluetoothControllers() {
        var iterator: io_iterator_t = 0
        let status = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOBluetoothHCIController"),
            &iterator
        )
        guard status == KERN_SUCCESS else {
            emitter.yield(.status(ProviderStatus(
                providerID: descriptor.id,
                state: .failed,
                message: "IOServiceGetMatchingServices returned \(status)"
            )))
            return
        }
        defer { IOObjectRelease(iterator) }

        var found = false
        while case let service = IOIteratorNext(iterator), service != 0 {
            found = true
            defer { IOObjectRelease(service) }
            emit(service)
        }

        if !found {
            let transport = TransportIdentity(
                providerID: descriptor.id,
                kind: .system,
                rawIdentifier: "this-mac-ioregistry",
                displayName: "This Mac"
            )
            emitter.yield(ProviderObservationFactory.unavailable(
                transport: transport,
                path: "registry.bluetoothController",
                availability: .notReported(detail: "No public IOBluetoothHCIController service was found")
            ))
        }
    }

    private func emit(_ service: io_registry_entry_t) {
        var registryID: UInt64 = 0
        IORegistryEntryGetRegistryEntryID(service, &registryID)
        var pathBuffer = [CChar](repeating: 0, count: 4_096)
        let pathStatus = IORegistryEntryGetPath(service, kIOServicePlane, &pathBuffer)
        let pathBytes = pathBuffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        let path = pathStatus == KERN_SUCCESS
            ? String(decoding: pathBytes, as: UTF8.self)
            : "registry:\(registryID)"

        var propertiesRef: Unmanaged<CFMutableDictionary>?
        let propertiesStatus = IORegistryEntryCreateCFProperties(
            service,
            &propertiesRef,
            kCFAllocatorDefault,
            0
        )
        let properties = propertiesStatus == KERN_SUCCESS
            ? (propertiesRef?.takeRetainedValue() as? [String: Any] ?? [:])
            : [:]
        let name = (properties["ProductName"] as? String)
            ?? (properties["IOClass"] as? String)
            ?? "Bluetooth Controller"
        let transport = TransportIdentity(
            providerID: descriptor.id,
            kind: .ioRegistry,
            rawIdentifier: "registry:\(registryID)",
            displayName: name,
            registryAncestryID: path
        )

        emitter.yield(ProviderObservationFactory.available(
            transport: transport,
            path: "registry.entryID",
            value: .unsignedInt(registryID),
            sensitivity: .deviceIdentifier
        ))
        emitter.yield(ProviderObservationFactory.available(
            transport: transport,
            path: "registry.path",
            value: .string(path),
            sensitivity: .rawRegistry
        ))

        let allowlistedKeys = [
            "IOClass", "CFBundleIdentifier", "Transport", "VendorID", "ProductID",
            "ProductName", "FirmwareVersion", "LocationID", "Built-In"
        ]
        for key in allowlistedKeys {
            guard let value = properties[key] else { continue }
            emitter.yield(ProviderObservationFactory.available(
                transport: transport,
                path: "registry.properties.\(key)",
                value: RawValue.from(propertyListValue: value),
                sensitivity: .rawRegistry
            ))
        }
    }
}
