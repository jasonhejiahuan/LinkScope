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
