import LinkScopeCore
import SwiftUI

struct AccessoryDetailView: View {
    let accessory: PhysicalAccessoryIdentity
    let snapshot: HubSnapshot
    let liveSessionStartedAt: Date
    @State private var selectedObservationID: UUID?

    private var transports: [TransportIdentity] {
        snapshot.transports[accessory.id] ?? []
    }

    private var latest: [ResolvedObservation] {
        snapshot.observations
            .filter { $0.identity.physicalAccessory.id == accessory.id }
            .sorted { $0.observation.parameterPath.rawValue < $1.observation.parameterPath.rawValue }
    }

    private var history: [ResolvedObservation] {
        snapshot.history.filter { $0.identity.physicalAccessory.id == accessory.id }
    }

    private var connectionSummary: AccessoryConnectionSummary {
        AccessoryConnectionClassifier.summary(
            for: accessory.id,
            snapshot: snapshot,
            observedAfter: liveSessionStartedAt
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            AccessoryHeader(
                accessory: accessory,
                transports: transports,
                observationCount: latest.count,
                connectionSummary: connectionSummary
            )
            Divider()
            TabView {
                AccessorySummaryView(transports: transports, latest: latest)
                    .tabItem {
                        Label {
                            LText("tab.summary")
                        } icon: {
                            Image(systemName: "rectangle.and.text.magnifyingglass")
                        }
                    }
                RawParameterView(rows: latest, selectedID: $selectedObservationID)
                    .tabItem {
                        Label {
                            LText("tab.rawParameters")
                        } icon: {
                            Image(systemName: "tablecells")
                        }
                    }
                ObservationHistoryView(rows: history)
                    .tabItem {
                        Label {
                            LText("tab.history")
                        } icon: {
                            Image(systemName: "chart.xyaxis.line")
                        }
                    }
            }
            .padding([.horizontal, .bottom])
        }
        .navigationTitle(accessory.displayName)
    }
}

private struct AccessoryHeader: View {
    @Environment(\.linkScopeLanguage) private var language
    let accessory: PhysicalAccessoryIdentity
    let transports: [TransportIdentity]
    let observationCount: Int
    let connectionSummary: AccessoryConnectionSummary

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "scope")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 48, height: 48)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(accessory.displayName)
                    .font(.title2.weight(.semibold))
                Text(L10n.formatted(
                    "detail.headerCounts",
                    language: language,
                    transports.count,
                    observationCount
                ))
                .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Label(
                        L10n.string(
                            "connectionState.\(connectionSummary.state.rawValue)",
                            language: language
                        ),
                        systemImage: "circle.fill"
                    )
                    .foregroundStyle(statusColor)
                    Text(L10n.string(
                        "connectionProtocol.\(connectionSummary.primaryProtocol.rawValue)",
                        language: language
                    ))
                    .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
            Spacer()
            Text(accessory.id.uuidString.lowercased())
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
        }
        .padding()
    }

    private var statusColor: Color {
        switch connectionSummary.state {
        case .connected: .green
        case .saved: .orange
        case .disconnected: .secondary
        case .inactive: .gray
        }
    }
}

private struct AccessorySummaryView: View {
    @Environment(\.linkScopeLanguage) private var language
    let transports: [TransportIdentity]
    let latest: [ResolvedObservation]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox {
                    VStack(spacing: 0) {
                        ForEach(transports) { transport in
                            TransportRow(transport: transport)
                            if transport.id != transports.last?.id { Divider() }
                        }
                    }
                } label: {
                    Label(L10n.string("detail.transports", language: language), systemImage: "point.3.connected.trianglepath.dotted")
                }

                GroupBox {
                    VStack(spacing: 0) {
                        ForEach(latest.prefix(12)) { row in
                            ParameterSummaryRow(row: row)
                            if row.id != latest.prefix(12).last?.id { Divider() }
                        }
                    }
                } label: {
                    Label(L10n.string("detail.latestParameters", language: language), systemImage: "list.bullet.rectangle")
                }
            }
            .padding(.vertical)
        }
    }
}

