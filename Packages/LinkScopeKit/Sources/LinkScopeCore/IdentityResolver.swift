import Foundation

public actor IdentityResolver {
    private struct KnownTransport: Sendable {
        let physical: PhysicalAccessoryIdentity
        let transport: TransportIdentity
    }

    private var exact: [String: KnownTransport] = [:]
    private var ancestry: [String: KnownTransport] = [:]
    private var physicalGroups: [String: KnownTransport] = [:]
    private var serialCorrelation: [String: KnownTransport] = [:]
    private var crossProviderCorrelations: [String: KnownTransport] = [:]
    private var softCorrelations: [String: Set<UUID>] = [:]
    private var displayNames: [String: Set<UUID>] = [:]
    private var physicals: [UUID: PhysicalAccessoryIdentity] = [:]
    private var physicalAliases: [UUID: UUID] = [:]
    private var transportKinds: [UUID: Set<TransportKind>] = [:]

    public init() {}

    public func reset() {
        exact.removeAll(keepingCapacity: true)
        ancestry.removeAll(keepingCapacity: true)
        physicalGroups.removeAll(keepingCapacity: true)
        serialCorrelation.removeAll(keepingCapacity: true)
        crossProviderCorrelations.removeAll(keepingCapacity: true)
        softCorrelations.removeAll(keepingCapacity: true)
        displayNames.removeAll(keepingCapacity: true)
        physicals.removeAll(keepingCapacity: true)
        physicalAliases.removeAll(keepingCapacity: true)
        transportKinds.removeAll(keepingCapacity: true)
    }

    public func register(_ resolved: ResolvedIdentity) {
        register(
            physical: resolved.physicalAccessory,
            transport: resolved.transportIdentity
        )
    }

    public func canonicalPhysicalID(for id: UUID) -> UUID {
        canonicalID(id)
    }

    /// Resolves a transport to a physical accessory. preferredPhysical is used
    /// while rebuilding history so stored UUIDs survive without trusting an
    /// older resolver's grouping decisions.
    public func resolve(
        _ candidate: TransportIdentity,
        preferredPhysical: PhysicalAccessoryIdentity? = nil
    ) -> ResolvedIdentity {
        let exactKnown = exact[candidate.exactKey].map(canonicalized)

        if let key = crossProviderCorrelationKey(candidate),
           let known = crossProviderCorrelations[key].map(canonicalized) {
            let resolved = resolve(
                candidate,
                against: known,
                exactKnown: exactKnown,
                resolution: .correlated(confidence: 0.98)
            )
            mergeAnchoredSoftAliases(for: candidate, into: resolved.physicalAccessory)
            register(physical: resolved.physicalAccessory, transport: resolved.transportIdentity)
            return ResolvedIdentity(
                physicalAccessory: canonicalPhysical(resolved.physicalAccessory),
                transportIdentity: resolved.transportIdentity,
                resolution: resolved.resolution
            )
        }

        if let key = physicalGroupKey(candidate),
           let known = physicalGroups[key].map(canonicalized) {
            return resolve(
                candidate,
                against: known,
                exactKnown: exactKnown,
                resolution: .correlated(confidence: 0.99)
            )
        }

        if let ancestryID = candidate.registryAncestryID,
           !ancestryID.isEmpty,
           let known = ancestry[ancestryID].map(canonicalized) {
            return resolve(
                candidate,
                against: known,
                exactKnown: exactKnown,
                resolution: .verifiedAncestry
            )
        }

        if let serialKey = serialCorrelationKey(candidate),
           let known = serialCorrelation[serialKey].map(canonicalized) {
            return resolve(
                candidate,
                against: known,
                exactKnown: exactKnown,
                resolution: .correlated(confidence: 0.95)
            )
        }

        // Cross-provider correlation is intentionally conservative. A name is
        // considered only inside a provider-supplied domain such as
        // bluetooth-accessory, and only when exactly one physical candidate
        // exists and that physical does not already contain this transport kind.
        if let key = softCorrelationKey(candidate) {
            let candidateIDs = Set((softCorrelations[key] ?? []).map(canonicalID))
            if candidateIDs.count == 1,
               let id = candidateIDs.first,
               transportKinds[id, default: []].contains(candidate.kind) == false,
               let physical = physicals[id] {
                let known = KnownTransport(physical: physical, transport: candidate)
                return resolve(
                    candidate,
                    against: known,
                    exactKnown: exactKnown,
                    resolution: .correlated(confidence: 0.75)
                )
            }
        }

        if let known = exactKnown {
            var refreshedPhysical = known.physical
            if let candidateName = candidate.displayName?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !candidateName.isEmpty,
               (!isGenericDisplayName(candidateName)
                    || refreshedPhysical.displayName == "Unknown accessory") {
                refreshedPhysical.displayName = candidateName
                physicals[refreshedPhysical.id] = refreshedPhysical
            }
            let normalized = transport(candidate, preservingID: known.transport.id)
            register(physical: refreshedPhysical, transport: normalized)
            return ResolvedIdentity(
                physicalAccessory: refreshedPhysical,
                transportIdentity: normalized,
                resolution: .exact
            )
        }

        let displayName = normalizedDisplayName(candidate.displayName)
        let nameWasSeen = displayName.flatMap { displayNames[$0] }?.isEmpty == false
        var physical = preferredPhysical ?? PhysicalAccessoryIdentity(
            displayName: candidate.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty ?? "Unknown accessory"
        )
        if physical.displayName == "Unknown accessory",
           let candidateName = candidate.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !candidateName.isEmpty {
            physical.displayName = candidateName
        }
        register(physical: physical, transport: candidate)

        return ResolvedIdentity(
            physicalAccessory: canonicalPhysical(physical),
            transportIdentity: candidate,
            resolution: nameWasSeen ? .ambiguous : .independent
        )
    }

    private func resolve(
        _ candidate: TransportIdentity,
        against known: KnownTransport,
        exactKnown: KnownTransport?,
        resolution: IdentityResolution
    ) -> ResolvedIdentity {
        let target = canonicalPhysical(known.physical)
        let prior = exactKnown.map { canonicalPhysical($0.physical) }
        if let prior, prior.id != target.id {
            mergePhysical(source: prior, into: target)
        }

        let normalized = transport(
            candidate,
            preservingID: exactKnown?.transport.id ?? candidate.id
        )
        register(physical: target, transport: normalized)
        return ResolvedIdentity(
            physicalAccessory: canonicalPhysical(target),
            transportIdentity: normalized,
            resolution: prior?.id == target.id ? .exact : resolution
        )
    }

    private func register(
        physical: PhysicalAccessoryIdentity,
        transport: TransportIdentity
    ) {
        physicals[physical.id] = physical
        let canonical = canonicalPhysical(physical)
        let known = KnownTransport(physical: canonical, transport: transport)
        exact[transport.exactKey] = known
        transportKinds[canonical.id, default: []].insert(transport.kind)

        if let ancestryID = transport.registryAncestryID, !ancestryID.isEmpty {
            ancestry[ancestryID] = known
        }
        if let key = physicalGroupKey(transport) {
            physicalGroups[key] = known
        }
        if let key = serialCorrelationKey(transport) {
            serialCorrelation[key] = known
        }
        if let key = crossProviderCorrelationKey(transport) {
            crossProviderCorrelations[key] = known
        }
        if let key = softCorrelationKey(transport) {
            softCorrelations[key, default: []].insert(canonical.id)
        }
        if let displayName = normalizedDisplayName(transport.displayName) {
            displayNames[displayName, default: []].insert(canonical.id)
        }
    }

    private func mergePhysical(
        source: PhysicalAccessoryIdentity,
        into target: PhysicalAccessoryIdentity
    ) {
        let sourceID = canonicalID(source.id)
        let targetID = canonicalID(target.id)
        guard sourceID != targetID else { return }
        physicalAliases[sourceID] = targetID
        transportKinds[targetID, default: []].formUnion(transportKinds[sourceID] ?? [])
        transportKinds.removeValue(forKey: sourceID)
    }

    private func canonicalized(_ known: KnownTransport) -> KnownTransport {
        KnownTransport(
            physical: canonicalPhysical(known.physical),
            transport: known.transport
        )
    }

    private func canonicalPhysical(
        _ physical: PhysicalAccessoryIdentity
    ) -> PhysicalAccessoryIdentity {
        let id = canonicalID(physical.id)
        return physicals[id] ?? physical
    }

    private func canonicalID(_ id: UUID) -> UUID {
        var current = id
        var visited: Set<UUID> = []
        while let next = physicalAliases[current], visited.insert(current).inserted {
            current = next
        }
        return current
    }

    private func transport(
        _ transport: TransportIdentity,
        preservingID id: UUID
    ) -> TransportIdentity {
        TransportIdentity(
            id: id,
            providerID: transport.providerID,
            kind: transport.kind,
            rawIdentifier: transport.rawIdentifier,
            displayName: transport.displayName,
            registryAncestryID: transport.registryAncestryID,
            vendorID: transport.vendorID,
            productID: transport.productID,
            serialNumber: transport.serialNumber,
            physicalGroupIdentifier: transport.physicalGroupIdentifier,
            correlationDomain: transport.correlationDomain,
            crossProviderIdentifier: transport.crossProviderIdentifier,
            connectionProtocol: transport.connectionProtocol
        )
    }

    private func physicalGroupKey(_ identity: TransportIdentity) -> String? {
        guard let value = identity.physicalGroupIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return "\(identity.providerID.rawValue)|\(value.lowercased())"
    }

    private func serialCorrelationKey(_ identity: TransportIdentity) -> String? {
        guard let serialNumber = identity.serialNumber?.trimmingCharacters(in: .whitespacesAndNewlines),
              !serialNumber.isEmpty,
              let vendorID = identity.vendorID,
              let productID = identity.productID else {
            return nil
        }
        return "\(vendorID)|\(productID)|\(serialNumber.lowercased())"
    }

    private func softCorrelationKey(_ identity: TransportIdentity) -> String? {
        guard let domain = identity.correlationDomain?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !domain.isEmpty,
              let displayName = normalizedDisplayName(identity.displayName) else {
            return nil
        }
        return "\(domain)|\(displayName)"
    }

    private func crossProviderCorrelationKey(_ identity: TransportIdentity) -> String? {
        guard let value = identity.crossProviderIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    /// Once two provider surfaces independently expose the same normalized
    /// identifier, that physical accessory becomes an anchor. A unique,
    /// non-generic name alias in the same correlation domain can then be folded
    /// into the anchor even if it came from the same provider kind (for example
    /// a rotating BLE companion address next to a saved classic address).
    private func mergeAnchoredSoftAliases(
        for identity: TransportIdentity,
        into target: PhysicalAccessoryIdentity
    ) {
        guard let key = softCorrelationKey(identity),
              !isGenericDisplayName(identity.displayName) else { return }
        let target = canonicalPhysical(target)
        let aliases = Set((softCorrelations[key] ?? []).map(canonicalID))
        for aliasID in aliases where aliasID != target.id {
            if let alias = physicals[aliasID] {
                mergePhysical(source: alias, into: target)
            }
        }
    }

    private func isGenericDisplayName(_ value: String?) -> Bool {
        guard let value = normalizedDisplayName(value) else { return true }
        return [
            "bluetooth device", "hid device", "audio device", "headset",
            "headphones", "keyboard", "mouse", "unknown accessory"
        ].contains(value)
    }

    private func normalizedDisplayName(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty ? nil : normalized
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
