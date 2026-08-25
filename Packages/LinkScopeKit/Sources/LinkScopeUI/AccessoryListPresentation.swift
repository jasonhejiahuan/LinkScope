import Foundation
import LinkScopeCore

enum AccessoryListGrouping: String, CaseIterable, Identifiable {
    case connection
    case connectionProtocol
    case none

    var id: String { rawValue }
}

enum AccessoryListSortOrder: String, CaseIterable, Identifiable {
    case nameAscending
    case nameDescending
    case connection
    case connectionProtocol
    case recentlyUpdated

    var id: String { rawValue }
}

struct AccessoryListEntry: Identifiable {
    let accessory: PhysicalAccessoryIdentity
    let transports: [TransportIdentity]
    let summary: AccessoryConnectionSummary
    let bluetoothClassOfDevice: UInt64?

    var id: UUID { accessory.id }
}

struct AccessoryListSection: Identifiable {
    enum Identifier: Hashable {
        case connection(AccessoryConnectionState)
        case connectionProtocol(ConnectionProtocol)
        case all
    }

    let id: Identifier
    let entries: [AccessoryListEntry]
}

enum AccessoryListPresentation {
    static func entries(
        snapshot: HubSnapshot,
        liveSessionStartedAt: Date,
        searchText: String,
        sortOrder: AccessoryListSortOrder
    ) -> [AccessoryListEntry] {
        let summaries = AccessoryConnectionClassifier.summaries(
            snapshot: snapshot,
            observedAfter: liveSessionStartedAt
        )
        let bluetoothClasses = bluetoothClassesByAccessory(in: snapshot)
        return snapshot.accessories
            .filter {
                searchText.isEmpty
                    || $0.displayName.localizedCaseInsensitiveContains(searchText)
            }
            .map { accessory in
                AccessoryListEntry(
                    accessory: accessory,
                    transports: snapshot.transports[accessory.id] ?? [],
                    summary: summaries[accessory.id] ?? AccessoryConnectionSummary(
                        state: .inactive,
                        protocols: [.unknown],
                        latestUpdate: nil
                    ),
                    bluetoothClassOfDevice: bluetoothClasses[accessory.id]
                )
            }
            .sorted(by: comparator(for: sortOrder))
    }

    static func sections(
        entries: [AccessoryListEntry],
        grouping: AccessoryListGrouping
    ) -> [AccessoryListSection] {
        switch grouping {
        case .connection:
            return AccessoryConnectionState.allCases.compactMap { state in
                let values = entries.filter { $0.summary.state == state }
                return values.isEmpty
                    ? nil
                    : AccessoryListSection(id: .connection(state), entries: values)
            }
        case .connectionProtocol:
            return ConnectionProtocol.allCases.compactMap { connectionProtocol in
                let values = entries.filter {
                    $0.summary.primaryProtocol == connectionProtocol
                }
                return values.isEmpty
                    ? nil
                    : AccessoryListSection(
                        id: .connectionProtocol(connectionProtocol),
                        entries: values
                    )
            }
        case .none:
            return entries.isEmpty
                ? []
                : [AccessoryListSection(id: .all, entries: entries)]
        }
    }

    private static func bluetoothClassesByAccessory(
        in snapshot: HubSnapshot
    ) -> [UUID: UInt64] {
        var values: [UUID: (timestamp: Date, value: UInt64)] = [:]
        for resolved in snapshot.observations
        where resolved.observation.parameterPath.rawValue == "bluetooth.classOfDevice" {
            guard case let .unsignedInt(value) = resolved.observation.value else {
                continue
            }
            let accessoryID = resolved.identity.physicalAccessory.id
            if values[accessoryID].map({ $0.timestamp > resolved.observation.timestamp }) != true {
                values[accessoryID] = (resolved.observation.timestamp, value)
            }
        }
        return values.mapValues(\.value)
    }

    private static func comparator(
        for order: AccessoryListSortOrder
    ) -> (AccessoryListEntry, AccessoryListEntry) -> Bool {
        { lhs, rhs in
            switch order {
            case .nameAscending:
                return nameAscending(lhs, rhs)
            case .nameDescending:
                let comparison = lhs.accessory.displayName.localizedStandardCompare(
                    rhs.accessory.displayName
                )
                if comparison == .orderedSame {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return comparison == .orderedDescending
            case .connection:
                if lhs.summary.state.sortRank != rhs.summary.state.sortRank {
                    return lhs.summary.state.sortRank < rhs.summary.state.sortRank
                }
                return nameAscending(lhs, rhs)
            case .connectionProtocol:
                let lhsRank = protocolRank(lhs.summary.primaryProtocol)
                let rhsRank = protocolRank(rhs.summary.primaryProtocol)
                if lhsRank != rhsRank {
                    return lhsRank < rhsRank
                }
                return nameAscending(lhs, rhs)
            case .recentlyUpdated:
                let lhsDate = lhs.summary.latestUpdate ?? .distantPast
                let rhsDate = rhs.summary.latestUpdate ?? .distantPast
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
                return nameAscending(lhs, rhs)
            }
        }
    }

    private static func nameAscending(
        _ lhs: AccessoryListEntry,
        _ rhs: AccessoryListEntry
    ) -> Bool {
        let comparison = lhs.accessory.displayName.localizedStandardCompare(
            rhs.accessory.displayName
        )
        if comparison == .orderedSame {
            return lhs.id.uuidString < rhs.id.uuidString
        }
        return comparison == .orderedAscending
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
