import Foundation
import LinkScopeCore

public enum DashboardSchemaCompatibility: Equatable, Sendable {
    case older(Int)
    case current
    case newer(Int)
}

/// Portable dashboard JSON. Newer schemas are decoded without rejecting or
/// rewriting their unknown widget kinds and extension fields, allowing Full
/// and Lite to render placeholders and export the document again losslessly.
public enum DashboardDocumentCodec {
    public static func encode(
        _ dashboard: DashboardDocument,
        pretty: Bool = true
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = pretty
            ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            : [.sortedKeys]
        return try encoder.encode(dashboard)
    }

    public static func decode(_ data: Data) throws -> DashboardDocument {
        try JSONDecoder().decode(DashboardDocument.self, from: data)
    }

    public static func compatibility(
        of dashboard: DashboardDocument
    ) -> DashboardSchemaCompatibility {
        if dashboard.schemaVersion < DashboardDocument.currentSchemaVersion {
            return .older(dashboard.schemaVersion)
        }
        if dashboard.schemaVersion > DashboardDocument.currentSchemaVersion {
            return .newer(dashboard.schemaVersion)
        }
        return .current
    }
}
