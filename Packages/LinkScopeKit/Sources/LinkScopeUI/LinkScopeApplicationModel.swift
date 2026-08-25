@preconcurrency import CoreBluetooth
import Foundation
import LinkScopeCore
import LinkScopePersistence
import LinkScopeProviders
import Observation
import OSLog
import Security
import UserNotifications

public enum LinkScopePermissionState: Sendable, Equatable {
    case unknown
    case notRequested
    case allowed
    case denied
    case unavailable
}

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
    public private(set) var diagnosticRuns: [DiagnosticRun] = []
    public private(set) var activeDiagnostic: DiagnosticRun?
    public private(set) var rules: [RuleDefinition] = []
    public private(set) var notificationsAuthorized = false
    public private(set) var retentionCandidateCount = 0
    public private(set) var keychainPermissionState: LinkScopePermissionState = .unknown
    public private(set) var bluetoothPermissionState: LinkScopePermissionState = .unknown
    public private(set) var notificationPermissionState: LinkScopePermissionState = .unknown

    private let hub: ObservationHub
    private var database: ObservationDatabase?
    private var didRestoreDatabase = false
    private var snapshotTask: Task<Void, Never>?
    private var diagnosticTask: Task<Void, Never>?
    private var lastRuleObservations: [WidgetSourceID: ResolvedObservation] = [:]
    private var lastRuleTriggerDates: [UUID: Date] = [:]
    private var lastProviderStates: [ProviderID: ProviderState] = [:]
    private var sleepGap: DiagnosticGap?
    private static let logger = Logger(subsystem: "cc.jasonstu.linkscope", category: "application")

    public init(edition: LinkScopeEdition) {
        self.edition = edition
        let providers = PublicProviderFactory.makeProviders()
        self.providerDescriptors = providers.map(\.descriptor)
        self.database = nil
        self.hub = ObservationHub(providers: providers, sink: InMemoryObservationSink())
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
        await prepareStorageIfAlreadyAuthorized()
        isRunning = true

        await restoreDatabaseIfNeeded()

        let stream = await hub.snapshots()
        snapshotTask = Task { [weak self] in
            for await value in stream {
                guard !Task.isCancelled else { break }
                self?.snapshot = value
                await self?.evaluateRules(in: value)
            }
        }
        liveSessionStartedAt = .now
        await hub.start()
        Self.logger.info("ObservationHub started for edition \(self.edition.rawValue, privacy: .public)")
    }

    public var permissionsNeedAttention: Bool {
        keychainPermissionState != .allowed || bluetoothPermissionState != .allowed
    }

    public var isUsingPersistentStorage: Bool {
        database != nil
    }

    public func refreshPermissionStatuses() async {
        switch KeychainMasterKey.accessStatus(service: keychainService) {
        case .available:
            keychainPermissionState = .allowed
            await prepareStorageIfAlreadyAuthorized()
        case .notConfigured:
            keychainPermissionState = .notRequested
        case .authorizationRequired:
            keychainPermissionState = .denied
        case .unavailable:
            keychainPermissionState = .unavailable
        }

        bluetoothPermissionState = switch CBManager.authorization {
        case .allowedAlways: .allowed
        case .notDetermined: .notRequested
        case .denied, .restricted: .denied
        @unknown default: .unavailable
        }

        await refreshNotificationAuthorization()
    }

    public func requestKeychainAccess() async {
        do {
            try await configurePersistence(allowAuthenticationUI: true)
            keychainPermissionState = .allowed
            persistenceError = nil
        } catch {
            if let keyMaterialError = error as? KeyMaterialError,
               case let .keychain(status) = keyMaterialError,
               status == errSecUserCanceled {
                keychainPermissionState = .notRequested
            } else {
                keychainPermissionState = .denied
            }
            persistenceError = error.localizedDescription
        }
    }

    public func requestBluetoothAccess() async {
        await start()
        try? await Task.sleep(for: .milliseconds(500))
        bluetoothPermissionState = switch CBManager.authorization {
        case .allowedAlways: .allowed
        case .notDetermined: .notRequested
        case .denied, .restricted: .denied
        @unknown default: .unavailable
        }
    }

    public func refreshNotificationAuthorization() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsAuthorized = [.authorized, .provisional]
            .contains(settings.authorizationStatus)
        notificationPermissionState = switch settings.authorizationStatus {
        case .authorized, .provisional: .allowed
        case .notDetermined: .notRequested
        case .denied: .denied
        @unknown default: .unavailable
        }
    }

    public func requestNotificationAuthorization() async {
        do {
            notificationsAuthorized = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            await refreshNotificationAuthorization()
        } catch {
            notificationsAuthorized = false
            notificationPermissionState = .denied
            persistenceError = error.localizedDescription
        }
    }

    public func saveRule(_ rule: RuleDefinition) async {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
        } else {
            rules.append(rule)
        }
        do {
            try await database?.saveRule(rule)
        } catch {
            persistenceError = error.localizedDescription
        }
    }

    public func deleteRule(id: UUID) async {
        do {
            try await database?.deleteRule(id: id)
            rules.removeAll { $0.id == id }
            lastRuleTriggerDates.removeValue(forKey: id)
        } catch {
            persistenceError = error.localizedDescription
        }
    }

    public func previewRetention(days: Int) async {
        guard days > 0, let database else {
            retentionCandidateCount = 0
            return
        }
        do {
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .distantPast
            retentionCandidateCount = try await database.observationCount(olderThan: cutoff)
        } catch {
            persistenceError = error.localizedDescription
        }
    }

    public func applyRetention(days: Int) async {
        guard days > 0, let database else { return }
        do {
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .distantPast
            _ = try await database.deleteObservations(olderThan: cutoff)
            retentionCandidateCount = 0
            let observations = try await database.observations(matching: ObservationQuery(limit: 5_000))
            let statuses = try await database.providerStatuses()
            let timeline = try await database.timeline(limit: 1_000)
            await hub.seed(observations: observations, statuses: statuses, timeline: timeline)
        } catch {
            persistenceError = error.localizedDescription
        }
    }

    public func stop() async {
        guard isRunning else { return }
        snapshotTask?.cancel()
        snapshotTask = nil
        await stopDiagnostic(reason: .applicationTerminated)
        await hub.stop()
        isRunning = false
    }

    public var diagnosticSources: [DiagnosticSource] {
        snapshot.observations.compactMap { resolved in
            let observation = resolved.observation
            guard let descriptor = providerDescriptors.first(where: {
                $0.id == observation.transportIdentity.providerID
            }),
            let capability = descriptor.capabilities.first(where: {
                $0.operation == .sample && $0.parameterPath == observation.parameterPath
            }) else { return nil }
            return DiagnosticSource(
                id: WidgetSourceID(observationIdentity: resolved.observationIdentity),
                accessoryID: resolved.identity.physicalAccessory.id,
                transportID: resolved.identity.transportIdentity.id,
                providerID: descriptor.id,
                parameterPath: observation.parameterPath,
                displayName: "\(resolved.identity.physicalAccessory.displayName) · \(observation.parameterPath.rawValue)",
                operation: capability.operation
            )
        }
        .reduce(into: [WidgetSourceID: DiagnosticSource]()) { $0[$1.id] = $1 }
        .values
        .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    public func startDiagnostic(
        name: String,
        purpose: String,
        sourceIDs: Set<WidgetSourceID>,
        duration: TimeInterval?,
        samplingPolicy: SamplingPolicy
    ) async throws {
        if activeDiagnostic != nil {
            await stopDiagnostic(reason: .replaced)
        }
        let sources = diagnosticSources.filter { sourceIDs.contains($0.id) }
        guard !sources.isEmpty else {
            throw DiagnosticControlError.noSources
        }
        let run = DiagnosticRun(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Diagnostic \(Date.now.formatted())" : name,
            purpose: purpose,
            startedAt: .now,
            plannedDuration: duration,
            state: .running,
            sources: sources,
            samplingPolicy: samplingPolicy
        )
        activeDiagnostic = run
        diagnosticRuns.insert(run, at: 0)
        try await database?.saveDiagnosticRun(run)
        await hub.record(TimelineEvent(
            kind: .diagnostic,
            message: "Diagnostic started: \(run.name)"
        ))
        diagnosticTask?.cancel()
        diagnosticTask = Task { [weak self] in
            await self?.runDiagnostic(id: run.id)
        }
    }

    public func stopDiagnostic(reason: DiagnosticEndReason = .userStopped) async {
        guard var run = activeDiagnostic else { return }
        diagnosticTask?.cancel()
        diagnosticTask = nil
        run.state = .completed
        run.endedAt = .now
        run.endReason = reason
        activeDiagnostic = nil
        replaceDiagnostic(run)
        try? await database?.saveDiagnosticRun(run)
        await hub.record(TimelineEvent(
            kind: .diagnostic,
            message: "Diagnostic stopped: \(run.name)"
        ))
    }

    public func systemWillSleep() async {
        guard let run = activeDiagnostic else { return }
        diagnosticTask?.cancel()
        diagnosticTask = nil
        let gap = DiagnosticGap(sessionID: run.id, reason: .systemSleep)
        sleepGap = gap
        try? await database?.saveDiagnosticGap(gap)
        if var active = activeDiagnostic {
            active.gapCount += 1
            activeDiagnostic = active
            replaceDiagnostic(active)
            try? await database?.saveDiagnosticRun(active)
        }
    }

    public func systemDidWake() async {
        guard var gap = sleepGap, let run = activeDiagnostic else { return }
        gap.endedAt = .now
        sleepGap = nil
        try? await database?.saveDiagnosticGap(gap)
        diagnosticTask = Task { [weak self] in
            await self?.runDiagnostic(id: run.id)
        }
    }

    public func observations(for run: DiagnosticRun, limit: Int = 10_000) async throws -> [ResolvedObservation] {
        if let database {
            return try await database.observations(
                matching: ObservationQuery(sessionID: run.id, limit: limit)
            )
        }
        return snapshot.history.filter { $0.observation.sessionID == run.id }
    }

    private func runDiagnostic(id: UUID) async {
        guard let run = activeDiagnostic, run.id == id else { return }
        var interval = diagnosticInterval(for: run.samplingPolicy)
        let deadline = run.plannedDuration.map { (run.startedAt ?? .now).addingTimeInterval($0) }
        while !Task.isCancelled {
            if let deadline, Date.now >= deadline {
                await stopDiagnostic(reason: .durationReached)
                return
            }
            let succeeded = await sampleActiveDiagnostic()
            if case let .adaptive(minimumSeconds, maximumSeconds) = run.samplingPolicy {
                interval = succeeded
                    ? max(2, minimumSeconds)
                    : min(max(maximumSeconds, minimumSeconds), interval * 2)
            }
            do {
                try await Task.sleep(for: .seconds(interval))
            } catch {
                return
            }
        }
    }

    private func sampleActiveDiagnostic() async -> Bool {
        guard var run = activeDiagnostic else { return false }
        let transports = snapshot.transports.values.flatMap { $0 }
        var allSucceeded = true
        for source in run.sources {
            guard let transport = transports.first(where: { $0.id == source.transportID }) else {
                await recordGap(for: run, source: source, reason: .providerUnavailable)
                run.gapCount += 1
                allSucceeded = false
                continue
            }
            let sampled = await hub.sample(
                providerID: source.providerID,
                request: ProviderSampleRequest(
                    transport: transport,
                    parameterPath: source.parameterPath,
                    sessionID: run.id
                )
            )
            if sampled {
                run.sampleCount += 1
            } else {
                await recordGap(for: run, source: source, reason: .samplingFailed)
                run.gapCount += 1
                allSucceeded = false
            }
        }
        activeDiagnostic = run
        replaceDiagnostic(run)
        try? await database?.saveDiagnosticRun(run)
        return allSucceeded
    }

    private func recordGap(
        for run: DiagnosticRun,
        source: DiagnosticSource,
        reason: DiagnosticGapReason
    ) async {
        let gap = DiagnosticGap(sessionID: run.id, sourceID: source.id, reason: reason)
        try? await database?.saveDiagnosticGap(gap)
    }

    private func diagnosticInterval(for policy: SamplingPolicy) -> TimeInterval {
        switch policy {
        case .eventOnly:
            return 60
        case let .fixedInterval(seconds):
            return max(2, seconds)
        case let .adaptive(minimumSeconds, _):
            return max(2, minimumSeconds)
        }
    }

    private func replaceDiagnostic(_ run: DiagnosticRun) {
        if let index = diagnosticRuns.firstIndex(where: { $0.id == run.id }) {
            diagnosticRuns[index] = run
        } else {
            diagnosticRuns.insert(run, at: 0)
        }
    }

    private func recoverInterruptedDiagnostics() async throws {
        for var run in diagnosticRuns where run.state == .running || run.state == .stopping {
            run.state = .interrupted
            run.endedAt = .now
            run.endReason = .applicationTerminated
            run.gapCount += 1
            replaceDiagnostic(run)
            try await database?.saveDiagnosticRun(run)
            try await database?.saveDiagnosticGap(DiagnosticGap(
                sessionID: run.id,
                reason: .applicationRestarted,
                detail: "The application restarted before the session stopped."
            ))
        }
    }

    private func evaluateRules(in snapshot: HubSnapshot) async {
        for observation in snapshot.observations {
            let sourceID = WidgetSourceID(observationIdentity: observation.observationIdentity)
            let previous = lastRuleObservations[sourceID]
            lastRuleObservations[sourceID] = observation
            for rule in rules where rule.isEnabled && rule.sourceID == sourceID {
                guard ruleMatches(rule, observation: observation, previous: previous),
                      canTrigger(rule) else { continue }
                await trigger(
                    rule,
                    observation: observation,
                    summary: "\(rule.name): \(observation.observation.value?.compactDescription ?? observation.observation.availability.code.rawValue)"
                )
            }
        }

        for status in snapshot.providerStatuses {
            defer { lastProviderStates[status.providerID] = status.state }
            guard lastProviderStates[status.providerID] != nil,
                  lastProviderStates[status.providerID] != status.state,
                  status.state != .running else { continue }
            let sourceID = WidgetSourceID(rawValue: "provider:\(status.providerID.rawValue)")
            for rule in rules where rule.isEnabled && rule.sourceID == sourceID && canTrigger(rule) {
                await trigger(rule, observation: nil, summary: "\(rule.name): \(status.state.rawValue)")
            }
        }
    }

    private func ruleMatches(
        _ rule: RuleDefinition,
        observation: ResolvedObservation,
        previous: ResolvedObservation?
    ) -> Bool {
        switch rule.predicate {
        case let .availability(code):
            return observation.observation.availability.code == code
        case let .numericBelow(limit):
            return numericValue(observation.observation.value).map { $0 < limit } ?? false
        case let .numericAbove(limit):
            return numericValue(observation.observation.value).map { $0 > limit } ?? false
        case .changed:
            guard let previous else { return false }
            return previous.observation.value != observation.observation.value
                || previous.observation.availability != observation.observation.availability
        }
    }

    private func numericValue(_ value: RawValue?) -> Double? {
        switch value {
        case let .signedInt(value): Double(value)
        case let .unsignedInt(value): Double(value)
        case let .double(value): value
        case let .decimal(value): Double(value)
        default: nil
        }
    }

    private func canTrigger(_ rule: RuleDefinition) -> Bool {
        guard let last = lastRuleTriggerDates[rule.id] else { return true }
        return Date.now.timeIntervalSince(last) >= max(60, rule.minimumRepeatInterval)
    }

    private func trigger(
        _ rule: RuleDefinition,
        observation: ResolvedObservation?,
        summary: String
    ) async {
        lastRuleTriggerDates[rule.id] = .now
        let trigger = RuleTrigger(
            ruleID: rule.id,
            sessionID: observation?.observation.sessionID,
            observationID: observation?.id,
            summary: summary
        )
        try? await database?.saveRuleTrigger(trigger)
        await hub.record(TimelineEvent(kind: .diagnostic, message: summary))
        guard notificationsAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "LinkScope"
        content.body = summary
        content.sound = .default
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: trigger.id.uuidString, content: content, trigger: nil)
        )
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
#if DEBUG
            Self.logger.info("Snapshot captured: \(archive.id.uuidString, privacy: .public)")
