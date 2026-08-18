import Foundation
import Testing
@testable import LinkScopeCore

private actor RecordingSink: ObservationSink {
    private(set) var observations: [ResolvedObservation] = []
    private(set) var statuses: [ProviderStatus] = []
    private(set) var events: [TimelineEvent] = []

    func persist(_ observation: ResolvedObservation) {
        observations.append(observation)
    }

    func persist(_ status: ProviderStatus) {
        statuses.append(status)
    }

    func persist(_ event: TimelineEvent) {
        events.append(event)
    }
}

private actor TestAccessoryProvider: AccessoryProvider {
    nonisolated let descriptor = ProviderDescriptor(
        id: "unit-provider",
        displayName: "Unit Provider",
        transportKind: .system,
        capabilities: [ProviderCapability(id: "unit.read", operation: .read)]
    )
    private var continuation: AsyncStream<ProviderEvent>.Continuation?
    private var pendingEvents: [ProviderEvent]

    init(events: [ProviderEvent]) {
        pendingEvents = events
    }

    func events() -> AsyncStream<ProviderEvent> {
        AsyncStream { continuation in self.continuation = continuation }
    }

    func start() {
        continuation?.yield(.status(ProviderStatus(providerID: descriptor.id, state: .running)))
        pendingEvents.forEach { continuation?.yield($0) }
        pendingEvents.removeAll()
    }

    func stop() {
        continuation?.finish()
        continuation = nil
    }
}

@Test func testProviderFlowsThroughHub() async throws {
    let transport = TransportIdentity(
        providerID: "unit-provider",
        kind: .system,
        rawIdentifier: "fixture-1",
        displayName: "Fixture Mouse"
    )
    let observation = AccessoryObservation.available(
        transport: transport,
        path: "battery.level",
        value: .double(0.5)
    )
    let provider = TestAccessoryProvider(events: [.observation(observation)])
    let sink = RecordingSink()
    let hub = ObservationHub(providers: [provider], sink: sink)

    await hub.start()
    try await Task.sleep(for: .milliseconds(50))
    let snapshot = await hub.currentSnapshot()
    await hub.stop()

    #expect(snapshot.accessories.count == 1)
    #expect(snapshot.observations.count == 1)
    #expect(await sink.observations.count == 1)
}

@Test func providerOperationsContainNoControlSurface() {
    #expect(Set(ProviderOperation.allCases) == Set([.read, .observe, .sample, .diagnose]))
}

@Test func immediateDuplicateObservationsAreCoalesced() async throws {
    let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
    let transport = TransportIdentity(
        providerID: "unit-provider",
        kind: .system,
        rawIdentifier: "coalescing-fixture"
    )
    let first = AccessoryObservation.available(
        transport: transport,
        path: "connection.connected",
        value: .bool(true),
        timestamp: timestamp
    )
    let repeated = AccessoryObservation.available(
        transport: transport,
        path: "connection.connected",
        value: .bool(true),
        timestamp: timestamp.addingTimeInterval(1)
    )
    let provider = TestAccessoryProvider(events: [
        .observation(first),
        .observation(repeated)
    ])
    let hub = ObservationHub(providers: [provider])

    await hub.start()
    try await Task.sleep(for: .milliseconds(50))
    let snapshot = await hub.currentSnapshot()
    await hub.stop()

    #expect(snapshot.observations.count == 1)
    #expect(snapshot.history.count == 1)
    #expect(snapshot.observations.first?.observation.timestamp == repeated.timestamp)
}

@Test func hubProjectsGroupedTransportsAsOnePhysicalAccessory() async throws {
    let first = TransportIdentity(
        providerID: "unit-provider",
        kind: .system,
        rawIdentifier: "endpoint-one",
        displayName: "Composite Device",
        physicalGroupIdentifier: "physical-one"
    )
    let second = TransportIdentity(
        providerID: "unit-provider",
        kind: .system,
        rawIdentifier: "endpoint-two",
        displayName: "Composite Device",
        physicalGroupIdentifier: "physical-one"
    )
    let provider = TestAccessoryProvider(events: [
        .observation(.available(
            transport: first,
            path: "connection.present",
            value: .bool(true)
        )),
        .observation(.available(
            transport: second,
            path: "connection.present",
            value: .bool(true)
        ))
    ])
    let hub = ObservationHub(providers: [provider])

    await hub.start()
    try await Task.sleep(for: .milliseconds(50))
    let snapshot = await hub.currentSnapshot()
    await hub.stop()

    #expect(snapshot.accessories.count == 1)
    #expect(snapshot.transports[snapshot.accessories[0].id]?.count == 2)
}

