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

@Test func diagnosticRunGapRuleAndSessionQueryRoundTrip() async throws {
    let (database, url) = try makeDatabase()
    // The database intentionally stores Codable dates at millisecond precision.
    // Keep round-trip fixtures on that boundary so equality tests the payload
    // rather than sub-millisecond precision that is not part of the format.
    let fixtureDate = Date(timeIntervalSince1970: 1_700_000_000.125)
    let original = makeResolvedObservation()
    let source = DiagnosticSource(
        id: WidgetSourceID(observationIdentity: original.observationIdentity),
        accessoryID: original.identity.physicalAccessory.id,
        transportID: original.identity.transportIdentity.id,
        providerID: original.observation.transportIdentity.providerID,
        parameterPath: original.observation.parameterPath,
        displayName: "Fixture RSSI",
        operation: .sample
    )
    let run = DiagnosticRun(
        name: "Shipping Diagnostic",
        purpose: "Verify a real session",
        createdAt: fixtureDate,
        startedAt: fixtureDate,
        plannedDuration: 300,
        state: .running,
        sources: [source],
        samplingPolicy: .fixedInterval(seconds: 5)
    )
    let observation = AccessoryObservation(
        timestamp: fixtureDate.addingTimeInterval(2),
        transportIdentity: original.observation.transportIdentity,
        parameterPath: original.observation.parameterPath,
        value: .signedInt(-42),
        availability: .available,
        sessionID: run.id
    )
    let resolved = ResolvedObservation(observation: observation, identity: original.identity)
    var gap = DiagnosticGap(
        sessionID: run.id,
        startedAt: fixtureDate.addingTimeInterval(1),
        reason: .systemSleep
    )
    let rule = RuleDefinition(
        name: "Weak signal",
        sourceID: source.id,
        predicate: .numericBelow(-80)
    )
    let olderTrigger = RuleTrigger(
        ruleID: rule.id,
        triggeredAt: fixtureDate.addingTimeInterval(3),
        summary: "Weak signal: -90"
    )
    let latestTrigger = RuleTrigger(
        ruleID: rule.id,
        observationID: resolved.id,
        triggeredAt: fixtureDate.addingTimeInterval(9),
        summary: "Weak signal: -91"
    )

    try await database.saveDiagnosticRun(run)
    try await database.persist(resolved)
    try await database.saveDiagnosticGap(gap)
    gap.endedAt = fixtureDate.addingTimeInterval(8)
    try await database.saveDiagnosticGap(gap)
    try await database.saveRule(rule)
    try await database.saveRuleTrigger(olderTrigger)
    try await database.saveRuleTrigger(latestTrigger)

    #expect(try await database.diagnosticRuns() == [run])
    #expect(try await database.diagnosticGaps(sessionID: run.id) == [gap])
    #expect(try await database.rules() == [rule])
    #expect(try await database.ruleTriggers(ruleID: rule.id) == [latestTrigger, olderTrigger])
    #expect(try await database.latestRuleTriggerDates()[rule.id] == latestTrigger.triggeredAt)
    #expect(try await database.observations(
        matching: ObservationQuery(sessionID: run.id)
    ) == [resolved])

    let keys = try DatabaseKeyMaterial(masterKeyData: Data(repeating: 0xA5, count: 32))
    let reopened = try ObservationDatabase(url: url, keyMaterial: keys)
    #expect(try await reopened.diagnosticGaps(sessionID: run.id) == [gap])
    #expect(try await reopened.latestRuleTriggerDates()[rule.id] == latestTrigger.triggeredAt)
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

@Test func encryptedDashboardCRUDSurvivesReopenWithDeterministicOrdering() async throws {
    let (database, url) = try makeDatabase()
    let privateName = "Alpha DASHBOARD-NAME-ULTRAVIOLET-SECRET"
    let alphaID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    let betaID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
    let alpha = DashboardDocument(
        id: alphaID,
        name: privateName,
        widgets: [
            DashboardWidget(
                kind: .timeSeries,
                sourceIDs: [],
                placement: GridPlacement(
                    column: 10,
                    row: 0,
                    columnSpan: 6,
                    rowSpan: 4
                ),
                configuration: [
                    "privateConfiguration": .string("DASHBOARD-SUPER-SECRET")
                ]
            )
        ]
    )
    let beta = DashboardDocument(id: betaID, name: "beta")

    let savedAlpha = try await database.saveDashboard(alpha)
    _ = try await database.saveDashboard(beta)

    #expect(savedAlpha.columns == 12)
    #expect(savedAlpha.widgets[0].placement.column == 6)
    #expect(try await database.dashboards().map(\.id) == [alphaID, betaID])
    #expect(try await database.dashboard(id: alphaID) == savedAlpha)

    try await database.checkpoint()
    let databaseText = String(decoding: try Data(contentsOf: url), as: UTF8.self)
    #expect(!databaseText.contains(privateName))
    #expect(!databaseText.contains("DASHBOARD-SUPER-SECRET"))

    let keys = try DatabaseKeyMaterial(masterKeyData: Data(repeating: 0xA5, count: 32))
    let reopened = try ObservationDatabase(url: url, keyMaterial: keys)
    #expect(try await reopened.dashboard(id: alphaID) == savedAlpha)

    #expect(try await reopened.deleteDashboard(id: alphaID))
    #expect(!(try await reopened.deleteDashboard(id: alphaID)))
    #expect(try await reopened.dashboard(id: alphaID) == nil)
}

