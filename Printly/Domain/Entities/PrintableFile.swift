import Foundation

/// A file discovered by the folder scanner that can enter the print pipeline.
nonisolated struct PrintableFile: Identifiable, Sendable, Equatable, Hashable {
    let id: UUID
    let url: URL
    let kind: FileKind
    let displayName: String
    let relativePath: String

    /// Creates a printable file descriptor.
    /// - Parameters:
    ///   - id: Stable identity for list/diff updates.
    ///   - url: Absolute file URL on disk.
    ///   - kind: Classified file category.
    ///   - displayName: File name shown in the UI.
    ///   - relativePath: Path relative to the scanned folder root.
    init(
        id: UUID = UUID(),
        url: URL,
        kind: FileKind,
        displayName: String,
        relativePath: String
    ) {
        self.id = id
        self.url = url
        self.kind = kind
        self.displayName = displayName
        self.relativePath = relativePath
    }
}
