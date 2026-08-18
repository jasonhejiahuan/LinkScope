import Foundation
import Testing
@testable import LinkScopeCore

@Test func connectionSummaryUsesOnlyCurrentSessionEvidence() {
    let sessionStart = Date(timeIntervalSince1970: 2_000)
    let accessory = PhysicalAccessoryIdentity(displayName: "Headphones")
    let transport = TransportIdentity(
        providerID: "iobluetooth",
        kind: .ioBluetooth,
        rawIdentifier: "headphones",
        displayName: "Headphones",
        correlationDomain: "bluetooth-accessory",
        connectionProtocol: .bluetooth
    )
    let identity = ResolvedIdentity(
        physicalAccessory: accessory,
        transportIdentity: transport,
        resolution: .independent
    )
    let staleConnected = ResolvedObservation(
        observation: .available(
            transport: transport,
            path: "connection.connected",
            value: .bool(true),
            timestamp: sessionStart.addingTimeInterval(-10)
        ),
        identity: identity
    )
    let snapshot = HubSnapshot(
        accessories: [accessory],
        transports: [accessory.id: [transport]],
        observations: [staleConnected]
    )

    let summary = AccessoryConnectionClassifier.summary(
        for: accessory.id,
        snapshot: snapshot,
        observedAfter: sessionStart
    )

    #expect(summary.state == .inactive)
    #expect(summary.primaryProtocol == .bluetooth)
}

@Test func pairedFalseConnectionIsSavedNotConnected() {
    let sessionStart = Date(timeIntervalSince1970: 2_000)
    let accessory = PhysicalAccessoryIdentity(displayName: "Headphones")
    let transport = TransportIdentity(
        providerID: "iobluetooth",
        kind: .ioBluetooth,
        rawIdentifier: "headphones",
        displayName: "Headphones",
        connectionProtocol: .bluetooth
    )
    let identity = ResolvedIdentity(
        physicalAccessory: accessory,
        transportIdentity: transport,
        resolution: .independent
    )
    let timestamp = sessionStart.addingTimeInterval(1)
    let disconnected = ResolvedObservation(
        observation: .available(
            transport: transport,
            path: "connection.connected",
            value: .bool(false),
            timestamp: timestamp
        ),
        identity: identity
    )
    let paired = ResolvedObservation(
        observation: .available(
            transport: transport,
            path: "bluetooth.paired",
            value: .bool(true),
            timestamp: timestamp
        ),
        identity: identity
    )
    let snapshot = HubSnapshot(
        accessories: [accessory],
        transports: [accessory.id: [transport]],
        observations: [disconnected, paired]
    )

    let summary = AccessoryConnectionClassifier.summary(
        for: accessory.id,
        snapshot: snapshot,
        observedAfter: sessionStart
    )

    #expect(summary.state == .saved)
}

@Test func audioObjectLivenessIsNotAccessoryConnectionEvidence() {
    let sessionStart = Date(timeIntervalSince1970: 2_000)
    let accessory = PhysicalAccessoryIdentity(displayName: "Audio Endpoint")
    let transport = TransportIdentity(
        providerID: "coreaudio",
        kind: .coreAudio,
        rawIdentifier: "audio-endpoint",
        displayName: "Audio Endpoint",
        connectionProtocol: .virtual
    )
    let identity = ResolvedIdentity(
        physicalAccessory: accessory,
        transportIdentity: transport,
        resolution: .independent
    )
    let alive = ResolvedObservation(
        observation: .available(
            transport: transport,
            path: "audio.deviceAlive",
            value: .bool(true),
            timestamp: sessionStart.addingTimeInterval(1)
        ),
        identity: identity
    )
    let snapshot = HubSnapshot(
        accessories: [accessory],
        transports: [accessory.id: [transport]],
        observations: [alive]
    )

    let summary = AccessoryConnectionClassifier.summary(
        for: accessory.id,
        snapshot: snapshot,
        observedAfter: sessionStart
    )

    #expect(summary.state == .inactive)
}
