import Foundation

public enum ProviderOperation: String, Codable, CaseIterable, Sendable {
    case read
    case observe
    case sample
    case diagnose
}

public struct ProviderCapability: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let operation: ProviderOperation
    public let parameterPath: ParameterPath?
    public let isExperimental: Bool

    public init(
        id: String,
        operation: ProviderOperation,
        parameterPath: ParameterPath? = nil,
        isExperimental: Bool = false
    ) {
        self.id = id
        self.operation = operation
        self.parameterPath = parameterPath
        self.isExperimental = isExperimental
    }
}

public struct ProviderDescriptor: Codable, Hashable, Identifiable, Sendable {
    public let id: ProviderID
    public let displayName: String
    public let transportKind: TransportKind
    public let capabilities: [ProviderCapability]
    public let isExperimental: Bool

    public init(
        id: ProviderID,
        displayName: String,
        transportKind: TransportKind,
        capabilities: [ProviderCapability],
        isExperimental: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.transportKind = transportKind
        self.capabilities = capabilities
        self.isExperimental = isExperimental
    }
}

public enum ProviderState: String, Codable, CaseIterable, Sendable {
    case idle
    case starting
    case running
    case permissionDenied
    case unsupported
    case failed
    case stopped
}

public struct ProviderStatus: Codable, Hashable, Identifiable, Sendable {
    public var id: ProviderID { providerID }

    public let providerID: ProviderID
    public let state: ProviderState
    public let message: String?
    public let updatedAt: Date

    public init(
        providerID: ProviderID,
        state: ProviderState,
        message: String? = nil,
        updatedAt: Date = .now
    ) {
        self.providerID = providerID
        self.state = state
        self.message = message
        self.updatedAt = updatedAt
    }
}

public enum ProviderEvent: Sendable {
    case status(ProviderStatus)
    case observation(AccessoryObservation)
    case timeline(TimelineEvent)
}

public protocol AccessoryProvider: Sendable {
    var descriptor: ProviderDescriptor { get }
    func events() async -> AsyncStream<ProviderEvent>
    func start() async
    func stop() async
}

public protocol ObservationSink: Sendable {
    func persist(_ observation: ResolvedObservation) async throws
    func persist(_ status: ProviderStatus) async throws
    func persist(_ event: TimelineEvent) async throws
}

