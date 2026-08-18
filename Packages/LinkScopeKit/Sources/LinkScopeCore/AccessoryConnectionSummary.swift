import Foundation

public enum AccessoryConnectionState: String, Codable, CaseIterable, Sendable {
    case connected
    case saved
    case disconnected
    case inactive

    public var sortRank: Int {
        switch self {
        case .connected: 0
        case .saved: 1
        case .disconnected: 2
        case .inactive: 3
        }
    }
}

public struct AccessoryConnectionSummary: Hashable, Sendable {
    public let state: AccessoryConnectionState
    public let protocols: [ConnectionProtocol]
    public let latestUpdate: Date?

    public init(
        state: AccessoryConnectionState,
        protocols: [ConnectionProtocol],
        latestUpdate: Date?
    ) {
        self.state = state
        self.protocols = protocols
        self.latestUpdate = latestUpdate
    }

    public var primaryProtocol: ConnectionProtocol {
        let priority: [ConnectionProtocol] = [
            .bluetooth, .usb, .network, .gameController,
            .builtIn, .virtual, .system, .unknown
        ]
        return priority.first(where: protocols.contains) ?? .unknown
    }
}

public enum AccessoryConnectionClassifier {
    private struct Evidence {
        var connected = false
        var paired = false
        var explicitlyDisconnected = false
        var latestUpdate: Date?
    }

    /// Produces current connection state from observations emitted in this app
    /// session. Persisted true values are inspector history, not proof that an
    /// accessory is still connected after the app relaunches.
    public static func summary(
        for accessoryID: UUID,
        snapshot: HubSnapshot,
        observedAfter liveSessionStartedAt: Date
    ) -> AccessoryConnectionSummary {
        summaries(
            snapshot: snapshot,
            observedAfter: liveSessionStartedAt
        )[accessoryID] ?? AccessoryConnectionSummary(
            state: .inactive,
            protocols: [.unknown],
            latestUpdate: nil
        )
    }

    /// Classifies the complete snapshot in one pass. This is the preferred path
    /// for sidebars and menu-bar counts because it avoids rescanning and copying
    /// the observation collection once per accessory.
    public static func summaries(
        snapshot: HubSnapshot,
        observedAfter liveSessionStartedAt: Date
    ) -> [UUID: AccessoryConnectionSummary] {
        var protocolSets: [UUID: Set<ConnectionProtocol>] = [:]
        for (accessoryID, transports) in snapshot.transports {
            protocolSets[accessoryID] = Set(
                transports.map(\.effectiveConnectionProtocol)
            )
        }

        var evidence: [UUID: Evidence] = [:]
        for resolved in snapshot.observations
        where resolved.observation.timestamp >= liveSessionStartedAt {
            let accessoryID = resolved.identity.physicalAccessory.id
            var value = evidence[accessoryID] ?? Evidence()
            if value.latestUpdate.map({ $0 < resolved.observation.timestamp }) ?? true {
                value.latestUpdate = resolved.observation.timestamp
            }
            guard resolved.observation.availability.code == .available else {
                evidence[accessoryID] = value
                continue
            }
            switch resolved.observation.parameterPath.rawValue {
            case "connection.connected":
                if resolved.observation.value == .bool(true) {
                    value.connected = true
                } else if resolved.observation.value == .bool(false) {
                    value.explicitlyDisconnected = true
                }
            case "bluetooth.paired":
                if resolved.observation.value == .bool(true) {
                    value.paired = true
                }
            default:
                break
            }
            evidence[accessoryID] = value
        }

        return Dictionary(uniqueKeysWithValues: snapshot.accessories.map { accessory in
            let value = evidence[accessory.id] ?? Evidence()
            let state: AccessoryConnectionState
            if value.connected {
                state = .connected
            } else if value.paired {
                state = .saved
            } else if value.explicitlyDisconnected {
                state = .disconnected
            } else {
                state = .inactive
            }
            let protocols = (protocolSets[accessory.id] ?? [])
                .sorted { protocolRank($0) < protocolRank($1) }
            return (
                accessory.id,
                AccessoryConnectionSummary(
                    state: state,
                    protocols: protocols.isEmpty ? [.unknown] : protocols,
                    latestUpdate: value.latestUpdate
                )
            )
        })
    }

    private static func protocolRank(_ value: ConnectionProtocol) -> Int {
        switch value {
        case .bluetooth: 0
        case .usb: 1
        case .network: 2
        case .gameController: 3
        case .builtIn: 4
        case .virtual: 5
        case .system: 6
        case .unknown: 7
        }
    }
}

public extension TransportIdentity {
    var effectiveConnectionProtocol: ConnectionProtocol {
        if let connectionProtocol {
            return connectionProtocol
        }
        switch kind {
        case .ioBluetooth, .coreBluetooth:
            return .bluetooth
        case .gameController:
            return .gameController
        case .ioRegistry, .system:
            return .system
        case .coreHID, .coreAudio, .mock:
            return .unknown
        }
    }
}
