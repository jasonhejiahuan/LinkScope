import Foundation

public enum DiagnosticControlError: Error, LocalizedError, Sendable {
    case noSources

    public var errorDescription: String? {
        switch self {
        case .noSources:
            "Select at least one available diagnostic source."
        }
    }
}

public enum DiagnosticRunState: String, Codable, CaseIterable, Sendable {
    case scheduled, running, stopping, completed, failed, interrupted
}

public enum DiagnosticEndReason: String, Codable, Sendable {
    case userStopped, durationReached, applicationTerminated, providerFailed, replaced
}

public struct DiagnosticSource: Codable, Hashable, Identifiable, Sendable {
    public let id: WidgetSourceID
    public let accessoryID: UUID
    public let transportID: UUID
    public let providerID: ProviderID
    public let parameterPath: ParameterPath
    public let displayName: String
    public let operation: ProviderOperation

    public init(
        id: WidgetSourceID, accessoryID: UUID, transportID: UUID,
        providerID: ProviderID, parameterPath: ParameterPath,
        displayName: String, operation: ProviderOperation
    ) {
        self.id = id
        self.accessoryID = accessoryID
        self.transportID = transportID
        self.providerID = providerID
        self.parameterPath = parameterPath
        self.displayName = displayName
        self.operation = operation
    }
}

public struct DiagnosticRun: Codable, Hashable, Identifiable, Sendable {
    public static let currentSchemaVersion = 1
    public let schemaVersion: Int
    public let id: UUID
    public var name: String
    public var purpose: String
    public let createdAt: Date
    public var startedAt: Date?
    public var endedAt: Date?
    public var plannedDuration: TimeInterval?
    public var state: DiagnosticRunState
    public var endReason: DiagnosticEndReason?
    public var sources: [DiagnosticSource]
    public var samplingPolicy: SamplingPolicy
    public var sampleCount: Int
    public var gapCount: Int
    public var errorMessage: String?

    public init(
        schemaVersion: Int = currentSchemaVersion, id: UUID = UUID(),
        name: String, purpose: String = "", createdAt: Date = .now,
        startedAt: Date? = nil, endedAt: Date? = nil,
        plannedDuration: TimeInterval? = nil,
        state: DiagnosticRunState = .scheduled,
        endReason: DiagnosticEndReason? = nil,
        sources: [DiagnosticSource], samplingPolicy: SamplingPolicy,
        sampleCount: Int = 0, gapCount: Int = 0,
        errorMessage: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.purpose = purpose
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plannedDuration = plannedDuration
        self.state = state
        self.endReason = endReason
        self.sources = sources
        self.samplingPolicy = samplingPolicy
        self.sampleCount = sampleCount
        self.gapCount = gapCount
        self.errorMessage = errorMessage
    }
}

public enum DiagnosticGapReason: String, Codable, Sendable {
    case systemSleep, providerUnavailable, samplingFailed, applicationRestarted
}

public struct DiagnosticGap: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let sessionID: UUID
    public let sourceID: WidgetSourceID?
    public let startedAt: Date
    public var endedAt: Date?
    public let reason: DiagnosticGapReason
    public let detail: String?

    public init(
        id: UUID = UUID(), sessionID: UUID, sourceID: WidgetSourceID? = nil,
        startedAt: Date = .now, endedAt: Date? = nil,
        reason: DiagnosticGapReason, detail: String? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.sourceID = sourceID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.reason = reason
        self.detail = detail
    }
}

public struct RuleTrigger: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let ruleID: UUID
    public let sessionID: UUID?
    public let observationID: UUID?
    public let triggeredAt: Date
    public let summary: String

    public init(
        id: UUID = UUID(), ruleID: UUID, sessionID: UUID? = nil,
        observationID: UUID? = nil, triggeredAt: Date = .now, summary: String
    ) {
        self.id = id
        self.ruleID = ruleID
        self.sessionID = sessionID
        self.observationID = observationID
        self.triggeredAt = triggeredAt
        self.summary = summary
    }
}

public struct ProviderSampleRequest: Sendable {
    public let transport: TransportIdentity
    public let parameterPath: ParameterPath
    public let sessionID: UUID

    public init(transport: TransportIdentity, parameterPath: ParameterPath, sessionID: UUID) {
        self.transport = transport
        self.parameterPath = parameterPath
        self.sessionID = sessionID
    }
}

