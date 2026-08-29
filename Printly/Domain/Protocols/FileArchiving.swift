import Foundation

/// Copies successfully printed files into an archive folder.
nonisolated protocol FileArchiving: Sendable {
    /// Copies `files` into `folder`, using a dated subfolder.
    func archive(_ files: [PrintableFile], to folder: URL) throws
}
