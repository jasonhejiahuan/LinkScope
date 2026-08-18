import Foundation

public struct PhysicalAccessoryIdentity: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var displayName: String
    public let createdAt: Date

    public init(id: UUID = UUID(), displayName: String, createdAt: Date = .now) {
        self.id = id
        self.displayName = displayName
        self.createdAt = createdAt
    }
}

public enum TransportKind: String, Codable, CaseIterable, Sendable {
    case coreHID
    case ioBluetooth
    case coreBluetooth
    case coreAudio
    case gameController
    case ioRegistry
    case system
    /// Decoder compatibility for development archives created before 0.1.2.
    /// Production providers must never emit this transport kind.
    case mock
}

/// The physical connection family reported by a provider. This is deliberately
/// separate from ``TransportKind``: Core Audio and CoreHID are API surfaces,
/// while Bluetooth, USB, and built-in are connection protocols.
public enum ConnectionProtocol: String, Codable, CaseIterable, Sendable {
    case bluetooth
    case usb
    case builtIn
    case network
    case virtual
    case gameController
    case system
    case unknown
}

public struct TransportIdentity: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let providerID: ProviderID
    public let kind: TransportKind
    public let rawIdentifier: String
    public var displayName: String?
    public var registryAncestryID: String?
    public var vendorID: UInt64?
    public var productID: UInt64?
    public var serialNumber: String?
    /// A provider-scoped, high-confidence grouping hint for several endpoints
    /// belonging to one physical device (for example HID collections sharing a
    /// built-in location, or Core Audio input/output endpoints sharing a UID).
    public var physicalGroupIdentifier: String?
    /// A deliberately broad domain used only for conservative multi-provider
    /// correlation. A matching display name is never sufficient by itself.
    public var correlationDomain: String?
    /// A normalized identifier that two different public provider surfaces can
    /// independently expose. It is never assumed from a display name. One
    /// example is an IOBluetooth address matching the address-shaped prefix of
    /// a Bluetooth Core Audio device UID.
    public var crossProviderIdentifier: String?
    /// The physical connection family, when the provider can determine it.
    public var connectionProtocol: ConnectionProtocol?

    public init(
        id: UUID = UUID(),
        providerID: ProviderID,
        kind: TransportKind,
        rawIdentifier: String,
        displayName: String? = nil,
        registryAncestryID: String? = nil,
        vendorID: UInt64? = nil,
        productID: UInt64? = nil,
        serialNumber: String? = nil,
        physicalGroupIdentifier: String? = nil,
        correlationDomain: String? = nil,
        crossProviderIdentifier: String? = nil,
        connectionProtocol: ConnectionProtocol? = nil
    ) {
        self.id = id
        self.providerID = providerID
        self.kind = kind
        self.rawIdentifier = rawIdentifier
        self.displayName = displayName
        self.registryAncestryID = registryAncestryID
        self.vendorID = vendorID
        self.productID = productID
        self.serialNumber = serialNumber
        self.physicalGroupIdentifier = physicalGroupIdentifier
        self.correlationDomain = correlationDomain
        self.crossProviderIdentifier = crossProviderIdentifier
        self.connectionProtocol = connectionProtocol
    }

    public var exactKey: String {
        "\(providerID.rawValue)|\(kind.rawValue)|\(rawIdentifier)"
    }
}

public enum DevelopmentFixturePolicy {
    public static func isDevelopmentProvider(_ providerID: ProviderID) -> Bool {
        let value = providerID.rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return ["mock", "test", "fixture"].contains { prefix in
            value == prefix || value.hasPrefix("\(prefix).")
        }
    }

    public static func isDevelopmentFixture(_ identity: TransportIdentity) -> Bool {
        identity.kind == .mock || isDevelopmentProvider(identity.providerID)
    }
}

public struct ObservationIdentity: Codable, Hashable, Sendable {
    public let providerID: ProviderID
    public let transportIdentityID: UUID
    public let parameterPath: ParameterPath

    public init(
        providerID: ProviderID,
        transportIdentityID: UUID,
        parameterPath: ParameterPath
    ) {
        self.providerID = providerID
        self.transportIdentityID = transportIdentityID
        self.parameterPath = parameterPath
    }
}

public enum IdentityResolution: Codable, Hashable, Sendable {
    case exact
    case verifiedAncestry
    case correlated(confidence: Double)
    case ambiguous
    case independent
}

public struct ResolvedIdentity: Codable, Hashable, Sendable {
    public let physicalAccessory: PhysicalAccessoryIdentity
    public let transportIdentity: TransportIdentity
    public let resolution: IdentityResolution

    public init(
        physicalAccessory: PhysicalAccessoryIdentity,
        transportIdentity: TransportIdentity,
        resolution: IdentityResolution
    ) {
        self.physicalAccessory = physicalAccessory
        self.transportIdentity = transportIdentity
        self.resolution = resolution
    }
}
