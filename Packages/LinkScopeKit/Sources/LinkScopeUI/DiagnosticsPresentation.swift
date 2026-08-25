import Foundation
import LinkScopeCore

struct DiagnosticObservationSource: Identifiable, Hashable {
    struct ID: Hashable {
        let accessoryID: UUID
        let transportID: UUID
        let providerID: ProviderID
    }

    let id: ID
    let displayName: String
    let providerID: ProviderID
}

struct DiagnosticObservationSeries: Identifiable, Hashable {
    struct ID: Hashable {
        let sourceID: DiagnosticObservationSource.ID
        let parameterPath: ParameterPath
    }

    let source: DiagnosticObservationSource
    let parameterPath: ParameterPath

    var id: ID {
        ID(sourceID: source.id, parameterPath: parameterPath)
    }

    var displayName: String {
        "\(source.displayName) · \(parameterPath.rawValue)"
    }
}

struct DiagnosticSeriesStatistics {
    let rowCount: Int
    let unavailableCount: Int
    let numericValues: [Double]

    var minimum: Double? { numericValues.min() }
    var maximum: Double? { numericValues.max() }

    var average: Double? {
        numericValues.isEmpty
            ? nil
            : numericValues.reduce(0, +) / Double(numericValues.count)
    }
}

enum DiagnosticsPresentation {
    static func runs(
        _ runs: [DiagnosticRun],
        searchText: String,
        state: DiagnosticRunState?
    ) -> [DiagnosticRun] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return runs.filter { run in
            guard state == nil || run.state == state else { return false }
            guard !query.isEmpty else { return true }
            let searchable = [
                run.name,
                run.purpose,
                run.state.rawValue,
                run.sources.map(\.displayName).joined(separator: " "),
                run.sources.map { $0.parameterPath.rawValue }.joined(separator: " ")
            ].joined(separator: " ")
            return searchable.localizedCaseInsensitiveContains(query)
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    static func source(for observation: ResolvedObservation) -> DiagnosticObservationSource {
        DiagnosticObservationSource(
            id: DiagnosticObservationSource.ID(
                accessoryID: observation.identity.physicalAccessory.id,
                transportID: observation.identity.transportIdentity.id,
                providerID: observation.observation.transportIdentity.providerID
            ),
            displayName: observation.identity.physicalAccessory.displayName,
            providerID: observation.observation.transportIdentity.providerID
        )
    }

    static func sources(in observations: [ResolvedObservation]) -> [DiagnosticObservationSource] {
        observations.reduce(into: [DiagnosticObservationSource.ID: DiagnosticObservationSource]()) {
            let source = source(for: $1)
            $0[source.id] = source
        }
        .values
        .sorted {
            let nameComparison = $0.displayName.localizedStandardCompare($1.displayName)
            if nameComparison != .orderedSame {
                return nameComparison == .orderedAscending
            }
            return $0.providerID.rawValue.localizedStandardCompare($1.providerID.rawValue)
                == .orderedAscending
        }
    }

    static func parameters(
        in observations: [ResolvedObservation],
        sourceID: DiagnosticObservationSource.ID
    ) -> [ParameterPath] {
        Set(observations.compactMap { observation in
            source(for: observation).id == sourceID
                ? observation.observation.parameterPath
                : nil
        })
        .sorted { $0.rawValue.localizedStandardCompare($1.rawValue) == .orderedAscending }
    }

    static func observations(
        in observations: [ResolvedObservation],
        sourceID: DiagnosticObservationSource.ID,
        parameterPath: ParameterPath,
        availability: AvailabilityCode? = nil
    ) -> [ResolvedObservation] {
        observations.filter { observation in
            source(for: observation).id == sourceID
                && observation.observation.parameterPath == parameterPath
                && (availability == nil || observation.observation.availability.code == availability)
        }
        .sorted { $0.observation.timestamp > $1.observation.timestamp }
    }

    static func series(
        in observations: [ResolvedObservation],
        numericOnly: Bool = false
    ) -> [DiagnosticObservationSeries] {
        observations.reduce(into: [DiagnosticObservationSeries.ID: DiagnosticObservationSeries]()) {
            guard !numericOnly || numericValue($1.observation.value) != nil else { return }
            let series = DiagnosticObservationSeries(
                source: source(for: $1),
                parameterPath: $1.observation.parameterPath
            )
            $0[series.id] = series
        }
        .values
        .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    static func observations(
        in values: [ResolvedObservation],
        seriesID: DiagnosticObservationSeries.ID
    ) -> [ResolvedObservation] {
        observations(
            in: values,
            sourceID: seriesID.sourceID,
            parameterPath: seriesID.parameterPath
        )
    }

    static func commonNumericSeries(
        lhs: [ResolvedObservation],
        rhs: [ResolvedObservation]
    ) -> [DiagnosticObservationSeries] {
        let lhsSeries = series(in: lhs, numericOnly: true)
        let rhsIDs = Set(series(in: rhs, numericOnly: true).map(\.id))
        return lhsSeries.filter { rhsIDs.contains($0.id) }
    }

    static func statistics(for observations: [ResolvedObservation]) -> DiagnosticSeriesStatistics {
        DiagnosticSeriesStatistics(
            rowCount: observations.count,
            unavailableCount: observations.count {
                $0.observation.availability.code != .available
            },
            numericValues: observations.compactMap {
                numericValue($0.observation.value)
            }
        )
    }

    static func numericValue(_ value: RawValue?) -> Double? {
        switch value {
        case let .signedInt(value): Double(value)
        case let .unsignedInt(value): Double(value)
        case let .double(value): value
        case let .decimal(value): Double(value)
        default: nil
        }
    }
}
