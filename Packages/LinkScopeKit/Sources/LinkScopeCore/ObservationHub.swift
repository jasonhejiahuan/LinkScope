import Foundation

public struct HubSnapshot: Sendable {
    public let accessories: [PhysicalAccessoryIdentity]
    public let transports: [UUID: [TransportIdentity]]
    public let observations: [ResolvedObservation]
    public let history: [ResolvedObservation]
    public let providerStatuses: [ProviderStatus]
    public let timeline: [TimelineEvent]
    public let updatedAt: Date

    public init(
        accessories: [PhysicalAccessoryIdentity] = [],
        transports: [UUID: [TransportIdentity]] = [:],
        observations: [ResolvedObservation] = [],
        history: [ResolvedObservation] = [],
        providerStatuses: [ProviderStatus] = [],
        timeline: [TimelineEvent] = [],
        updatedAt: Date = .now
    ) {
        self.accessories = accessories
        self.transports = transports
        self.observations = observations
        self.history = history
        self.providerStatuses = providerStatuses
        self.timeline = timeline
        self.updatedAt = updatedAt
    }

    public static let empty = HubSnapshot()
}

public actor ObservationHub {
    private let providers: [any AccessoryProvider]
    private var sink: (any ObservationSink)?
    private let resolver: IdentityResolver
    private var providerTasks: [Task<Void, Never>] = []
    private var continuations: [UUID: AsyncStream<HubSnapshot>.Continuation] = [:]
    private var accessories: [UUID: PhysicalAccessoryIdentity] = [:]
    private var transports: [UUID: [UUID: TransportIdentity]] = [:]
    private var transportOwners: [UUID: UUID] = [:]
    private var latestObservations: [ObservationIdentity: ResolvedObservation] = [:]
    private var history: [ResolvedObservation] = []
    private var statuses: [ProviderID: ProviderStatus] = [:]
    private var timeline: [TimelineEvent] = []
    private var started = false

    public init(
        providers: [any AccessoryProvider],
        sink: (any ObservationSink)? = nil,
        resolver: IdentityResolver = IdentityResolver()
    ) {
        self.providers = providers
        self.sink = sink
        self.resolver = resolver
    }

    public func snapshots() -> AsyncStream<HubSnapshot> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.yield(makeSnapshot())
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }

    public func start() async {
        guard !started else { return }
        started = true

        for provider in providers {
            let stream = await provider.events()
            let task = Task { [weak self] in
                for await event in stream {
                    guard !Task.isCancelled else { break }
                    await self?.consume(event)
                }
            }
            providerTasks.append(task)
            await provider.start()
        }
    }

    public func stop() async {
        guard started else { return }
        started = false
        for provider in providers {
            await provider.stop()
        }
        providerTasks.forEach { $0.cancel() }
        providerTasks.removeAll()
    }

    public func currentSnapshot() -> HubSnapshot {
        makeSnapshot()
    }

    public func setSink(_ sink: (any ObservationSink)?) {
        self.sink = sink
    }

    public func record(_ event: TimelineEvent) async {
        await consume(.timeline(event))
    }

    @discardableResult
    public func sample(
        providerID: ProviderID,
        request: ProviderSampleRequest
    ) async -> Bool {
        guard started,
              let provider = providers.first(where: { $0.descriptor.id == providerID }),
              let observation = await provider.sample(request) else {
            return false
        }
        await consume(.observation(observation))
        return true
    }

    public func seed(
        observations: [ResolvedObservation],
        statuses: [ProviderStatus],
        timeline: [TimelineEvent]
    ) async {
        accessories.removeAll(keepingCapacity: true)
        transports.removeAll(keepingCapacity: true)
        transportOwners.removeAll(keepingCapacity: true)
        latestObservations.removeAll(keepingCapacity: true)
        history.removeAll(keepingCapacity: true)
        await resolver.reset()
        for resolved in observations.sorted(by: { $0.observation.timestamp < $1.observation.timestamp }) {
            guard !DevelopmentFixturePolicy.isDevelopmentFixture(
                resolved.identity.transportIdentity
            ) else { continue }
            let identity = await resolver.resolve(
                resolved.identity.transportIdentity,
                preferredPhysical: resolved.identity.physicalAccessory
            )
            let rebuilt = ResolvedObservation(
                observation: resolved.observation,
                identity: identity
            )
            if let previousOwner = transportOwners[identity.transportIdentity.id],
               previousOwner != identity.physicalAccessory.id {
                remapPhysicalAccessory(
                    from: previousOwner,
                    to: identity.physicalAccessory
                )
            }
            await remapCanonicalAliases(to: identity.physicalAccessory)
            accessories[identity.physicalAccessory.id] = identity.physicalAccessory
            transports[identity.physicalAccessory.id, default: [:]][identity.transportIdentity.id] = identity.transportIdentity
            transportOwners[identity.transportIdentity.id] = identity.physicalAccessory.id
            latestObservations[rebuilt.observationIdentity] = rebuilt
            history.append(rebuilt)
        }
        history.sort { $0.observation.timestamp > $1.observation.timestamp }
        if history.count > 5_000 {
            history.removeLast(history.count - 5_000)
        }
        self.statuses = Dictionary(uniqueKeysWithValues: statuses.map { ($0.providerID, $0) })
        self.timeline = Array(timeline.sorted { $0.timestamp > $1.timestamp }.prefix(1_000))
        publish()
    }

    private func consume(_ event: ProviderEvent) async {
        switch event {
        case let .status(status):
            guard !DevelopmentFixturePolicy.isDevelopmentProvider(status.providerID) else { return }
            statuses[status.providerID] = status
            try? await sink?.persist(status)

        case let .timeline(event):
            if let providerID = event.providerID,
               DevelopmentFixturePolicy.isDevelopmentProvider(providerID) { return }
            timeline.insert(event, at: 0)
            if timeline.count > 1_000 {
                timeline.removeLast(timeline.count - 1_000)
            }
            try? await sink?.persist(event)

        case let .observation(observation):
            guard !DevelopmentFixturePolicy.isDevelopmentFixture(
                observation.transportIdentity
            ) else { return }
            guard observation.isWellFormed else {
                let event = TimelineEvent(
                    providerID: observation.transportIdentity.providerID,
                    kind: .error,
                    message: "Provider emitted a malformed observation at \(observation.parameterPath.rawValue)"
                )
                timeline.insert(event, at: 0)
                try? await sink?.persist(event)
                publish()
                return
            }

            let identity = await resolver.resolve(observation.transportIdentity)
            if let previousOwner = transportOwners[identity.transportIdentity.id],
               previousOwner != identity.physicalAccessory.id {
                remapPhysicalAccessory(
                    from: previousOwner,
                    to: identity.physicalAccessory
                )
            }
            await remapCanonicalAliases(to: identity.physicalAccessory)
            transportOwners[identity.transportIdentity.id] = identity.physicalAccessory.id
            let resolved = ResolvedObservation(observation: observation, identity: identity)
            accessories[identity.physicalAccessory.id] = identity.physicalAccessory
            transports[identity.physicalAccessory.id, default: [:]][identity.transportIdentity.id] = identity.transportIdentity

            let previous = latestObservations[resolved.observationIdentity]
            latestObservations[resolved.observationIdentity] = resolved
            if let previous,
               previous.observation.value == resolved.observation.value,
               previous.observation.availability == resolved.observation.availability,
               resolved.observation.timestamp.timeIntervalSince(previous.observation.timestamp) < 2 {
                publish()
                return
            }
            history.insert(resolved, at: 0)
            if history.count > 5_000 {
                history.removeLast(history.count - 5_000)
            }
            try? await sink?.persist(resolved)
        }
        publish()
    }

    private func remapPhysicalAccessory(
        from sourceID: UUID,
        to target: PhysicalAccessoryIdentity
    ) {
        guard sourceID != target.id else { return }

        accessories.removeValue(forKey: sourceID)
        accessories[target.id] = target
        if let sourceTransports = transports.removeValue(forKey: sourceID) {
            for (id, transport) in sourceTransports {
                transports[target.id, default: [:]][id] = transport
                transportOwners[id] = target.id
            }
        }

        latestObservations = latestObservations.mapValues {
            reassign($0, from: sourceID, to: target)
        }
        history = history.map {
            reassign($0, from: sourceID, to: target)
        }
    }

    private func remapCanonicalAliases(
        to target: PhysicalAccessoryIdentity
    ) async {
        let ownerIDs = Set(transportOwners.values)
        for ownerID in ownerIDs where ownerID != target.id {
            if await resolver.canonicalPhysicalID(for: ownerID) == target.id {
                remapPhysicalAccessory(from: ownerID, to: target)
            }
        }
    }

    private func reassign(
        _ observation: ResolvedObservation,
        from sourceID: UUID,
        to target: PhysicalAccessoryIdentity
    ) -> ResolvedObservation {
        guard observation.identity.physicalAccessory.id == sourceID else {
            return observation
        }
        return ResolvedObservation(
            observation: observation.observation,
            identity: ResolvedIdentity(
                physicalAccessory: target,
                transportIdentity: observation.identity.transportIdentity,
                resolution: observation.identity.resolution
            )
        )
    }

    private func makeSnapshot() -> HubSnapshot {
        HubSnapshot(
            accessories: accessories.values.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending },
            transports: transports.mapValues { values in
                values.values.sorted { $0.kind.rawValue < $1.kind.rawValue }
            },
            observations: latestObservations.values.sorted { $0.observation.timestamp > $1.observation.timestamp },
            history: history,
            providerStatuses: statuses.values.sorted { $0.providerID.rawValue < $1.providerID.rawValue },
            timeline: timeline,
            updatedAt: .now
        )
    }

    private func publish() {
        let snapshot = makeSnapshot()
        for continuation in continuations.values {
            continuation.yield(snapshot)
        }
    }

    private func removeContinuation(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }
}
