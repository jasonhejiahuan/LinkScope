import CryptoKit
import Foundation
import LinkScopeCore
import SQLite3

public struct ObservationQuery: Sendable {
    public var physicalAccessoryID: UUID?
    public var providerID: ProviderID?
    public var parameterPath: ParameterPath?
    public var availability: AvailabilityCode?
    public var eventID: UUID?
    public var sessionID: UUID?
    public var from: Date?
    public var through: Date?
    public var limit: Int

    public init(
        physicalAccessoryID: UUID? = nil,
        providerID: ProviderID? = nil,
        parameterPath: ParameterPath? = nil,
        availability: AvailabilityCode? = nil,
        eventID: UUID? = nil,
        sessionID: UUID? = nil,
        from: Date? = nil,
        through: Date? = nil,
        limit: Int = 500
    ) {
        self.physicalAccessoryID = physicalAccessoryID
        self.providerID = providerID
        self.parameterPath = parameterPath
        self.availability = availability
        self.eventID = eventID
        self.sessionID = sessionID
        self.from = from
        self.through = through
        self.limit = max(1, limit)
    }
}

public enum ObservationDatabaseError: Error, LocalizedError {
    case open(String)
    case sqlite(code: Int32, message: String, sql: String)
    case newerSchema(found: Int, supported: Int)
    case corruptPayload

    public var errorDescription: String? {
        switch self {
        case let .open(message):
            "Unable to open the LinkScope database: \(message)"
        case let .sqlite(code, message, sql):
            "SQLite error \(code): \(message) [\(sql)]"
        case let .newerSchema(found, supported):
            "Database schema \(found) is newer than supported schema \(supported)."
        case .corruptPayload:
            "An encrypted database payload was missing or corrupt."
        }
    }
}

