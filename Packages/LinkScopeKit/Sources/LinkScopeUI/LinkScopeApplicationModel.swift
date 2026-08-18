import Foundation
import LinkScopeCore
import LinkScopePersistence
import LinkScopeProviders
import Observation
import OSLog

@MainActor
@Observable
public final class LinkScopeApplicationModel {
    public let edition: LinkScopeEdition
    public let providerDescriptors: [ProviderDescriptor]
    public private(set) var snapshot = HubSnapshot.empty
    public private(set) var isRunning = false
    public private(set) var persistenceError: String?
    public private(set) var savedSnapshots: [SnapshotArchive] = []
    public private(set) var liveSessionStartedAt = Date.distantFuture

    private let hub: ObservationHub
    private let database: ObservationDatabase?
    private var snapshotTask: Task<Void, Never>?
    private static let logger = Logger(subsystem: "cc.jasonstu.linkscope", category: "application")

    public init(edition: LinkScopeEdition) {
        self.edition = edition
        let providers = PublicProviderFactory.makeProviders()
        self.providerDescriptors = providers.map(\.descriptor)

        do {
            let keyData = try KeychainMasterKey.loadOrCreate(
                service: "cc.jasonstu.linkscope.\(edition.rawValue).storage"
            )
            let keys = try DatabaseKeyMaterial(masterKeyData: keyData)
            let databaseURL = try Self.databaseURL(edition: edition)
            let database = try ObservationDatabase(url: databaseURL, keyMaterial: keys)
            self.database = database
            self.hub = ObservationHub(providers: providers, sink: database)
        } catch {
            self.database = nil
            self.persistenceError = error.localizedDescription
            self.hub = ObservationHub(providers: providers, sink: InMemoryObservationSink())
        }
    }

    public var connectedAccessoryCount: Int {
        AccessoryConnectionClassifier.summaries(
            snapshot: snapshot,
            observedAfter: liveSessionStartedAt
        ).values.count { $0.state == .connected }
    }

    public var runningProviderCount: Int {
        snapshot.providerStatuses.filter { $0.state == .running }.count
    }

    public func connectionSummary(for accessoryID: UUID) -> AccessoryConnectionSummary {
        AccessoryConnectionClassifier.summary(
            for: accessoryID,
            snapshot: snapshot,
            observedAfter: liveSessionStartedAt
        )
    }

    public func start() async {
        guard !isRunning else { return }
        isRunning = true

        if let database {
            do {
                try await database.removeDevelopmentFixtures()
                async let observations = database.observations(matching: ObservationQuery(limit: 5_000))
                async let statuses = database.providerStatuses()
                async let timeline = database.timeline(limit: 1_000)
                async let snapshots = database.snapshots(limit: 100)
                let restored = try await (observations, statuses, timeline, snapshots)
                savedSnapshots = restored.3
                await hub.seed(
                    observations: restored.0,
                    statuses: restored.1,
                    timeline: restored.2
                )
            } catch {
                persistenceError = error.localizedDescription
                Self.logger.error("History restore failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        let stream = await hub.snapshots()
        snapshotTask = Task { [weak self] in
            for await value in stream {
                guard !Task.isCancelled else { break }
                self?.snapshot = value
            }
        }
        liveSessionStartedAt = .now
        await hub.start()
        Self.logger.info("ObservationHub started for edition \(self.edition.rawValue, privacy: .public)")
    }

    public func stop() async {
        guard isRunning else { return }
        snapshotTask?.cancel()
        snapshotTask = nil
        await hub.stop()
        isRunning = false
    }

    public func captureSnapshot(name: String? = nil) async {
        let archive = makeArchive(name: name ?? Self.defaultSnapshotName())
        do {
            try await database?.saveSnapshot(archive)
            savedSnapshots.insert(archive, at: 0)
            await hub.record(TimelineEvent(
                kind: .snapshotCaptured,
                message: "Snapshot captured: \(archive.name)"
            ))
            Self.logger.info("Snapshot captured: \(archive.id.uuidString, privacy: .public)")
        } catch {
            persistenceError = error.localizedDescription
        }
    }

    public func exportData() async throws -> Data {
        if let database {
            async let observations = database.observations(matching: ObservationQuery(limit: Int.max))
            async let statuses = database.providerStatuses()
            async let timeline = database.timeline(limit: Int.max)
            let complete = try await (observations, statuses, timeline)
            let archive = SnapshotArchive(
                name: Self.defaultSnapshotName(),
                edition: edition,
                accessories: uniqueAccessories(from: complete.0),
                observations: complete.0,
                providerStatuses: complete.1,
                timeline: complete.2
            )
            return try await Task.detached {
                try SnapshotArchiveCodec.encode(archive)
            }.value
        }
        let archive = makeArchive(name: Self.defaultSnapshotName())
        return try await Task.detached {
            try SnapshotArchiveCodec.encode(archive)
        }.value
    }

    public func importData(_ data: Data) async throws {
        let archive = try await Task.detached {
            try SnapshotArchiveCodec.decode(data)
        }.value
        if let database {
            try await database.importSnapshot(archive)
            let observations = try await database.observations(matching: ObservationQuery(limit: 5_000))
            let statuses = try await database.providerStatuses()
            let timeline = try await database.timeline(limit: 1_000)
            savedSnapshots = try await database.snapshots(limit: 100)
            await hub.seed(observations: observations, statuses: statuses, timeline: timeline)
        } else {
            savedSnapshots.insert(archive, at: 0)
            await hub.seed(
                observations: archive.observations,
                statuses: archive.providerStatuses,
                timeline: archive.timeline
            )
        }
        Self.logger.info("Snapshot imported: \(archive.id.uuidString, privacy: .public)")
    }

    public func makeArchive(name: String) -> SnapshotArchive {
        SnapshotArchive(
            name: name,
            edition: edition,
            accessories: snapshot.accessories,
            observations: snapshot.history,
            providerStatuses: snapshot.providerStatuses,
            timeline: snapshot.timeline
        )
    }

    private static func databaseURL(edition: LinkScopeEdition) throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return root
            .appendingPathComponent(edition == .full ? "LinkScope" : "LinkScope Lite", isDirectory: true)
            .appendingPathComponent("LinkScope.sqlite3")
    }

    private static func defaultSnapshotName() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return "LinkScope \(formatter.string(from: .now))"
    }

    private func uniqueAccessories(
        from observations: [ResolvedObservation]
    ) -> [PhysicalAccessoryIdentity] {
        var values: [UUID: PhysicalAccessoryIdentity] = [:]
        for observation in observations {
            values[observation.identity.physicalAccessory.id] = observation.identity.physicalAccessory
        }
        return values.values.sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }
}
