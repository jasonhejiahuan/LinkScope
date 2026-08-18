import SwiftUI
import UniformTypeIdentifiers

public struct SnapshotDocument: FileDocument {
    public static var readableContentTypes: [UTType] { [.json] }

    private let data: Data

    public init(data: Data) {
        self.data = data
    }

    public init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

