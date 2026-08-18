import Foundation

public enum LinkScopeEdition: String, Codable, CaseIterable, Sendable {
    case full
    case lite
}

public struct CapabilityMatrix: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let generatedAt: Date
    public let edition: LinkScopeEdition
    public let providers: [ProviderDescriptor]
    public let statuses: [ProviderStatus]

    public init(
        schemaVersion: Int = currentSchemaVersion,
        generatedAt: Date = .now,
        edition: LinkScopeEdition,
        providers: [ProviderDescriptor],
        statuses: [ProviderStatus]
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.edition = edition
        self.providers = providers
        self.statuses = statuses
    }
}

public struct SnapshotArchive: Codable, Hashable, Identifiable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let id: UUID
    public let name: String
    public let createdAt: Date
    public let edition: LinkScopeEdition
    public let accessories: [PhysicalAccessoryIdentity]
    public let observations: [ResolvedObservation]
    public let providerStatuses: [ProviderStatus]
    public let timeline: [TimelineEvent]

    public init(
        schemaVersion: Int = currentSchemaVersion,
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        edition: LinkScopeEdition,
        accessories: [PhysicalAccessoryIdentity],
        observations: [ResolvedObservation],
        providerStatuses: [ProviderStatus],
        timeline: [TimelineEvent]
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.edition = edition
        self.accessories = accessories
        self.observations = observations
        self.providerStatuses = providerStatuses
        self.timeline = timeline
    }
}

public struct DiagnosticSession: Codable, Hashable, Identifiable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let id: UUID
    public var name: String
    public let createdAt: Date
    public var endedAt: Date?
    public var sourceIDs: [WidgetSourceID]
    public var samplingPolicy: SamplingPolicy

    public init(
        schemaVersion: Int = currentSchemaVersion,
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        endedAt: Date? = nil,
        sourceIDs: [WidgetSourceID],
        samplingPolicy: SamplingPolicy
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.endedAt = endedAt
        self.sourceIDs = sourceIDs
        self.samplingPolicy = samplingPolicy
    }
}

public enum SamplingPolicy: Codable, Hashable, Sendable {
    case eventOnly
    case fixedInterval(seconds: Double)
    case adaptive(minimumSeconds: Double, maximumSeconds: Double)
}

public struct RuleDefinition: Codable, Hashable, Identifiable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let id: UUID
    public var name: String
    public var isEnabled: Bool
    public var sourceID: WidgetSourceID
    public var predicate: RulePredicate
    public var minimumRepeatInterval: TimeInterval

    public init(
        schemaVersion: Int = currentSchemaVersion,
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool = true,
        sourceID: WidgetSourceID,
        predicate: RulePredicate,
        minimumRepeatInterval: TimeInterval = 900
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.sourceID = sourceID
        self.predicate = predicate
        self.minimumRepeatInterval = minimumRepeatInterval
    }
}

public enum RulePredicate: Codable, Hashable, Sendable {
    case availability(AvailabilityCode)
    case numericBelow(Double)
    case numericAbove(Double)
    case changed
}

public struct DashboardDocument: Codable, Hashable, Identifiable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let id: UUID
    public var name: String
    public var columns: Int
    public var widgets: [DashboardWidget]

    public init(
        schemaVersion: Int = currentSchemaVersion,
        id: UUID = UUID(),
        name: String,
        columns: Int = 12,
        widgets: [DashboardWidget] = []
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.columns = columns
        self.widgets = widgets
    }
}

public struct DashboardWidget: Codable, Hashable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case currentValue
        case status
        case timeSeries
        case rawTable
        case timeline
        case providerHealth
        case unknown
    }

    public let id: UUID
    public var kind: Kind
    public var sourceIDs: [WidgetSourceID]
    public var placement: GridPlacement
    public var configuration: [String: RawValue]

    public init(
        id: UUID = UUID(),
        kind: Kind,
        sourceIDs: [WidgetSourceID],
        placement: GridPlacement,
        configuration: [String: RawValue] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.sourceIDs = sourceIDs
        self.placement = placement
        self.configuration = configuration
    }
}

public struct GridPlacement: Codable, Hashable, Sendable {
    public var column: Int
    public var row: Int
    public var columnSpan: Int
    public var rowSpan: Int

    public init(column: Int, row: Int, columnSpan: Int, rowSpan: Int) {
        self.column = column
        self.row = row
        self.columnSpan = columnSpan
        self.rowSpan = rowSpan
    }
}

