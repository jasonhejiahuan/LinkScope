import Foundation

public struct DashboardTimeSeriesPoint: Hashable, Identifiable, Sendable {
    public let observationID: UUID
    public let sourceID: WidgetSourceID
    public let timestamp: Date
    public let value: Double

    public var id: UUID { observationID }

    public init(
        observationID: UUID = UUID(),
        sourceID: WidgetSourceID,
        timestamp: Date,
        value: Double
    ) {
        self.observationID = observationID
        self.sourceID = sourceID
        self.timestamp = timestamp
        self.value = value
    }
}

/// Largest-Triangle-Three-Buckets downsampling for dashboard charts. The API
/// is pure and Sendable, so callers can run it from a detached task without
/// retaining database or UI state.
public enum DashboardTimeSeriesDecimator: Sendable {
    public static func numericPoints(
        from observations: [ResolvedObservation]
    ) -> [DashboardTimeSeriesPoint] {
        observations.compactMap { observation in
            guard observation.observation.availability.code == .available,
                  let value = numericValue(observation.observation.value),
                  value.isFinite else {
                return nil
            }
            return DashboardTimeSeriesPoint(
                observationID: observation.id,
                sourceID: WidgetSourceID(
                    observationIdentity: observation.observationIdentity
                ),
                timestamp: observation.observation.timestamp,
                value: value
            )
        }
        .sorted(by: orderedBefore)
    }

    public static func decimate(
        _ observations: [ResolvedObservation],
        maximumPointCount: Int = 300
    ) -> [DashboardTimeSeriesPoint] {
        decimate(
            numericPoints(from: observations),
            maximumPointCount: maximumPointCount
        )
    }

    public static func decimate(
        _ points: [DashboardTimeSeriesPoint],
        maximumPointCount: Int = 300
    ) -> [DashboardTimeSeriesPoint] {
        guard maximumPointCount > 0, !points.isEmpty else { return [] }
        let points = points.sorted(by: orderedBefore)
        guard points.count > maximumPointCount else { return points }
        if maximumPointCount == 1 { return [points[points.count - 1]] }
        if maximumPointCount == 2 { return [points[0], points[points.count - 1]] }

        let every = Double(points.count - 2) / Double(maximumPointCount - 2)
        var sampled: [DashboardTimeSeriesPoint] = [points[0]]
        sampled.reserveCapacity(maximumPointCount)
        var selectedIndex = 0

        for bucket in 0..<(maximumPointCount - 2) {
            let averageStart = min(
                points.count - 1,
                Int(floor(Double(bucket + 1) * every)) + 1
            )
            let averageEnd = min(
                points.count,
                Int(floor(Double(bucket + 2) * every)) + 1
            )
            let averageRange = averageStart..<max(averageStart + 1, averageEnd)
            let averageCount = Double(averageRange.count)
            let averageX = averageRange.reduce(0.0) {
                $0 + points[$1].timestamp.timeIntervalSince1970
            } / averageCount
            let averageY = averageRange.reduce(0.0) {
                $0 + points[$1].value
            } / averageCount

            let candidateStart = min(
                points.count - 2,
                Int(floor(Double(bucket) * every)) + 1
            )
            let candidateEnd = min(
                points.count - 1,
                Int(floor(Double(bucket + 1) * every)) + 1
            )
            let candidateRange = candidateStart..<max(candidateStart + 1, candidateEnd)
            let selected = points[selectedIndex]
            let selectedX = selected.timestamp.timeIntervalSince1970

            var largestArea = -Double.infinity
            var nextSelectedIndex = candidateStart
            for index in candidateRange {
                let candidate = points[index]
                let candidateX = candidate.timestamp.timeIntervalSince1970
                let area = abs(
                    (selectedX - averageX) * (candidate.value - selected.value)
                        - (selectedX - candidateX) * (averageY - selected.value)
                )
                if area > largestArea {
                    largestArea = area
                    nextSelectedIndex = index
                }
            }
            sampled.append(points[nextSelectedIndex])
            selectedIndex = nextSelectedIndex
        }

        sampled.append(points[points.count - 1])
        return sampled
    }

    private static func orderedBefore(
        _ lhs: DashboardTimeSeriesPoint,
        _ rhs: DashboardTimeSeriesPoint
    ) -> Bool {
        if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
        return lhs.observationID.uuidString < rhs.observationID.uuidString
    }

    private static func numericValue(_ value: RawValue?) -> Double? {
        switch value {
        case let .signedInt(value):
            return Double(value)
        case let .unsignedInt(value):
            return Double(value)
        case let .double(value):
            return value
        case let .decimal(value):
            return Double(value)
        default:
            return nil
        }
    }
}
