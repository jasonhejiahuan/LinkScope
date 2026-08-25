import Foundation

public struct ProviderID: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }
}

public struct ParameterPath: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }
}

public struct WidgetSourceID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(observationIdentity: ObservationIdentity) {
        let provider = observationIdentity.providerID.rawValue
        let path = observationIdentity.parameterPath.rawValue
        if provider == "v2" || provider.contains(":") || provider.isEmpty || path.isEmpty {
            self.rawValue = [
                "v2",
                Self.encodedComponent(provider),
                observationIdentity.transportIdentityID.uuidString.lowercased(),
                Self.encodedComponent(path)
            ].joined(separator: ":")
        } else {
            // Preserve the original representation for existing dashboards.
            self.rawValue = [
                provider,
                observationIdentity.transportIdentityID.uuidString.lowercased(),
                path
            ].joined(separator: ":")
        }
    }

    /// Decomposes IDs created with ``init(observationIdentity:)`` so persisted
    /// widgets can issue an indexed transport + parameter history query.
    public var observationIdentity: ObservationIdentity? {
        let versionedComponents = rawValue.split(
            separator: ":",
            omittingEmptySubsequences: false
        )
        if versionedComponents.count == 4, versionedComponents[0] == "v2" {
            if let provider = Self.decodedComponent(String(versionedComponents[1])),
               let transportIdentityID = UUID(
                uuidString: String(versionedComponents[2])
               ),
               let path = Self.decodedComponent(String(versionedComponents[3])) {
                return ObservationIdentity(
                    providerID: ProviderID(rawValue: provider),
                    transportIdentityID: transportIdentityID,
                    parameterPath: ParameterPath(rawValue: path)
                )
            }
        }

        let components = rawValue.split(
            separator: ":",
            maxSplits: 2,
            omittingEmptySubsequences: false
        )
        if components.count == 3,
           !components[0].isEmpty,
           let transportIdentityID = UUID(uuidString: String(components[1])),
           !components[2].isEmpty {
            return ObservationIdentity(
                providerID: ProviderID(rawValue: String(components[0])),
                transportIdentityID: transportIdentityID,
                parameterPath: ParameterPath(rawValue: String(components[2]))
            )
        }
        return legacyColonObservationIdentity
    }

    /// Recovers source IDs emitted by schema v1 when an unconstrained
    /// provider ID itself contained colons. The canonical UUID in the middle
    /// provides an unambiguous delimiter for normal provider identifiers.
    private var legacyColonObservationIdentity: ObservationIdentity? {
        var searchStart = rawValue.startIndex
        while let providerEnd = rawValue[searchStart...].firstIndex(of: ":") {
            let uuidStart = rawValue.index(after: providerEnd)
            guard let uuidEnd = rawValue.index(
                uuidStart,
                offsetBy: 36,
                limitedBy: rawValue.endIndex
            ), uuidEnd < rawValue.endIndex else {
                return nil
            }
            if rawValue[uuidEnd] == ":",
               let uuid = UUID(uuidString: String(rawValue[uuidStart..<uuidEnd])) {
                let provider = String(rawValue[..<providerEnd])
                let pathStart = rawValue.index(after: uuidEnd)
                let path = String(rawValue[pathStart...])
                if !provider.isEmpty, !path.isEmpty {
                    return ObservationIdentity(
                        providerID: ProviderID(rawValue: provider),
                        transportIdentityID: uuid,
                        parameterPath: ParameterPath(rawValue: path)
                    )
                }
            }
            searchStart = rawValue.index(after: providerEnd)
        }
        return nil
    }

    private static func encodedComponent(_ value: String) -> String {
        Data(value.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func decodedComponent(_ value: String) -> String? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
