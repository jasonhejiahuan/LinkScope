import Foundation
import LinkScopeCore

public enum SnapshotArchiveError: Error, LocalizedError {
    case newerSchema(found: Int, supported: Int)

    public var errorDescription: String? {
        switch self {
        case let .newerSchema(found, supported):
            "Snapshot schema \(found) is newer than supported schema \(supported)."
        }
    }
}

public enum SnapshotArchiveCodec {
    public static func encode(_ archive: SnapshotArchive, pretty: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes] : [.sortedKeys]
        return try encoder.encode(archive)
    }

    public static func decode(_ data: Data) throws -> SnapshotArchive {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let archive = try decoder.decode(SnapshotArchive.self, from: data)
        guard archive.schemaVersion <= SnapshotArchive.currentSchemaVersion else {
            throw SnapshotArchiveError.newerSchema(
                found: archive.schemaVersion,
                supported: SnapshotArchive.currentSchemaVersion
            )
        }
        return archive
    }
}