@Test func hubRemapsRotatingAliasWhenCrossProviderAnchorArrives() async throws {
    let rotating = TransportIdentity(
        providerID: "public.iobluetooth",
        kind: .ioBluetooth,
        rawIdentifier: "rotating-address",
        displayName: "J-4ANC",
        correlationDomain: "bluetooth-accessory",
        crossProviderIdentifier: "bluetooth-address:111111111111",
        connectionProtocol: .bluetooth
    )
    let saved = TransportIdentity(
        providerID: "public.iobluetooth",
        kind: .ioBluetooth,
        rawIdentifier: "saved-address",
        displayName: "J-4ANC",
        correlationDomain: "bluetooth-accessory",
        crossProviderIdentifier: "bluetooth-address:542a433cab99",
        connectionProtocol: .bluetooth
    )
    let audio = TransportIdentity(
        providerID: "public.coreaudio",
        kind: .coreAudio,
        rawIdentifier: "54-2A-43-3C-AB-99::input",
        displayName: "J-4ANC",
        correlationDomain: "bluetooth-accessory",
        crossProviderIdentifier: "bluetooth-address:542a433cab99",
        connectionProtocol: .bluetooth
    )
    let provider = TestAccessoryProvider(events: [rotating, saved, audio].map {
        .observation(.available(
            transport: $0,
            path: "identity.name",
            value: .string("J-4ANC")
        ))
    })
    let hub = ObservationHub(providers: [provider])

    await hub.start()
    try await Task.sleep(for: .milliseconds(50))
    let snapshot = await hub.currentSnapshot()
    await hub.stop()

    #expect(snapshot.accessories.count == 1)
    #expect(snapshot.transports.values.first?.count == 3)
}

@Test func seededHistoryIsRemappedWhenNewerIdentityEvidenceUnifiesTransports() async {
    let firstPhysical = PhysicalAccessoryIdentity(displayName: "Internal Device")
    let secondPhysical = PhysicalAccessoryIdentity(displayName: "Internal Device")
    let firstLegacy = TransportIdentity(
        providerID: "hid",
        kind: .coreHID,
        rawIdentifier: "registry:1",
        displayName: "Internal Device"
    )
    let secondLegacy = TransportIdentity(
        providerID: "hid",
        kind: .coreHID,
        rawIdentifier: "registry:2",
        displayName: "Internal Device"
    )
    let firstCurrent = TransportIdentity(
        id: firstLegacy.id,
        providerID: "hid",
        kind: .coreHID,
        rawIdentifier: "registry:1",
        displayName: "Internal Device",
        physicalGroupIdentifier: "built-in:49"
    )
    let secondCurrent = TransportIdentity(
        id: secondLegacy.id,
        providerID: "hid",
        kind: .coreHID,
        rawIdentifier: "registry:2",
        displayName: "Internal Device",
        physicalGroupIdentifier: "built-in:49"
    )
    let oldTime = Date(timeIntervalSince1970: 1_000)
    let newTime = oldTime.addingTimeInterval(10)
    let observations = [
        resolvedFixture(
            physical: firstPhysical,
            transport: firstLegacy,
            path: "legacy.first",
            timestamp: oldTime
        ),
        resolvedFixture(
            physical: secondPhysical,
            transport: secondLegacy,
            path: "legacy.second",
            timestamp: oldTime
        ),
        resolvedFixture(
            physical: firstPhysical,
            transport: firstCurrent,
            path: "current.first",
            timestamp: newTime
        ),
        resolvedFixture(
            physical: secondPhysical,
            transport: secondCurrent,
            path: "current.second",
            timestamp: newTime
        )
    ]
    let hub = ObservationHub(providers: [])

    await hub.seed(observations: observations, statuses: [], timeline: [])
    let snapshot = await hub.currentSnapshot()

    #expect(snapshot.accessories.count == 1)
    #expect(snapshot.transports[snapshot.accessories[0].id]?.count == 2)
    #expect(Set(snapshot.history.map(\.identity.physicalAccessory.id)).count == 1)
}

private func resolvedFixture(
    physical: PhysicalAccessoryIdentity,
    transport: TransportIdentity,
    path: ParameterPath,
    timestamp: Date
) -> ResolvedObservation {
    ResolvedObservation(
        observation: .available(
            transport: transport,
            path: path,
            value: .bool(true),
            timestamp: timestamp
        ),
        identity: ResolvedIdentity(
            physicalAccessory: physical,
            transportIdentity: transport,
            resolution: .independent
        )
    )
}