public actor ObservationDatabase: ObservationSink {
    public static let currentSchemaVersion = 4

    private let connection: SQLiteConnection
    private let keys: DatabaseKeyMaterial
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(url: URL, keyMaterial: DatabaseKeyMaterial) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var opened: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        let status = sqlite3_open_v2(url.path, &opened, flags, nil)
        guard status == SQLITE_OK, let opened else {
            let message = opened.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            if let opened { sqlite3_close(opened) }
            throw ObservationDatabaseError.open(message)
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        do {
            try Self.execute(opened, sql: "PRAGMA journal_mode=WAL;")
            try Self.execute(opened, sql: "PRAGMA foreign_keys=ON;")
            try Self.execute(opened, sql: "PRAGMA synchronous=NORMAL;")
            try Self.migrate(opened)
        } catch {
            sqlite3_close(opened)
            throw error
        }
        self.connection = SQLiteConnection(handle: opened)
        self.keys = keyMaterial
        self.encoder = encoder
        self.decoder = decoder
    }

    public func persist(_ observation: ResolvedObservation) throws {
        guard !DevelopmentFixturePolicy.isDevelopmentFixture(
            observation.identity.transportIdentity
        ) else { return }
        let encryptedObservation = try encrypted(observation)
        let encryptedAccessoryName = try encrypted(observation.identity.physicalAccessory.displayName)
        let encryptedTransport = try encrypted(observation.identity.transportIdentity)
        let identityDigest = keys.identityDigest(observation.identity.transportIdentity.exactKey)

        try transaction {
            let accessorySQL = """
                INSERT INTO physical_accessories(id, display_name_payload, created_at)
                VALUES(?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET display_name_payload = excluded.display_name_payload;
                """
            try withStatement(accessorySQL) { statement in
                bind(observation.identity.physicalAccessory.id.uuidString, at: 1, to: statement)
                bind(encryptedAccessoryName, at: 2, to: statement)
                bind(observation.identity.physicalAccessory.createdAt.timeIntervalSince1970, at: 3, to: statement)
                try stepDone(statement, sql: accessorySQL)
            }

            let transportSQL = """
                INSERT INTO transport_identities(
                    id, physical_accessory_id, provider_id, kind, identity_hash,
                    encrypted_payload, first_seen_at, last_seen_at
                ) VALUES(?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(provider_id, identity_hash) DO UPDATE SET
                    physical_accessory_id = excluded.physical_accessory_id,
                    encrypted_payload = excluded.encrypted_payload,
                    last_seen_at = excluded.last_seen_at;
                """
            try withStatement(transportSQL) { statement in
                bind(observation.identity.transportIdentity.id.uuidString, at: 1, to: statement)
                bind(observation.identity.physicalAccessory.id.uuidString, at: 2, to: statement)
                bind(observation.observation.transportIdentity.providerID.rawValue, at: 3, to: statement)
                bind(observation.identity.transportIdentity.kind.rawValue, at: 4, to: statement)
                bind(identityDigest, at: 5, to: statement)
                bind(encryptedTransport, at: 6, to: statement)
                bind(observation.observation.timestamp.timeIntervalSince1970, at: 7, to: statement)
                bind(observation.observation.timestamp.timeIntervalSince1970, at: 8, to: statement)
                try stepDone(statement, sql: transportSQL)
            }

            let observationSQL = """
                INSERT OR REPLACE INTO observations(
                    id, physical_accessory_id, transport_identity_id, provider_id,
                    parameter_path, observed_at, availability, value_type,
                    event_id, session_id, sensitivity, encrypted_payload
                ) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """
            try withStatement(observationSQL) { statement in
                bind(observation.id.uuidString, at: 1, to: statement)
                bind(observation.identity.physicalAccessory.id.uuidString, at: 2, to: statement)
                bind(observation.identity.transportIdentity.id.uuidString, at: 3, to: statement)
                bind(observation.observation.transportIdentity.providerID.rawValue, at: 4, to: statement)
                bind(observation.observation.parameterPath.rawValue, at: 5, to: statement)
                bind(observation.observation.timestamp.timeIntervalSince1970, at: 6, to: statement)
                bind(observation.observation.availability.code.rawValue, at: 7, to: statement)
                bind(observation.observation.value?.valueType.rawValue, at: 8, to: statement)
                bind(observation.observation.eventID?.uuidString, at: 9, to: statement)
                bind(observation.observation.sessionID?.uuidString, at: 10, to: statement)
                bind(observation.observation.sensitivity.rawValue, at: 11, to: statement)
                bind(encryptedObservation, at: 12, to: statement)
                try stepDone(statement, sql: observationSQL)
            }
        }
    }

    public func persist(_ status: ProviderStatus) throws {
        guard !DevelopmentFixturePolicy.isDevelopmentProvider(status.providerID) else { return }
        let sql = """
            INSERT INTO provider_status(provider_id, state, updated_at, encrypted_payload)
            VALUES(?, ?, ?, ?)
            ON CONFLICT(provider_id) DO UPDATE SET
                state = excluded.state,
                updated_at = excluded.updated_at,
                encrypted_payload = excluded.encrypted_payload;
            """
        let payload = try encrypted(status)
        try withStatement(sql) { statement in
            bind(status.providerID.rawValue, at: 1, to: statement)
            bind(status.state.rawValue, at: 2, to: statement)
            bind(status.updatedAt.timeIntervalSince1970, at: 3, to: statement)
            bind(payload, at: 4, to: statement)
            try stepDone(statement, sql: sql)
        }
    }

    public func persist(_ event: TimelineEvent) throws {
        if let providerID = event.providerID,
           DevelopmentFixturePolicy.isDevelopmentProvider(providerID) { return }
        let sql = """
            INSERT OR REPLACE INTO timeline_events(
                id, provider_id, kind, occurred_at, encrypted_payload
            ) VALUES(?, ?, ?, ?, ?);
            """
        let payload = try encrypted(event)
        try withStatement(sql) { statement in
            bind(event.id.uuidString, at: 1, to: statement)
            bind(event.providerID?.rawValue, at: 2, to: statement)
            bind(event.kind.rawValue, at: 3, to: statement)
            bind(event.timestamp.timeIntervalSince1970, at: 4, to: statement)
            bind(payload, at: 5, to: statement)
            try stepDone(statement, sql: sql)
        }
    }

    public func observations(matching query: ObservationQuery = ObservationQuery()) throws -> [ResolvedObservation] {
        var clauses: [String] = []
        var bindings: [SQLBinding] = []

        if let value = query.physicalAccessoryID {
            clauses.append("physical_accessory_id = ?")
            bindings.append(.text(value.uuidString))
        }
        if let value = query.providerID {
            clauses.append("provider_id = ?")
            bindings.append(.text(value.rawValue))
        }
        if let value = query.parameterPath {
            clauses.append("parameter_path = ?")
            bindings.append(.text(value.rawValue))
        }
        if let value = query.availability {
            clauses.append("availability = ?")
            bindings.append(.text(value.rawValue))
        }
        if let value = query.eventID {
            clauses.append("event_id = ?")
            bindings.append(.text(value.uuidString))
        }
        if let value = query.sessionID {
            clauses.append("session_id = ?")
            bindings.append(.text(value.uuidString))
        }
        if let value = query.from {
            clauses.append("observed_at >= ?")
            bindings.append(.double(value.timeIntervalSince1970))
        }
        if let value = query.through {
            clauses.append("observed_at <= ?")
            bindings.append(.double(value.timeIntervalSince1970))
        }

        let whereClause = clauses.isEmpty ? "" : " WHERE " + clauses.joined(separator: " AND ")
        let sql = """
            SELECT encrypted_payload FROM observations
            \(whereClause)
            ORDER BY observed_at DESC
            LIMIT ?;
            """
        bindings.append(.int(Int64(query.limit)))

        return try withStatement(sql) { statement in
            for (offset, binding) in bindings.enumerated() {
                bind(binding, at: Int32(offset + 1), to: statement)
            }
            var results: [ResolvedObservation] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                let data = try columnData(statement, index: 0)
                results.append(try decrypted(ResolvedObservation.self, from: data))
            }
            return results
        }
    }

    public func providerStatuses() throws -> [ProviderStatus] {
        let sql = "SELECT encrypted_payload FROM provider_status ORDER BY provider_id;"
        return try withStatement(sql) { statement in
            var results: [ProviderStatus] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                results.append(try decrypted(ProviderStatus.self, from: columnData(statement, index: 0)))
            }
            return results
        }
    }

    public func timeline(limit: Int = 1_000) throws -> [TimelineEvent] {
        let sql = "SELECT encrypted_payload FROM timeline_events ORDER BY occurred_at DESC LIMIT ?;"
        return try withStatement(sql) { statement in
            bind(Int64(max(1, limit)), at: 1, to: statement)
            var results: [TimelineEvent] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                results.append(try decrypted(TimelineEvent.self, from: columnData(statement, index: 0)))
            }
            return results
        }
    }

    public func saveSnapshot(_ archive: SnapshotArchive) throws {
        let sql = """
            INSERT OR REPLACE INTO snapshots(id, name, created_at, schema_version, encrypted_payload)
            VALUES(?, ?, ?, ?, ?);
            """
        let cleanArchive = sanitized(archive)
        let payload = try encrypted(cleanArchive)
        try withStatement(sql) { statement in
            bind(cleanArchive.id.uuidString, at: 1, to: statement)
            bind(cleanArchive.name, at: 2, to: statement)
            bind(cleanArchive.createdAt.timeIntervalSince1970, at: 3, to: statement)
            bind(Int64(cleanArchive.schemaVersion), at: 4, to: statement)
            bind(payload, at: 5, to: statement)
            try stepDone(statement, sql: sql)
        }
    }

    public func importSnapshot(_ archive: SnapshotArchive) throws {
        for observation in archive.observations {
            try persist(observation)
        }
        for status in archive.providerStatuses {
            try persist(status)
        }
        for event in archive.timeline {
            try persist(event)
        }
        try saveSnapshot(archive)
    }

    public func snapshots(limit: Int = 100) throws -> [SnapshotArchive] {
        let sql = "SELECT encrypted_payload FROM snapshots ORDER BY created_at DESC LIMIT ?;"
        return try withStatement(sql) { statement in
            bind(Int64(max(1, min(limit, 1_000))), at: 1, to: statement)
            var results: [SnapshotArchive] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                results.append(try decrypted(SnapshotArchive.self, from: columnData(statement, index: 0)))
            }
            return results
        }
    }

    public func saveDiagnosticRun(_ run: DiagnosticRun) throws {
        let sql = """
            INSERT OR REPLACE INTO diagnostic_sessions(
                id, created_at, ended_at, schema_version, encrypted_payload
            ) VALUES(?, ?, ?, ?, ?);
            """
        let payload = try encrypted(run)
        try withStatement(sql) { statement in
            bind(run.id.uuidString, at: 1, to: statement)
            bind(run.createdAt.timeIntervalSince1970, at: 2, to: statement)
            if let endedAt = run.endedAt {
                bind(endedAt.timeIntervalSince1970, at: 3, to: statement)
            } else {
                bind(nil as String?, at: 3, to: statement)
            }
            bind(Int64(run.schemaVersion), at: 4, to: statement)
            bind(payload, at: 5, to: statement)
            try stepDone(statement, sql: sql)
        }
    }

    public func diagnosticRuns(limit: Int = 500) throws -> [DiagnosticRun] {
        let sql = """
            SELECT encrypted_payload FROM diagnostic_sessions
            ORDER BY created_at DESC LIMIT ?;
            """
        return try withStatement(sql) { statement in
            bind(Int64(max(1, min(limit, 5_000))), at: 1, to: statement)
            var results: [DiagnosticRun] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                let data = try columnData(statement, index: 0)
                if let run = try? decrypted(DiagnosticRun.self, from: data) {
                    results.append(run)
                }
            }
            return results
        }
    }

    public func saveDiagnosticGap(_ gap: DiagnosticGap) throws {
        let sql = """
            INSERT OR REPLACE INTO diagnostic_gaps(
                id, session_id, started_at, ended_at, reason, encrypted_payload
            ) VALUES(?, ?, ?, ?, ?, ?);
            """
        let payload = try encrypted(gap)
        try withStatement(sql) { statement in
            bind(gap.id.uuidString, at: 1, to: statement)
            bind(gap.sessionID.uuidString, at: 2, to: statement)
            bind(gap.startedAt.timeIntervalSince1970, at: 3, to: statement)
            if let endedAt = gap.endedAt {
                bind(endedAt.timeIntervalSince1970, at: 4, to: statement)
            } else {
                bind(nil as String?, at: 4, to: statement)
            }
            bind(gap.reason.rawValue, at: 5, to: statement)
            bind(payload, at: 6, to: statement)
            try stepDone(statement, sql: sql)
        }
    }

    public func diagnosticGaps(sessionID: UUID) throws -> [DiagnosticGap] {
        let sql = """
            SELECT encrypted_payload FROM diagnostic_gaps
            WHERE session_id = ? ORDER BY started_at;
            """
        return try withStatement(sql) { statement in
            bind(sessionID.uuidString, at: 1, to: statement)
            var results: [DiagnosticGap] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                results.append(try decrypted(DiagnosticGap.self, from: columnData(statement, index: 0)))
            }
            return results
        }
    }

    public func saveRule(_ rule: RuleDefinition) throws {
        let sql = """
            INSERT OR REPLACE INTO rule_definitions(
                id, enabled, schema_version, encrypted_payload
            ) VALUES(?, ?, ?, ?);
            """
        let payload = try encrypted(rule)
        try withStatement(sql) { statement in
            bind(rule.id.uuidString, at: 1, to: statement)
            bind(Int64(rule.isEnabled ? 1 : 0), at: 2, to: statement)
            bind(Int64(rule.schemaVersion), at: 3, to: statement)
            bind(payload, at: 4, to: statement)
            try stepDone(statement, sql: sql)
        }
    }

    public func rules() throws -> [RuleDefinition] {
        let sql = "SELECT encrypted_payload FROM rule_definitions ORDER BY enabled DESC, id;"
        return try withStatement(sql) { statement in
            var results: [RuleDefinition] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                results.append(try decrypted(RuleDefinition.self, from: columnData(statement, index: 0)))
            }
            return results
        }
    }

    public func deleteRule(id: UUID) throws {
        let sql = "DELETE FROM rule_definitions WHERE id = ?;"
        try withStatement(sql) { statement in
            bind(id.uuidString, at: 1, to: statement)
            try stepDone(statement, sql: sql)
        }
    }

    public func saveRuleTrigger(_ trigger: RuleTrigger) throws {
        let sql = """
            INSERT OR REPLACE INTO rule_triggers(
                id, rule_id, session_id, triggered_at, encrypted_payload
            ) VALUES(?, ?, ?, ?, ?);
            """
        let payload = try encrypted(trigger)
        try withStatement(sql) { statement in
            bind(trigger.id.uuidString, at: 1, to: statement)
            bind(trigger.ruleID.uuidString, at: 2, to: statement)
            bind(trigger.sessionID?.uuidString, at: 3, to: statement)
            bind(trigger.triggeredAt.timeIntervalSince1970, at: 4, to: statement)
            bind(payload, at: 5, to: statement)
            try stepDone(statement, sql: sql)
        }
    }

    public func ruleTriggers(
        ruleID: UUID? = nil,
        limit: Int = 500
    ) throws -> [RuleTrigger] {
        let sql: String
        if ruleID == nil {
            sql = """
                SELECT encrypted_payload FROM rule_triggers
                ORDER BY triggered_at DESC LIMIT ?;
                """
        } else {
            sql = """
                SELECT encrypted_payload FROM rule_triggers
                WHERE rule_id = ? ORDER BY triggered_at DESC LIMIT ?;
                """
        }
        return try withStatement(sql) { statement in
            var bindingIndex: Int32 = 1
            if let ruleID {
                bind(ruleID.uuidString, at: bindingIndex, to: statement)
                bindingIndex += 1
            }
            bind(Int64(max(1, min(limit, 100_000))), at: bindingIndex, to: statement)
            var results: [RuleTrigger] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                results.append(try decrypted(
                    RuleTrigger.self,
                    from: columnData(statement, index: 0)
                ))
            }
            return results
        }
    }

    public func latestRuleTriggerDates() throws -> [UUID: Date] {
        let sql = """
            SELECT candidate.encrypted_payload
            FROM rule_triggers AS candidate
            WHERE candidate.id = (
                SELECT latest.id FROM rule_triggers AS latest
                WHERE latest.rule_id = candidate.rule_id
                ORDER BY latest.triggered_at DESC, latest.id DESC
                LIMIT 1
            )
            ORDER BY candidate.rule_id;
            """
        return try withStatement(sql) { statement in
            var results: [UUID: Date] = [:]
            while sqlite3_step(statement) == SQLITE_ROW {
                let trigger = try decrypted(
                    RuleTrigger.self,
                    from: columnData(statement, index: 0)
                )
                results[trigger.ruleID] = trigger.triggeredAt
            }
            return results
        }
    }

    public func schemaVersion() throws -> Int {
        try Self.schemaVersion(connection.handle)
    }

    public func checkpoint() throws {
        try Self.execute(connection.handle, sql: "PRAGMA wal_checkpoint(TRUNCATE);")
    }

    public func observationCount(olderThan date: Date) throws -> Int {
        let sql = "SELECT COUNT(*) FROM observations WHERE observed_at < ?;"
        return try withStatement(sql) { statement in
            bind(date.timeIntervalSince1970, at: 1, to: statement)
            guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
            return Int(sqlite3_column_int64(statement, 0))
        }
    }

    @discardableResult
    public func deleteObservations(olderThan date: Date) throws -> Int {
        let count = try observationCount(olderThan: date)
        let sql = "DELETE FROM observations WHERE observed_at < ?;"
        try withStatement(sql) { statement in
            bind(date.timeIntervalSince1970, at: 1, to: statement)
            try stepDone(statement, sql: sql)
        }
        return count
    }

    /// Removes only LinkScope development fixtures. This never reads or writes
    /// macOS Bluetooth preferences, paired-device records, or system databases.
    public func removeDevelopmentFixtures() throws {
        try transaction {
            try Self.execute(connection.handle, sql: Self.developmentFixtureCleanupSQL)
        }
        for archive in try snapshots(limit: 1_000) {
            let cleanArchive = sanitized(archive)
            if cleanArchive != archive {
                try saveSnapshot(cleanArchive)
            }
        }
    }

    private func sanitized(_ archive: SnapshotArchive) -> SnapshotArchive {
        let observations = archive.observations.filter {
            !DevelopmentFixturePolicy.isDevelopmentFixture($0.identity.transportIdentity)
        }
        let accessoryIDs = Set(observations.map { $0.identity.physicalAccessory.id })
        return SnapshotArchive(
            schemaVersion: archive.schemaVersion,
            id: archive.id,
            name: archive.name,
            createdAt: archive.createdAt,
            edition: archive.edition,
            accessories: archive.accessories.filter { accessoryIDs.contains($0.id) },
            observations: observations,
            providerStatuses: archive.providerStatuses.filter {
                !DevelopmentFixturePolicy.isDevelopmentProvider($0.providerID)
            },
            timeline: archive.timeline.filter {
                guard let providerID = $0.providerID else { return true }
                return !DevelopmentFixturePolicy.isDevelopmentProvider(providerID)
            }
        )
    }

    private func encrypted<T: Encodable>(_ value: T) throws -> Data {
        try PayloadCipher.seal(encoder.encode(value), using: keys.encryptionKey)
    }

    private func decrypted<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let plaintext = try PayloadCipher.open(data, using: keys.encryptionKey)
        return try decoder.decode(type, from: plaintext)
    }

    private func transaction(_ body: () throws -> Void) throws {
        try Self.execute(connection.handle, sql: "BEGIN IMMEDIATE;")
        do {
            try body()
            try Self.execute(connection.handle, sql: "COMMIT;")
        } catch {
            try? Self.execute(connection.handle, sql: "ROLLBACK;")
            throw error
        }
    }

    private func withStatement<T>(_ sql: String, _ body: (OpaquePointer) throws -> T) throws -> T {
        var statement: OpaquePointer?
        let status = sqlite3_prepare_v2(connection.handle, sql, -1, &statement, nil)
        guard status == SQLITE_OK, let statement else {
            throw sqliteError(code: status, sql: sql)
        }
        defer { sqlite3_finalize(statement) }
        return try body(statement)
    }

    private func stepDone(_ statement: OpaquePointer, sql: String) throws {
        let status = sqlite3_step(statement)
        guard status == SQLITE_DONE else {
            throw sqliteError(code: status, sql: sql)
        }
    }

    private func sqliteError(code: Int32, sql: String) -> ObservationDatabaseError {
        .sqlite(code: code, message: String(cString: sqlite3_errmsg(connection.handle)), sql: sql)
    }

    private func bind(_ binding: SQLBinding, at index: Int32, to statement: OpaquePointer) {
        switch binding {
        case let .text(value): bind(value, at: index, to: statement)
        case let .double(value): bind(value, at: index, to: statement)
        case let .int(value): bind(value, at: index, to: statement)
        }
    }

    private func bind(_ value: String?, at index: Int32, to statement: OpaquePointer) {
        guard let value else {
            sqlite3_bind_null(statement, index)
            return
        }
        sqlite3_bind_text(statement, index, value, -1, Self.sqliteTransient)
    }

    private func bind(_ value: Data, at index: Int32, to statement: OpaquePointer) {
        _ = value.withUnsafeBytes { buffer in
            sqlite3_bind_blob(statement, index, buffer.baseAddress, Int32(buffer.count), Self.sqliteTransient)
        }
    }

    private func bind(_ value: Double, at index: Int32, to statement: OpaquePointer) {
        sqlite3_bind_double(statement, index, value)
    }

    private func bind(_ value: Int64, at index: Int32, to statement: OpaquePointer) {
        sqlite3_bind_int64(statement, index, value)
    }

    private func columnData(_ statement: OpaquePointer, index: Int32) throws -> Data {
        guard let bytes = sqlite3_column_blob(statement, index) else {
            throw ObservationDatabaseError.corruptPayload
        }
        let count = Int(sqlite3_column_bytes(statement, index))
        return Data(bytes: bytes, count: count)
    }

    private static var sqliteTransient: sqlite3_destructor_type {
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    }

    private static func execute(_ connection: OpaquePointer, sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        let status = sqlite3_exec(connection, sql, nil, nil, &errorMessage)
        guard status == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) }
                ?? String(cString: sqlite3_errmsg(connection))
            sqlite3_free(errorMessage)
            throw ObservationDatabaseError.sqlite(code: status, message: message, sql: sql)
        }
    }

    private static func schemaVersion(_ connection: OpaquePointer) throws -> Int {
        var statement: OpaquePointer?
        let sql = "SELECT COALESCE(MAX(version), 0) FROM schema_migrations;"
        let status = sqlite3_prepare_v2(connection, sql, -1, &statement, nil)
        guard status == SQLITE_OK, let statement else {
            return 0
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(statement, 0))
    }

    private static func migrate(_ connection: OpaquePointer) throws {
        try execute(connection, sql: """
            CREATE TABLE IF NOT EXISTS schema_migrations(
                version INTEGER PRIMARY KEY,
                applied_at REAL NOT NULL
            );
            """)
        var version = try schemaVersion(connection)
        guard version <= currentSchemaVersion else {
            throw ObservationDatabaseError.newerSchema(found: version, supported: currentSchemaVersion)
        }

        if version < 1 {
            try applyMigration(1, sql: migration1, connection: connection)
            version = 1
        }
        if version < 2 {
            try applyMigration(2, sql: migration2, connection: connection)
            version = 2
        }
        if version < 3 {
            try applyMigration(3, sql: developmentFixtureCleanupSQL, connection: connection)
            version = 3
        }
        if version < 4 {
            try applyMigration(4, sql: migration4, connection: connection)
        }
    }

    private static func applyMigration(
        _ version: Int,
        sql: String,
        connection: OpaquePointer
    ) throws {
        try execute(connection, sql: "BEGIN IMMEDIATE;")
        do {
            try execute(connection, sql: sql)
            try execute(connection, sql: """
                INSERT OR IGNORE INTO schema_migrations(version, applied_at)
                VALUES(\(version), \(Date.now.timeIntervalSince1970));
                """)
            try execute(connection, sql: "COMMIT;")
        } catch {
            try? execute(connection, sql: "ROLLBACK;")
            throw error
        }
    }

    private static let migration1 = """
        CREATE TABLE IF NOT EXISTS physical_accessories(
            id TEXT PRIMARY KEY,
            display_name_payload BLOB NOT NULL,
            created_at REAL NOT NULL
        );
        CREATE TABLE IF NOT EXISTS transport_identities(
            id TEXT PRIMARY KEY,
            physical_accessory_id TEXT NOT NULL REFERENCES physical_accessories(id),
            provider_id TEXT NOT NULL,
            kind TEXT NOT NULL,
            identity_hash BLOB NOT NULL,
            encrypted_payload BLOB NOT NULL,
            first_seen_at REAL NOT NULL,
            last_seen_at REAL NOT NULL,
            UNIQUE(provider_id, identity_hash)
        );
        CREATE TABLE IF NOT EXISTS observations(
            id TEXT PRIMARY KEY,
            physical_accessory_id TEXT NOT NULL REFERENCES physical_accessories(id),
            transport_identity_id TEXT NOT NULL,
            provider_id TEXT NOT NULL,
            parameter_path TEXT NOT NULL,
            observed_at REAL NOT NULL,
            availability TEXT NOT NULL,
            value_type TEXT,
            event_id TEXT,
            session_id TEXT,
            sensitivity TEXT NOT NULL,
            encrypted_payload BLOB NOT NULL
        );
        CREATE INDEX IF NOT EXISTS observations_device_time
            ON observations(physical_accessory_id, observed_at DESC);
        CREATE INDEX IF NOT EXISTS observations_provider_path_time
            ON observations(provider_id, parameter_path, observed_at DESC);
        CREATE INDEX IF NOT EXISTS observations_availability_time
            ON observations(availability, observed_at DESC);
        CREATE INDEX IF NOT EXISTS observations_event ON observations(event_id) WHERE event_id IS NOT NULL;
        CREATE INDEX IF NOT EXISTS observations_session ON observations(session_id) WHERE session_id IS NOT NULL;
        CREATE TABLE IF NOT EXISTS provider_status(
            provider_id TEXT PRIMARY KEY,
            state TEXT NOT NULL,
            updated_at REAL NOT NULL,
            encrypted_payload BLOB NOT NULL
        );
        CREATE TABLE IF NOT EXISTS timeline_events(
            id TEXT PRIMARY KEY,
            provider_id TEXT,
            kind TEXT NOT NULL,
            occurred_at REAL NOT NULL,
            encrypted_payload BLOB NOT NULL
        );
        CREATE INDEX IF NOT EXISTS timeline_occurred_at ON timeline_events(occurred_at DESC);
        CREATE TABLE IF NOT EXISTS snapshots(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            created_at REAL NOT NULL,
            schema_version INTEGER NOT NULL,
            encrypted_payload BLOB NOT NULL
        );
        """

    private static let migration2 = """
        CREATE TABLE IF NOT EXISTS diagnostic_sessions(
            id TEXT PRIMARY KEY,
            created_at REAL NOT NULL,
            ended_at REAL,
            schema_version INTEGER NOT NULL,
            encrypted_payload BLOB NOT NULL
        );
        CREATE TABLE IF NOT EXISTS rule_definitions(
            id TEXT PRIMARY KEY,
            enabled INTEGER NOT NULL,
            schema_version INTEGER NOT NULL,
            encrypted_payload BLOB NOT NULL
        );
        CREATE TABLE IF NOT EXISTS dashboard_documents(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            schema_version INTEGER NOT NULL,
            encrypted_payload BLOB NOT NULL
        );
        CREATE TABLE IF NOT EXISTS provider_capabilities(
            provider_id TEXT NOT NULL,
            capability_id TEXT NOT NULL,
            operation TEXT NOT NULL,
            experimental INTEGER NOT NULL,
            validated_at REAL,
            encrypted_payload BLOB,
            PRIMARY KEY(provider_id, capability_id)
        );
        """

    private static let developmentFixtureCleanupSQL = """
        DELETE FROM observations
        WHERE lower(provider_id) IN ('mock', 'test', 'fixture')
           OR lower(provider_id) LIKE 'mock.%'
           OR lower(provider_id) LIKE 'test.%'
           OR lower(provider_id) LIKE 'fixture.%';
        DELETE FROM transport_identities
        WHERE kind = 'mock'
           OR lower(provider_id) IN ('mock', 'test', 'fixture')
           OR lower(provider_id) LIKE 'mock.%'
           OR lower(provider_id) LIKE 'test.%'
           OR lower(provider_id) LIKE 'fixture.%';
        DELETE FROM provider_status
        WHERE lower(provider_id) IN ('mock', 'test', 'fixture')
           OR lower(provider_id) LIKE 'mock.%'
           OR lower(provider_id) LIKE 'test.%'
           OR lower(provider_id) LIKE 'fixture.%';
        DELETE FROM timeline_events
        WHERE lower(provider_id) IN ('mock', 'test', 'fixture')
           OR lower(provider_id) LIKE 'mock.%'
           OR lower(provider_id) LIKE 'test.%'
           OR lower(provider_id) LIKE 'fixture.%';
        DELETE FROM physical_accessories
        WHERE id NOT IN (SELECT physical_accessory_id FROM transport_identities)
          AND id NOT IN (SELECT physical_accessory_id FROM observations);
        """

    private static let migration4 = """
        CREATE INDEX IF NOT EXISTS observations_session_path_time
            ON observations(session_id, parameter_path, observed_at DESC)
            WHERE session_id IS NOT NULL;
        CREATE TABLE IF NOT EXISTS diagnostic_gaps(
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            started_at REAL NOT NULL,
            ended_at REAL,
            reason TEXT NOT NULL,
            encrypted_payload BLOB NOT NULL
        );
        CREATE INDEX IF NOT EXISTS diagnostic_gaps_session_time
            ON diagnostic_gaps(session_id, started_at);
        CREATE TABLE IF NOT EXISTS rule_triggers(
            id TEXT PRIMARY KEY,
            rule_id TEXT NOT NULL,
            session_id TEXT,
            triggered_at REAL NOT NULL,
            encrypted_payload BLOB NOT NULL
        );
        CREATE INDEX IF NOT EXISTS rule_triggers_rule_time
            ON rule_triggers(rule_id, triggered_at DESC);
        """
}

private enum SQLBinding {
    case text(String)
    case double(Double)
    case int(Int64)
}

private final class SQLiteConnection: @unchecked Sendable {
    let handle: OpaquePointer

    init(handle: OpaquePointer) {
        self.handle = handle
    }

    deinit {
        sqlite3_close(handle)
    }
}