private struct TransportRow: View {
    @Environment(\.linkScopeLanguage) private var language
    let transport: TransportIdentity

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
            GridRow {
                Text(L10n.string("field.transport", language: language)).foregroundStyle(.secondary)
                Text(transport.kind.rawValue)
            }
            GridRow {
                Text(L10n.string("field.provider", language: language)).foregroundStyle(.secondary)
                Text(transport.providerID.rawValue).font(.body.monospaced())
            }
            GridRow {
                Text(L10n.string("field.connectionProtocol", language: language))
                    .foregroundStyle(.secondary)
                Text(L10n.string(
                    "connectionProtocol.\(transport.effectiveConnectionProtocol.rawValue)",
                    language: language
                ))
            }
            GridRow {
                Text(L10n.string("field.rawIdentifier", language: language)).foregroundStyle(.secondary)
                Text(transport.rawIdentifier).font(.body.monospaced()).textSelection(.enabled)
            }
            if transport.kind == .coreBluetooth {
                GridRow {
                    Text(L10n.string("field.identityScope", language: language)).foregroundStyle(.secondary)
                    Text(L10n.string("coreBluetooth.identifierDisclaimer", language: language))
                        .foregroundStyle(.orange)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }
}

private struct ParameterSummaryRow: View {
    @Environment(\.linkScopeLanguage) private var language
    let row: ResolvedObservation

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.observation.parameterPath.rawValue)
                    .font(.body.monospaced())
                Text(row.observation.transportIdentity.providerID.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(row.observation.value?.compactDescription
                     ?? availabilityTitle(row.observation.availability, language: language))
                    .lineLimit(2)
                    .textSelection(.enabled)
                Text(row.observation.timestamp.formatted(date: .abbreviated, time: .standard))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct RawParameterView: View {
    @Environment(\.linkScopeLanguage) private var language
    let rows: [ResolvedObservation]
    @Binding var selectedID: UUID?

    private var selected: ResolvedObservation? {
        rows.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(spacing: 12) {
            Table(rows, selection: $selectedID) {
                TableColumn(L10n.string("column.parameter", language: language)) { row in
                    Text(row.observation.parameterPath.rawValue).font(.body.monospaced())
                }
                TableColumn(L10n.string("column.value", language: language)) { row in
                    Text(row.observation.value?.compactDescription ?? "—").lineLimit(2)
                }
                TableColumn(L10n.string("column.availability", language: language)) { row in
                    AvailabilityBadge(availability: row.observation.availability)
                }
                TableColumn(L10n.string("column.provider", language: language)) { row in
                    Text(row.observation.transportIdentity.providerID.rawValue).lineLimit(1)
                }
                TableColumn(L10n.string("column.updated", language: language)) { row in
                    Text(row.observation.timestamp, style: .time)
                }
            }
            if let selected {
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selected.observation.parameterPath.rawValue)
                            .font(.headline.monospaced())
                        Text(selected.observation.value?.compactDescription
                             ?? availabilityTitle(selected.observation.availability, language: language))
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                        if let detail = selected.observation.availability.detail {
                            Text(detail).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 160)
            }
        }
        .padding(.top)
    }
}

private struct AvailabilityBadge: View {
    @Environment(\.linkScopeLanguage) private var language
    let availability: ParameterAvailability

    var body: some View {
        Text(availabilityTitle(availability, language: language))
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var color: Color {
        switch availability.code {
        case .available: .green
        case .stale: .orange
        case .permissionDenied, .providerFailure: .red
        case .notExposed, .notReported, .unsupported: .secondary
        }
    }
}

private struct ObservationHistoryView: View {
    @Environment(\.linkScopeLanguage) private var language
    let rows: [ResolvedObservation]

    var body: some View {
        List(rows) { row in
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.observation.parameterPath.rawValue).font(.body.monospaced())
                    Text(row.observation.transportIdentity.providerID.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(row.observation.value?.compactDescription
                     ?? availabilityTitle(row.observation.availability, language: language))
                    .lineLimit(1)
                Text(row.observation.timestamp, style: .time)
                    .foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .trailing)
            }
        }
        .listStyle(.inset)
        .padding(.top)
    }
}

private func availabilityTitle(
    _ availability: ParameterAvailability,
    language: AppLanguage
) -> String {
    L10n.string("availability.\(availability.code.rawValue)", language: language)
}
