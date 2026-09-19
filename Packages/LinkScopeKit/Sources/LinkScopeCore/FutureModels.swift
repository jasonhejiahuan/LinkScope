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

public indirect enum DashboardFieldValue: Codable, Hashable, Sendable {
    case null
    case bool(Bool)
    case signedInteger(Int64)
    case unsignedInteger(UInt64)
    case number(Double)
    case string(String)
    case array([DashboardFieldValue])
    case object([String: DashboardFieldValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .signedInteger(value)
        } else if let value = try? container.decode(UInt64.self) {
            self = .unsignedInteger(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([DashboardFieldValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: DashboardFieldValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.typeMismatch(
                DashboardFieldValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unsupported dashboard extension value"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case let .bool(value):
            try container.encode(value)
        case let .signedInteger(value):
            try container.encode(value)
        case let .unsignedInteger(value):
            try container.encode(value)
        case let .number(value):
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        }
    }
}

public struct DashboardDocument: Codable, Hashable, Identifiable, Sendable {
    public static let currentSchemaVersion = 1
    public static let gridColumnCount = 12

    public let schemaVersion: Int
    public let id: UUID
    public var name: String
    public var columns: Int
    public var widgets: [DashboardWidget]
    public var extensionFields: [String: DashboardFieldValue]

    public init(
        schemaVersion: Int = currentSchemaVersion,
        id: UUID = UUID(),
        name: String,
        columns: Int = gridColumnCount,
        widgets: [DashboardWidget] = [],
        extensionFields: [String: DashboardFieldValue] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.columns = schemaVersion > Self.currentSchemaVersion
            ? max(1, columns)
            : Self.gridColumnCount
        self.widgets = widgets
        self.extensionFields = extensionFields
    }

    /// Applies only the edited field to the current widget. Inspector callbacks
    /// can outlive the snapshot from which their controls were rendered.
    public mutating func apply(_ edit: DashboardWidget.ContentEdit, toWidget id: UUID) {
        guard schemaVersion <= Self.currentSchemaVersion,
              let index = widgets.firstIndex(where: { $0.id == id }),
              widgets[index].opaqueConfiguration == nil else { return }
        switch edit {
        case let .sourceIDs(sourceIDs):
            widgets[index].sourceIDs = sourceIDs
        case let .configurationValue(key, value):
            widgets[index].configuration[key] = value
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DashboardCodingKey.self)
        schemaVersion = try container.decodeIfPresent(
            Int.self,
            forKey: DashboardCodingKey("schemaVersion")
        ) ?? Self.currentSchemaVersion
        id = try container.decode(UUID.self, forKey: DashboardCodingKey("id"))
        name = try container.decode(String.self, forKey: DashboardCodingKey("name"))
        let decodedColumns = try container.decodeIfPresent(
            Int.self,
            forKey: DashboardCodingKey("columns")
        ) ?? Self.gridColumnCount
        columns = schemaVersion > Self.currentSchemaVersion
            ? max(1, decodedColumns)
            : Self.gridColumnCount
        widgets = try container.decodeIfPresent(
            [DashboardWidget].self,
            forKey: DashboardCodingKey("widgets")
        ) ?? []
        extensionFields = try container.dashboardExtensionFields(excluding: [
            "schemaVersion", "id", "name", "columns", "widgets"
        ])
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DashboardCodingKey.self)
        try container.encode(schemaVersion, forKey: DashboardCodingKey("schemaVersion"))
        try container.encode(id, forKey: DashboardCodingKey("id"))
        try container.encode(name, forKey: DashboardCodingKey("name"))
        let encodedColumns = schemaVersion > Self.currentSchemaVersion
            ? columns
            : Self.gridColumnCount
        try container.encode(encodedColumns, forKey: DashboardCodingKey("columns"))
        try container.encode(widgets, forKey: DashboardCodingKey("widgets"))
        try container.encodeDashboardExtensionFields(
            extensionFields,
            excluding: ["schemaVersion", "id", "name", "columns", "widgets"]
        )
    }
}

public struct DashboardWidget: Codable, Hashable, Identifiable, Sendable {
    public enum ContentEdit: Sendable {
        case sourceIDs([WidgetSourceID])
        case configurationValue(key: String, value: RawValue?)
    }

    public struct Kind: RawRepresentable, Codable, Hashable, Sendable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            rawValue = try container.decode(String.self)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }

        public static let currentValue = Kind(rawValue: "currentValue")
        public static let status = Kind(rawValue: "status")
        public static let timeSeries = Kind(rawValue: "timeSeries")
        public static let rawTable = Kind(rawValue: "rawTable")
        public static let timeline = Kind(rawValue: "timeline")
        public static let providerHealth = Kind(rawValue: "providerHealth")
        public static let unknown = Kind(rawValue: "unknown")

        public var isSupported: Bool {
            switch rawValue {
            case Self.currentValue.rawValue,
                 Self.status.rawValue,
                 Self.timeSeries.rawValue,
                 Self.rawTable.rawValue,
                 Self.timeline.rawValue,
                 Self.providerHealth.rawValue:
                return true
            default:
                return false
            }
        }
    }

    public let id: UUID
    public var kind: Kind
    public var sourceIDs: [WidgetSourceID]
    public var placement: GridPlacement
    public var configuration: [String: RawValue]
    public var opaqueConfiguration: DashboardFieldValue?
    public var extensionFields: [String: DashboardFieldValue]

    public init(
        id: UUID = UUID(),
        kind: Kind,
        sourceIDs: [WidgetSourceID],
        placement: GridPlacement,
        configuration: [String: RawValue] = [:],
        opaqueConfiguration: DashboardFieldValue? = nil,
        extensionFields: [String: DashboardFieldValue] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.sourceIDs = sourceIDs
        self.placement = placement
        self.configuration = configuration
        self.opaqueConfiguration = opaqueConfiguration
        self.extensionFields = extensionFields
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DashboardCodingKey.self)
        id = try container.decode(UUID.self, forKey: DashboardCodingKey("id"))
        kind = try container.decode(Kind.self, forKey: DashboardCodingKey("kind"))
        sourceIDs = try container.decodeIfPresent(
            [WidgetSourceID].self,
            forKey: DashboardCodingKey("sourceIDs")
        ) ?? []
        placement = try container.decodeIfPresent(
            GridPlacement.self,
            forKey: DashboardCodingKey("placement")
        ) ?? GridPlacement(column: 0, row: 0, columnSpan: 1, rowSpan: 1)
        let configurationKey = DashboardCodingKey("configuration")
        if !container.contains(configurationKey) {
            configuration = [:]
            opaqueConfiguration = nil
        } else if let typedConfiguration = try? container.decode(
            [String: RawValue].self,
            forKey: configurationKey
        ) {
            configuration = typedConfiguration
            opaqueConfiguration = nil
        } else {
            configuration = [:]
            opaqueConfiguration = try container.decode(
                DashboardFieldValue.self,
                forKey: configurationKey
            )
        }
        extensionFields = try container.dashboardExtensionFields(excluding: [
            "id", "kind", "sourceIDs", "placement", "configuration"
        ])
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DashboardCodingKey.self)
        try container.encode(id, forKey: DashboardCodingKey("id"))
        try container.encode(kind, forKey: DashboardCodingKey("kind"))
        try container.encode(sourceIDs, forKey: DashboardCodingKey("sourceIDs"))
        try container.encode(placement, forKey: DashboardCodingKey("placement"))
        if let opaqueConfiguration {
            try container.encode(
                opaqueConfiguration,
                forKey: DashboardCodingKey("configuration")
            )
        } else {
            try container.encode(
                configuration,
                forKey: DashboardCodingKey("configuration")
            )
        }
        try container.encodeDashboardExtensionFields(
            extensionFields,
            excluding: ["id", "kind", "sourceIDs", "placement", "configuration"]
        )
    }
}

