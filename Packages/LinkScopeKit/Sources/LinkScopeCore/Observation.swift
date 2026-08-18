import Foundation

public enum DataSensitivity: String, Codable, CaseIterable, Sendable {
    case ordinary
    case deviceIdentifier
    case accountIdentifier
    case credentialMaterial
    case rawRegistry
    case privateFramework
}

public struct AccessoryObservation: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let transportIdentity: TransportIdentity
    public let parameterPath: ParameterPath
    public let value: RawValue?
    public let availability: ParameterAvailability
    public let sensitivity: DataSensitivity
    public let eventID: UUID?
    public let sessionID: UUID?

    public init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        transportIdentity: TransportIdentity,
        parameterPath: ParameterPath,
        value: RawValue?,
        availability: ParameterAvailability,
        sensitivity: DataSensitivity = .ordinary,
        eventID: UUID? = nil,
        sessionID: UUID? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.transportIdentity = transportIdentity
        self.parameterPath = parameterPath
        self.value = value
        self.availability = availability
        self.sensitivity = sensitivity
        self.eventID = eventID
        self.sessionID = sessionID
    }

    public static func available(
        transport: TransportIdentity,
        path: ParameterPath,
        value: RawValue,
        sensitivity: DataSensitivity = .ordinary,
        timestamp: Date = .now
    ) -> AccessoryObservation {
        AccessoryObservation(
            timestamp: timestamp,
            transportIdentity: transport,
            parameterPath: path,
            value: value,
            availability: .available,
            sensitivity: sensitivity
        )
    }

    public var isWellFormed: Bool {
        switch availability {
        case .available:
            value != nil
        default:
            value == nil
        }
    }
}

public struct ResolvedObservation: Codable, Hashable, Identifiable, Sendable {
    public let observation: AccessoryObservation
    public let identity: ResolvedIdentity

    public var id: UUID { observation.id }

    public init(observation: AccessoryObservation, identity: ResolvedIdentity) {
        self.observation = observation
        self.identity = identity
    }

    public var observationIdentity: ObservationIdentity {
        ObservationIdentity(
            providerID: observation.transportIdentity.providerID,
            transportIdentityID: identity.transportIdentity.id,
            parameterPath: observation.parameterPath
        )
    }
}

public struct TimelineEvent: Codable, Hashable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case providerStarted
        case providerStopped
        case deviceConnected
        case deviceDisconnected
        case systemSleep
        case systemWake
        case thermalChanged
        case snapshotCaptured
        case diagnostic
        case error
    }

    public let id: UUID
    public let timestamp: Date
    public let providerID: ProviderID?
    public let kind: Kind
    public let message: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        providerID: ProviderID? = nil,
        kind: Kind,
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.providerID = providerID
        self.kind = kind
        self.message = message
    }
}