#else
            Self.logger.info("Snapshot captured")
#endif
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
#if DEBUG
        Self.logger.info("Snapshot imported: \(archive.id.uuidString, privacy: .public)")
#else
        Self.logger.info("Snapshot imported")
#endif
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

    private var keychainService: String {
        "cc.jasonstu.linkscope.\(edition.rawValue).storage"
    }

    private func prepareStorageIfAlreadyAuthorized() async {
        guard database == nil,
              KeychainMasterKey.accessStatus(service: keychainService) == .available else {
            return
        }
        do {
            try await configurePersistence(allowAuthenticationUI: false)
            keychainPermissionState = .allowed
            persistenceError = nil
        } catch {
            keychainPermissionState = .unavailable
            persistenceError = error.localizedDescription
        }
    }

    private func configurePersistence(allowAuthenticationUI: Bool) async throws {
        guard database == nil else {
            await restoreDatabaseIfNeeded()
            return
        }
        let keyData = try KeychainMasterKey.loadOrCreate(
            service: keychainService,
            allowAuthenticationUI: allowAuthenticationUI,
            operationPrompt: allowAuthenticationUI
                ? "LinkScope needs its storage key to reopen saved history and diagnostics."
                : nil
        )
        let keys = try DatabaseKeyMaterial(masterKeyData: keyData)
        let databaseURL = try Self.databaseURL(edition: edition)
        let database = try ObservationDatabase(url: databaseURL, keyMaterial: keys)
        self.database = database
        await hub.setSink(database)
        await restoreDatabaseIfNeeded()
    }

    private func restoreDatabaseIfNeeded() async {
        guard !didRestoreDatabase, let database else { return }
        do {
            try await database.removeDevelopmentFixtures()
            async let observations = database.observations(matching: ObservationQuery(limit: 5_000))
            async let statuses = database.providerStatuses()
            async let timeline = database.timeline(limit: 1_000)
            async let snapshots = database.snapshots(limit: 100)
            async let runs = database.diagnosticRuns()
            async let rules = database.rules()
            let restored = try await (observations, statuses, timeline, snapshots, runs, rules)
            savedSnapshots = restored.3
            diagnosticRuns = restored.4
            self.rules = restored.5
            try await recoverInterruptedDiagnostics()
            await hub.seed(
                observations: restored.0,
                statuses: restored.1,
                timeline: restored.2
            )
            didRestoreDatabase = true
        } catch {
            persistenceError = error.localizedDescription
#if DEBUG
            Self.logger.error("History restore failed: \(error.localizedDescription, privacy: .public)")
#else
            Self.logger.error("History restore failed")
#endif
        }
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