public struct GridPlacement: Codable, Hashable, Sendable {
    public var column: Int
    public var row: Int
    public var columnSpan: Int
    public var rowSpan: Int
    public var extensionFields: [String: DashboardFieldValue]

    public init(
        column: Int,
        row: Int,
        columnSpan: Int,
        rowSpan: Int,
        extensionFields: [String: DashboardFieldValue] = [:]
    ) {
        self.column = column
        self.row = row
        self.columnSpan = columnSpan
        self.rowSpan = rowSpan
        self.extensionFields = extensionFields
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DashboardCodingKey.self)
        column = try container.decode(Int.self, forKey: DashboardCodingKey("column"))
        row = try container.decode(Int.self, forKey: DashboardCodingKey("row"))
        columnSpan = try container.decode(Int.self, forKey: DashboardCodingKey("columnSpan"))
        rowSpan = try container.decode(Int.self, forKey: DashboardCodingKey("rowSpan"))
        extensionFields = try container.dashboardExtensionFields(excluding: [
            "column", "row", "columnSpan", "rowSpan"
        ])
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DashboardCodingKey.self)
        try container.encode(column, forKey: DashboardCodingKey("column"))
        try container.encode(row, forKey: DashboardCodingKey("row"))
        try container.encode(columnSpan, forKey: DashboardCodingKey("columnSpan"))
        try container.encode(rowSpan, forKey: DashboardCodingKey("rowSpan"))
        try container.encodeDashboardExtensionFields(
            extensionFields,
            excluding: ["column", "row", "columnSpan", "rowSpan"]
        )
    }
}

private struct DashboardCodingKey: CodingKey, Hashable {
    let stringValue: String
    let intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

private extension KeyedDecodingContainer where Key == DashboardCodingKey {
    func dashboardExtensionFields(
        excluding knownKeys: Set<String>
    ) throws -> [String: DashboardFieldValue] {
        var fields: [String: DashboardFieldValue] = [:]
        for key in allKeys where !knownKeys.contains(key.stringValue) {
            fields[key.stringValue] = try decode(DashboardFieldValue.self, forKey: key)
        }
        return fields
    }
}

private extension KeyedEncodingContainer where Key == DashboardCodingKey {
    mutating func encodeDashboardExtensionFields(
        _ fields: [String: DashboardFieldValue],
        excluding knownKeys: Set<String>
    ) throws {
        for key in fields.keys.sorted() where !knownKeys.contains(key) {
            if let value = fields[key] {
                try encode(value, forKey: DashboardCodingKey(key))
            }
        }
    }
}