@Test func dashboardCodecPreservesFutureWidgetKindsAndOpaqueFields() throws {
    let data = Data(
        """
        {
          "schemaVersion": 9,
          "id": "20000000-0000-0000-0000-000000000001",
          "name": "Future Dashboard",
          "columns": 24,
          "futureDocument": {"accent": "ultraviolet", "revision": 42},
          "widgets": [
            {
              "id": "20000000-0000-0000-0000-000000000002",
              "kind": "futureSpectrum",
              "sourceIDs": [],
              "placement": {
                "column": 1,
                "row": 2,
                "columnSpan": 5,
                "rowSpan": 3,
                "zIndex": 7
              },
              "configuration": {
                "palette": {"futureGradient": {"stops": ["violet", "infrared"]}}
              },
              "futureWidget": {"flags": [true, "opaque"], "minimum": -12.5}
            }
          ]
        }
        """.utf8
    )

    let imported = try DashboardDocumentCodec.decode(data)
    let widget = try #require(imported.widgets.first)

    #expect(imported.schemaVersion == 9)
    #expect(imported.columns == 24)
    #expect(DashboardDocumentCodec.compatibility(of: imported) == .newer(9))
    #expect(widget.kind.rawValue == "futureSpectrum")
    #expect(!widget.kind.isSupported)
    #expect(widget.configuration.isEmpty)
    #expect(widget.opaqueConfiguration != nil)
    #expect(widget.placement.extensionFields["zIndex"] == .signedInteger(7))
    #expect(imported.extensionFields["futureDocument"] != nil)
    #expect(widget.extensionFields["futureWidget"] != nil)

    let exported = try DashboardDocumentCodec.encode(imported)
    let reimported = try DashboardDocumentCodec.decode(exported)
    #expect(reimported == imported)
}

@Test func newerDashboardSchemaPersistsWithoutCurrentLayoutRewrites() async throws {
    let (database, url) = try makeDatabase()
    let future = DashboardDocument(
        schemaVersion: DashboardDocument.currentSchemaVersion + 4,
        id: UUID(uuidString: "25000000-0000-0000-0000-000000000001")!,
        name: "Future Layout",
        columns: 24,
        widgets: [
            DashboardWidget(
                id: UUID(uuidString: "25000000-0000-0000-0000-000000000002")!,
                kind: DashboardWidget.Kind(rawValue: "futureSpectrum"),
                sourceIDs: [],
                placement: GridPlacement(
                    column: 18,
                    row: 0,
                    columnSpan: 6,
                    rowSpan: 5
                ),
                extensionFields: ["futureWidget": .string("opaque")]
            ),
            DashboardWidget(
                id: UUID(uuidString: "25000000-0000-0000-0000-000000000003")!,
                kind: .currentValue,
                sourceIDs: [],
                placement: GridPlacement(
                    column: 18,
                    row: 0,
                    columnSpan: 6,
                    rowSpan: 5
                )
            )
        ],
        extensionFields: ["futureLayout": .signedInteger(24)]
    )

    #expect(try await database.saveDashboard(future) == future)
    #expect(try await database.dashboard(id: future.id) == future)

    let keys = try DatabaseKeyMaterial(masterKeyData: Data(repeating: 0xA5, count: 32))
    let reopened = try ObservationDatabase(url: url, keyMaterial: keys)
    #expect(try await reopened.dashboard(id: future.id) == future)
}

@Test func widgetSourceHistoryQueryUsesTransportAndPathIdentity() async throws {
    let (database, _) = try makeDatabase()
    let timestamp = Date(timeIntervalSince1970: 1_700_000_100)
    let physical = PhysicalAccessoryIdentity(
        id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
        displayName: "History Fixture",
        createdAt: timestamp
    )
    let targetTransport = TransportIdentity(
        id: UUID(uuidString: "30000000-0000-0000-0000-000000000002")!,
        providerID: "unit.dashboard",
        kind: .system,
        rawIdentifier: "target"
    )
    let otherTransport = TransportIdentity(
        id: UUID(uuidString: "30000000-0000-0000-0000-000000000003")!,
        providerID: "unit.dashboard",
        kind: .system,
        rawIdentifier: "other"
    )
    let path = ParameterPath(rawValue: "radio:rssi")

    func resolved(
        id: UUID,
        transport: TransportIdentity,
        value: Int64
    ) -> ResolvedObservation {
        ResolvedObservation(
            observation: AccessoryObservation(
                id: id,
                timestamp: timestamp,
                transportIdentity: transport,
                parameterPath: path,
                value: .signedInt(value),
                availability: .available
            ),
            identity: ResolvedIdentity(
                physicalAccessory: physical,
                transportIdentity: transport,
                resolution: .independent
            )
        )
    }

    let target = resolved(
        id: UUID(uuidString: "30000000-0000-0000-0000-000000000004")!,
        transport: targetTransport,
        value: -48
    )
    let other = resolved(
        id: UUID(uuidString: "30000000-0000-0000-0000-000000000005")!,
        transport: otherTransport,
        value: -80
    )
    try await database.persist(target)
    try await database.persist(other)

    let sourceID = WidgetSourceID(observationIdentity: target.observationIdentity)
    let query = try #require(ObservationQuery(widgetSourceID: sourceID, limit: 300))
    let results = try await database.observations(matching: query)

    #expect(sourceID.observationIdentity == target.observationIdentity)
    #expect(query.transportIdentityID == targetTransport.id)
    #expect(query.parameterPath == path)
    #expect(results == [target])
    #expect(ObservationQuery(widgetSourceID: WidgetSourceID(rawValue: "opaque")) == nil)
}
