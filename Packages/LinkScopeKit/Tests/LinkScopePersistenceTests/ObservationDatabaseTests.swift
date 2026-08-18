import Foundation
import LinkScopeCore
import Testing
@testable import LinkScopePersistence

private func makeDatabase() throws -> (ObservationDatabase, URL) {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LinkScopeTests-\(UUID().uuidString)", isDirectory: true)
    let url = directory.appendingPathComponent("observations.sqlite3")
    let keys = try DatabaseKeyMaterial(masterKeyData: Data(repeating: 0xA5, count: 32))
    return (try ObservationDatabase(url: url, keyMaterial: keys), url)
}

private func makeResolvedObservation() -> ResolvedObservation {
    let fixtureDate = Date(timeIntervalSince1970: 1_700_000_000.125)
    let transport = TransportIdentity(
        providerID: "unit.provider",
        kind: .system,
        rawIdentifier: "SECRET-DEVICE-123",
        displayName: "Private Fixture",
        vendorID: 1452,
        productID: 123,
        serialNumber: "SERIAL-SECRET"
    )
    let physical = PhysicalAccessoryIdentity(displayName: "Private Fixture", createdAt: fixtureDate)
    let observation = AccessoryObservation.available(
        transport: transport,
        path: "raw.secret",
        value: .string("TOP-SECRET-PAYLOAD"),
        sensitivity: .credentialMaterial,
        timestamp: fixtureDate
    )
    return ResolvedObservation(
        observation: observation,
        identity: ResolvedIdentity(
            physicalAccessory: physical,
            transportIdentity: transport,
            resolution: .independent
        )
    )
}

@Test func encryptedPayloadIsQueryableWithoutPlaintext() async throws {
    let (database, url) = try makeDatabase()
    let original = makeResolvedObservation()

    try await database.persist(original)
    let results = try await database.observations(matching: ObservationQuery(
        providerID: "unit.provider",
        parameterPath: "raw.secret"
    ))
    try await database.checkpoint()

    #expect(results == [original])
    #expect(try await database.schemaVersion() == ObservationDatabase.currentSchemaVersion)

    let databaseBytes = try Data(contentsOf: url)
    let databaseText = String(decoding: databaseBytes, as: UTF8.self)
    #expect(!databaseText.contains("SECRET-DEVICE-123"))
    #expect(!databaseText.contains("SERIAL-SECRET"))
    #expect(!databaseText.contains("TOP-SECRET-PAYLOAD"))
}

@Test func migrationsAreSafeToReopen() async throws {
    let (database, url) = try makeDatabase()
    #expect(try await database.schemaVersion() == ObservationDatabase.currentSchemaVersion)

    let keys = try DatabaseKeyMaterial(masterKeyData: Data(repeating: 0xA5, count: 32))
    let reopened = try ObservationDatabase(url: url, keyMaterial: keys)
    #expect(try await reopened.schemaVersion() == ObservationDatabase.currentSchemaVersion)
}

@Test func snapshotArchiveRoundTripsEveryAvailability() throws {
    let fixtureDate = Date(timeIntervalSince1970: 1_700_000_000.125)
    let physical = PhysicalAccessoryIdentity(displayName: "Fixture", createdAt: fixtureDate)
    let transport = TransportIdentity(
        providerID: "unit",
        kind: .system,
        rawIdentifier: "fixture"
    )
    let states: [ParameterAvailability] = [
        .available,
        .notExposed(detail: nil),
        .notReported(detail: nil),
        .permissionDenied(detail: nil),
        .unsupported(detail: nil),
        .stale(lastObservedAt: .distantPast, detail: nil),
        .providerFailure(code: "fixture", detail: "failure")
    ]
    let observations = states.enumerated().map { index, state in
        ResolvedObservation(
            observation: AccessoryObservation(
                timestamp: fixtureDate,
                transportIdentity: transport,
                parameterPath: ParameterPath(rawValue: "fixture.\(index)"),
                value: state.code == .available ? .bool(true) : nil,
                availability: state
            ),
            identity: ResolvedIdentity(
                physicalAccessory: physical,
                transportIdentity: transport,
                resolution: .independent
            )
        )
    }
    let original = SnapshotArchive(
        name: "Fixture snapshot",
        createdAt: fixtureDate,
        edition: .full,
        accessories: [physical],
        observations: observations,
        providerStatuses: [],
        timeline: []
    )

    let data = try SnapshotArchiveCodec.encode(original)
    let decoded = try SnapshotArchiveCodec.decode(data)
    #expect(decoded == original)
}

@Test func developmentFixturesCannotEnterPersistentDeviceData() async throws {
    let (database, _) = try makeDatabase()
    let physical = PhysicalAccessoryIdentity(displayName: "Legacy Mock")
    let transport = TransportIdentity(
        providerID: "mock.bluetooth",
        kind: .mock,
        rawIdentifier: "mock-device"
    )
    let resolved = ResolvedObservation(
        observation: .available(
            transport: transport,
            path: "connection.connected",
            value: .bool(true)
        ),
        identity: ResolvedIdentity(
            physicalAccessory: physical,
            transportIdentity: transport,
            resolution: .independent
        )
    )
    let archive = SnapshotArchive(
        name: "Legacy fixture snapshot",
        edition: .full,
        accessories: [physical],
        observations: [resolved],
        providerStatuses: [ProviderStatus(providerID: "mock.bluetooth", state: .running)],
        timeline: [TimelineEvent(providerID: "mock.bluetooth", kind: .deviceConnected, message: "fixture")]
    )

    try await database.persist(resolved)
    try await database.saveSnapshot(archive)

    #expect(try await database.observations().isEmpty)
    let storedSnapshots = try await database.snapshots()
    let stored = try #require(storedSnapshots.first)
    #expect(stored.accessories.isEmpty)
    #expect(stored.observations.isEmpty)
    #expect(stored.providerStatuses.isEmpty)
    #expect(stored.timeline.isEmpty)
}
