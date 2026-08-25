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
    public private(set) var dashboards: [DashboardDocument] = []
    public private(set) var dashboardHistoryRevision = 0
    public private(set) var dashboardLiveSeries: [
        WidgetSourceID: [DashboardTimeSeriesPoint]
    ] = [:]
    public private(set) var notificationsAuthorized = false
    public private(set) var retentionCandidateCount = 0
    public private(set) var keychainPermissionState: LinkScopePermissionState = .unknown
    public private(set) var bluetoothPermissionState: LinkScopePermissionState = .unknown
    public private(set) var notificationPermissionState: LinkScopePermissionState = .unknown

    private let hub: ObservationHub
    private let coreBluetoothProvider: CoreBluetoothProvider?
    private let ioBluetoothProvider: IOBluetoothProvider?
    private var database: ObservationDatabase?
    private var didRestoreDatabase = false
    private var snapshotTask: Task<Void, Never>?
    private var diagnosticTask: Task<Void, Never>?
    private var dashboardPersistenceTask: Task<Void, Never>?
    private var dashboardHistoryCache: [DashboardHistoryRequestKey: DashboardHistoryCacheEntry] = [:]
    private var dashboardHistoryInFlight: [
        DashboardHistoryRequestKey: Task<[ResolvedObservation], Error>
    ] = [:]
    private var lastRuleObservations: [WidgetSourceID: ResolvedObservation] = [:]
    private var lastRuleTriggerDates: [UUID: Date] = [:]
    private var lastProviderStates: [ProviderID: ProviderState] = [:]
    private var sleepGap: DiagnosticGap?
    private var openSourceGaps: [WidgetSourceID: DiagnosticGap] = [:]
    private var isRequestingKeychainAccess = false
    private var isRequestingBluetoothAccess = false
    private var isRequestingNotificationAccess = false
    private static let logger = Logger(subsystem: "cc.jasonstu.linkscope", category: "application")

    public init(edition: LinkScopeEdition) {
        self.edition = edition
        let providers = PublicProviderFactory.makeProviders()
        self.providerDescriptors = providers.map(\.descriptor)
        self.coreBluetoothProvider = providers.compactMap { $0 as? CoreBluetoothProvider }.first
        self.ioBluetoothProvider = providers.compactMap { $0 as? IOBluetoothProvider }.first
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
                self?.recordDashboardLiveSeries(from: value.observations)
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
        if database != nil {
            keychainPermissionState = .allowed
        } else {
            await prepareStorageIfAlreadyAuthorized()
        }

        let authorization = CBManager.authorization
        bluetoothPermissionState = permissionState(for: authorization)
        if isRunning, authorization != .notDetermined {
            await coreBluetoothProvider?.start()
            await ioBluetoothProvider?.start()
        }

        await refreshNotificationAuthorization()
    }

    public func requestKeychainAccess() async {
        guard !isRequestingKeychainAccess else { return }
        isRequestingKeychainAccess = true
        keychainPermissionState = .unknown
        defer { isRequestingKeychainAccess = false }

        let service = keychainService
        do {
            let keyData = try await Task.detached(priority: .userInitiated) {
                try KeychainMasterKey.authorizeAndMigrateLegacyKey(
                    service: service,
                    operationPrompt: "LinkScope needs its storage key to reopen saved history and diagnostics."
                )
            }.value
            try await configurePersistence(masterKeyData: keyData)
            keychainPermissionState = .allowed
            persistenceError = nil
        } catch {
            if let keyMaterialError = error as? KeyMaterialError,
               case let .keychain(status) = keyMaterialError,
               status == errSecUserCanceled {
                keychainPermissionState = .notRequested
                persistenceError = nil
            } else {
                keychainPermissionState = .denied
                persistenceError = error.localizedDescription
            }
        }
    }

    public func requestBluetoothAccess() async {
        guard !isRequestingBluetoothAccess else { return }
        isRequestingBluetoothAccess = true
        bluetoothPermissionState = .unknown
        defer { isRequestingBluetoothAccess = false }

        // start() is intentionally non-interactive: both Bluetooth providers
        // refuse framework access while authorization is undetermined.
        await start()
        guard let coreBluetoothProvider else {
            bluetoothPermissionState = .unavailable
            return
        }
        let authorization = await coreBluetoothProvider.requestAuthorization()
        bluetoothPermissionState = permissionState(for: authorization)
        await ioBluetoothProvider?.start()
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
        guard !isRequestingNotificationAccess else { return }
        isRequestingNotificationAccess = true
        notificationPermissionState = .unknown
        defer { isRequestingNotificationAccess = false }

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

    /// Applies dashboard edits immediately for a responsive canvas, then
    /// serializes encrypted persistence in edit order. Memory-only sessions
    /// retain the same behavior without prompting for Keychain access.
    public func applyDashboard(_ dashboard: DashboardDocument) {
        let dashboard = dashboard.schemaVersion <= DashboardDocument.currentSchemaVersion
            ? DashboardLayoutEngine.normalized(dashboard)
            : dashboard
        replaceDashboard(dashboard)
        enqueueDashboardPersistence { database in
            _ = try await database.saveDashboard(dashboard)
        }
    }

    public func deleteDashboard(id: UUID) {
        dashboards.removeAll { $0.id == id }
        enqueueDashboardPersistence { database in
            _ = try await database.deleteDashboard(id: id)
        }
    }

    /// Fetches one exact stable widget source through the indexed persistence
    /// query. The view performs numeric decimation off the main actor.
    public func dashboardHistory(
        for sourceID: WidgetSourceID,
        limit: Int = 5_000
    ) async throws -> [ResolvedObservation] {
        let boundedLimit = max(1, min(limit, 20_000))
        let requestKey = DashboardHistoryRequestKey(
            sourceID: sourceID,
            limit: boundedLimit,
            revision: dashboardHistoryRevision
        )
        if let cached = dashboardHistoryCache[requestKey],
           Date.now.timeIntervalSince(cached.loadedAt) < 15 {
            return cached.observations
        }
        if let inFlight = dashboardHistoryInFlight[requestKey] {
            return try await inFlight.value
        }

        let database = self.database
        let inMemoryHistory = snapshot.history
        let query = ObservationQuery(widgetSourceID: sourceID, limit: boundedLimit)
        let task: Task<[ResolvedObservation], Error> = Task.detached(priority: .userInitiated) {
            if let database,
               let query {
                return try await database.observations(matching: query)
            }
            return inMemoryHistory.filter {
                WidgetSourceID(observationIdentity: $0.observationIdentity) == sourceID
            }
            .sorted { $0.observation.timestamp > $1.observation.timestamp }
            .prefix(boundedLimit)
            .map { $0 }
        }
        dashboardHistoryInFlight[requestKey] = task
        do {
            let observations = try await task.value
            dashboardHistoryInFlight.removeValue(forKey: requestKey)
            if requestKey.revision == dashboardHistoryRevision {
                dashboardHistoryCache[requestKey] = DashboardHistoryCacheEntry(
                    loadedAt: .now,
                    observations: observations
                )
            }
            return observations
        } catch {
            dashboardHistoryInFlight.removeValue(forKey: requestKey)
            throw error
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
            invalidateDashboardHistory()
        } catch {
            persistenceError = error.localizedDescription
        }
    }

    public func stop() async {
        await flushForTermination()
        guard isRunning else { return }
        snapshotTask?.cancel()
        snapshotTask = nil
        await stopDiagnostic(reason: .applicationTerminated)
        await hub.stop()
        isRunning = false
    }

    /// Called by the shared AppDelegate's terminate-later path so the final
    /// queued layout edit reaches SQLite before either edition replies to
    /// macOS termination.
    public func flushForTermination() async {
        await dashboardPersistenceTask?.value
    }

    public var diagnosticSources: [DiagnosticSource] {
        DiagnosticSourceCatalog.sampleSources(
            observations: snapshot.observations,
            providers: providerDescriptors
        )
    }

    /// Every currently observed parameter can be monitored, even when its
    /// provider does not offer active sampling (for example, battery events).
    public var monitoringSources: [DiagnosticSource] {
        DiagnosticSourceCatalog.monitoringSources(
            observations: snapshot.observations,
            providers: providerDescriptors
        )
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
        let endedAt = Date.now
        await closeAllSourceGaps(at: endedAt)
        if var gap = sleepGap {
            gap.endedAt = endedAt
            sleepGap = nil
            try? await database?.saveDiagnosticGap(gap)
        }
        run.state = .completed
        run.endedAt = endedAt
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
        await closeAllSourceGaps(at: .now)
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
        let deadline = run.plannedDuration.map { (run.startedAt ?? .now).addingTimeInterval($0) }
        guard var interval = DiagnosticSamplingScheduler.periodicInterval(
            for: run.samplingPolicy
        ) else {
            guard let deadline else { return }
            let remaining = max(0, deadline.timeIntervalSinceNow)
            do {
                try await Task.sleep(for: .seconds(remaining))
            } catch {
                return
            }
            guard activeDiagnostic?.id == id else { return }
            await stopDiagnostic(reason: .durationReached)
            return
        }
        while !Task.isCancelled {
            if let deadline, Date.now >= deadline {
                await stopDiagnostic(reason: .durationReached)
                return
            }
            let succeeded = await sampleActiveDiagnostic()
            if case let .adaptive(minimumSeconds, maximumSeconds) = run.samplingPolicy {
                interval = DiagnosticSamplingScheduler.nextAdaptiveInterval(
                    current: interval,
                    minimumSeconds: minimumSeconds,
                    maximumSeconds: maximumSeconds,
                    sampleSucceeded: succeeded
                )
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
            guard !Task.isCancelled, activeDiagnostic?.id == run.id else {
                return false
            }
            guard snapshot.providerStatuses.first(where: {
                $0.providerID == source.providerID
            })?.state == .running else {
                if await transitionGap(
                    for: run,
                    source: source,
                    reason: .providerUnavailable
                ) {
                    run.gapCount += 1
                }
                allSucceeded = false
                continue
            }
            guard let transport = transports.first(where: { $0.id == source.transportID }) else {
                if await transitionGap(
                    for: run,
                    source: source,
                    reason: .providerUnavailable
                ) {
                    run.gapCount += 1
                }
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
            guard !Task.isCancelled, activeDiagnostic?.id == run.id else {
                return false
            }
            if sampled {
                _ = await transitionGap(for: run, source: source, reason: nil)
                run.sampleCount += 1
            } else {
                if await transitionGap(for: run, source: source, reason: .samplingFailed) {
                    run.gapCount += 1
                }
                allSucceeded = false
            }
        }
        guard !Task.isCancelled, activeDiagnostic?.id == run.id else {
            return false
        }
        activeDiagnostic = run
        replaceDiagnostic(run)
        try? await database?.saveDiagnosticRun(run)
        return allSucceeded
    }

    /// Returns true only when a new gap is opened. Repeated failures preserve
    /// one record until recovery instead of adding a row on every sample tick.
    private func transitionGap(
        for run: DiagnosticRun,
        source: DiagnosticSource,
        reason: DiagnosticGapReason?,
        at date: Date = .now
    ) async -> Bool {
        if var existing = openSourceGaps[source.id] {
            if existing.sessionID == run.id,
               let reason,
               existing.reason == reason {
                return false
            }
            existing.endedAt = date
            openSourceGaps.removeValue(forKey: source.id)
            try? await database?.saveDiagnosticGap(existing)
        }
        guard let reason else { return false }
        let gap = DiagnosticGap(
            sessionID: run.id,
            sourceID: source.id,
            startedAt: date,
            reason: reason
        )
        openSourceGaps[source.id] = gap
        try? await database?.saveDiagnosticGap(gap)
        return true
    }

    private func closeAllSourceGaps(at date: Date) async {
        let gaps = Array(openSourceGaps.values)
        openSourceGaps.removeAll(keepingCapacity: true)
        for var gap in gaps {
            gap.endedAt = date
            try? await database?.saveDiagnosticGap(gap)
        }
    }

    private func replaceDiagnostic(_ run: DiagnosticRun) {
        if let index = diagnosticRuns.firstIndex(where: { $0.id == run.id }) {
            diagnosticRuns[index] = run
        } else {
            diagnosticRuns.insert(run, at: 0)
        }
    }

    private func replaceDashboard(_ dashboard: DashboardDocument) {
        if let index = dashboards.firstIndex(where: { $0.id == dashboard.id }) {
            dashboards[index] = dashboard
        } else {
            dashboards.append(dashboard)
        }
        dashboards.sort {
            let comparison = $0.name.localizedCaseInsensitiveCompare($1.name)
            if comparison != .orderedSame { return comparison == .orderedAscending }
            if $0.name != $1.name { return $0.name < $1.name }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    private func recordDashboardLiveSeries(from observations: [ResolvedObservation]) {
        let latestPoints = DashboardTimeSeriesDecimator.numericPoints(from: observations)
        guard !latestPoints.isEmpty else { return }
        var updatedSeries = dashboardLiveSeries
        var didChange = false
        for point in latestPoints {
            var series = updatedSeries[point.sourceID, default: []]
            guard !series.contains(where: { $0.observationID == point.observationID }) else {
                continue
            }
            series.append(point)
            series.sort {
                if $0.timestamp != $1.timestamp { return $0.timestamp < $1.timestamp }
                return $0.observationID.uuidString < $1.observationID.uuidString
            }
            if series.count > 120 {
                series.removeFirst(series.count - 120)
            }
            updatedSeries[point.sourceID] = series
            didChange = true
        }
        if didChange {
            dashboardLiveSeries = updatedSeries
        }
    }

    private func enqueueDashboardPersistence(
        _ operation: @escaping @Sendable (ObservationDatabase) async throws -> Void
    ) {
        let previousTask = dashboardPersistenceTask
        dashboardPersistenceTask = Task { [weak self] in
            await previousTask?.value
            guard let self, let database = self.database else { return }
            do {
                try await operation(database)
            } catch {
                self.persistenceError = error.localizedDescription
            }
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
                guard MonitoringRuleEvaluator.matches(
                    rule.predicate,
                    observation: observation.observation,
                    previous: previous?.observation
                ),
                      canTrigger(rule) else { continue }
                await trigger(
                    rule,
                    observation: observation,
                    summary: "\(rule.name): \(observation.observation.value?.compactDescription ?? observation.observation.availability.code.rawValue)"
                )
            }
        }

        for status in snapshot.providerStatuses {
            let previous = lastProviderStates[status.providerID]
            lastProviderStates[status.providerID] = status.state
            guard previous != nil, previous != status.state else { continue }
            let sourceID = WidgetSourceID(rawValue: "provider:\(status.providerID.rawValue)")
            for rule in rules where rule.isEnabled && rule.sourceID == sourceID {
                guard MonitoringRuleEvaluator.matchesProviderStatus(
                    rule.predicate,
                    state: status.state,
                    previous: previous
                ), canTrigger(rule) else { continue }
                await trigger(rule, observation: nil, summary: "\(rule.name): \(status.state.rawValue)")
            }
        }
    }

    private func canTrigger(_ rule: RuleDefinition) -> Bool {
        MonitoringRuleEvaluator.canTrigger(
            minimumRepeatInterval: rule.minimumRepeatInterval,
            lastTriggeredAt: lastRuleTriggerDates[rule.id],
            now: .now
        )
    }

    private func trigger(
        _ rule: RuleDefinition,
        observation: ResolvedObservation?,
        summary: String
    ) async {
        let triggeredAt = Date.now
        lastRuleTriggerDates[rule.id] = triggeredAt
        let trigger = RuleTrigger(
            ruleID: rule.id,
            sessionID: observation?.observation.sessionID,
            observationID: observation?.id,
            triggeredAt: triggeredAt,
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
            invalidateDashboardHistory()
        } else {
            savedSnapshots.insert(archive, at: 0)
            await hub.seed(
                observations: archive.observations,
                statuses: archive.providerStatuses,
                timeline: archive.timeline
            )
            invalidateDashboardHistory()
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
        guard database == nil else {
            keychainPermissionState = .allowed
            return
        }

        switch KeychainMasterKey.readDataProtectionKeyNonInteractive(service: keychainService) {
        case let .available(keyData):
            do {
                try await configurePersistence(masterKeyData: keyData)
                keychainPermissionState = .allowed
                persistenceError = nil
            } catch {
                keychainPermissionState = .unavailable
                persistenceError = error.localizedDescription
            }
        case .notConfigured:
            keychainPermissionState = .notRequested
        case .authorizationRequired:
            keychainPermissionState = .denied
        case let .unavailable(status):
            keychainPermissionState = .unavailable
            persistenceError = KeyMaterialError.keychain(status).localizedDescription
        }
    }

    private func configurePersistence(masterKeyData: Data) async throws {
        guard database == nil else {
            await restoreDatabaseIfNeeded()
            return
        }
        let keys = try DatabaseKeyMaterial(masterKeyData: masterKeyData)
        let databaseURL = try Self.databaseURL(edition: edition)
        let database = try ObservationDatabase(url: databaseURL, keyMaterial: keys)
        self.database = database
        await hub.setSink(database)
        await restoreDatabaseIfNeeded()
    }

    private func permissionState(for authorization: CBManagerAuthorization) -> LinkScopePermissionState {
        switch authorization {
        case .allowedAlways: .allowed
        case .notDetermined: .notRequested
        case .denied, .restricted: .denied
        @unknown default: .unavailable
        }
    }

    private func restoreDatabaseIfNeeded() async {
        guard !didRestoreDatabase, let database else { return }
        do {
            try await database.removeDevelopmentFixtures()
            for dashboard in dashboards {
                _ = try await database.saveDashboard(dashboard)
            }
            async let observations = database.observations(matching: ObservationQuery(limit: 5_000))
            async let statuses = database.providerStatuses()
            async let timeline = database.timeline(limit: 1_000)
            async let snapshots = database.snapshots(limit: 100)
            async let runs = database.diagnosticRuns()
            async let rules = database.rules()
            async let triggerDates = database.latestRuleTriggerDates()
            async let dashboards = database.dashboards()
            let restored = try await (
                observations,
                statuses,
                timeline,
                snapshots,
                runs,
                rules,
                triggerDates,
                dashboards
            )
            savedSnapshots = restored.3
            diagnosticRuns = restored.4
            self.rules = restored.5
            lastRuleTriggerDates = restored.6
            self.dashboards = restored.7
            try await recoverInterruptedDiagnostics()
            await hub.seed(
                observations: restored.0,
                statuses: restored.1,
                timeline: restored.2
            )
            invalidateDashboardHistory()
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

    private func invalidateDashboardHistory() {
        dashboardHistoryInFlight.values.forEach { $0.cancel() }
        dashboardHistoryInFlight.removeAll(keepingCapacity: false)
        dashboardHistoryCache.removeAll(keepingCapacity: false)
        dashboardHistoryRevision &+= 1
    }
}

private struct DashboardHistoryRequestKey: Hashable {
    let sourceID: WidgetSourceID
    let limit: Int
    let revision: Int
}

private struct DashboardHistoryCacheEntry {
    let loadedAt: Date
    let observations: [ResolvedObservation]
}