/// Pure scheduling decisions shared by the application model and tests.
/// An event-only diagnostic intentionally has no polling interval.
public enum DiagnosticSamplingScheduler: Sendable {
    public static func periodicInterval(for policy: SamplingPolicy) -> TimeInterval? {
        switch policy {
        case .eventOnly:
            return nil
        case let .fixedInterval(seconds):
            return max(2, seconds)
        case let .adaptive(minimumSeconds, _):
            return max(2, minimumSeconds)
        }
    }

    public static func nextAdaptiveInterval(
        current: TimeInterval,
        minimumSeconds: TimeInterval,
        maximumSeconds: TimeInterval,
        sampleSucceeded: Bool
    ) -> TimeInterval {
        let minimum = max(2, minimumSeconds)
        let maximum = max(minimum, maximumSeconds)
        return sampleSucceeded ? minimum : min(maximum, max(minimum, current * 2))
    }
}

public enum DiagnosticSourceCatalog: Sendable {
    public static func sampleSources(
        observations: [ResolvedObservation],
        providers: [ProviderDescriptor]
    ) -> [DiagnosticSource] {
        return sources(observations: observations, providers: providers, sampleOnly: true)
    }

    public static func monitoringSources(
        observations: [ResolvedObservation],
        providers: [ProviderDescriptor]
    ) -> [DiagnosticSource] {
        return sources(observations: observations, providers: providers, sampleOnly: false)
    }

    private static func sources(
        observations: [ResolvedObservation],
        providers: [ProviderDescriptor],
        sampleOnly: Bool
    ) -> [DiagnosticSource] {
        return observations.compactMap { resolved in
            let observation = resolved.observation
            let descriptor = providers.first(where: {
                $0.id == observation.transportIdentity.providerID
            })
            let operation: ProviderOperation
            if sampleOnly {
                guard descriptor?.capabilities.contains(where: {
                    $0.operation == .sample
                        && $0.parameterPath == observation.parameterPath
                }) == true else { return nil }
                operation = .sample
            } else {
                operation = descriptor?.capabilities.first(where: {
                    $0.parameterPath == observation.parameterPath
                })?.operation ?? .observe
            }
            return DiagnosticSource(
                id: WidgetSourceID(observationIdentity: resolved.observationIdentity),
                accessoryID: resolved.identity.physicalAccessory.id,
                transportID: resolved.identity.transportIdentity.id,
                providerID: observation.transportIdentity.providerID,
                parameterPath: observation.parameterPath,
                displayName: "\(resolved.identity.physicalAccessory.displayName) · \(observation.parameterPath.rawValue)",
                operation: operation
            )
        }
        .reduce(into: [WidgetSourceID: DiagnosticSource]()) { $0[$1.id] = $1 }
        .values
        .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }
}

/// Side-effect-free rule semantics. Provider health is represented as an
/// availability state; numeric predicates never match a provider status.
public enum MonitoringRuleEvaluator: Sendable {
    public static func matches(
        _ predicate: RulePredicate,
        observation: AccessoryObservation,
        previous: AccessoryObservation?
    ) -> Bool {
        switch predicate {
        case let .availability(code):
            return observation.availability.code == code
        case let .numericBelow(limit):
            return numericValue(observation.value).map { $0 < limit } ?? false
        case let .numericAbove(limit):
            return numericValue(observation.value).map { $0 > limit } ?? false
        case .changed:
            guard let previous else { return false }
            return previous.value != observation.value
                || previous.availability != observation.availability
        }
    }

    public static func matchesProviderStatus(
        _ predicate: RulePredicate,
        state: ProviderState,
        previous: ProviderState?
    ) -> Bool {
        switch predicate {
        case let .availability(code):
            return providerAvailability(for: state) == code
        case .numericBelow, .numericAbove:
            return false
        case .changed:
            return previous.map { $0 != state } ?? false
        }
    }

    public static func providerAvailability(for state: ProviderState) -> AvailabilityCode {
        switch state {
        case .running:
            return .available
        case .permissionDenied:
            return .permissionDenied
        case .unsupported:
            return .unsupported
        case .failed:
            return .providerFailure
        case .idle, .starting, .stopped:
            return .notReported
        }
    }

    public static func canTrigger(
        minimumRepeatInterval: TimeInterval,
        lastTriggeredAt: Date?,
        now: Date
    ) -> Bool {
        guard let lastTriggeredAt else { return true }
        return now.timeIntervalSince(lastTriggeredAt) >= max(60, minimumRepeatInterval)
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
