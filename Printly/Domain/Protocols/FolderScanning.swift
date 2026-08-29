import Foundation

/// Recursively discovers printable files under a folder.
nonisolated protocol FolderScanning: Sendable {
    /// Scans `rootURL` and returns classified, sorted printable files.
    /// - Parameter rootURL: Folder or supported file chosen by the user.
    /// - Returns: Supported files ready for the print pipeline.
    func scan(rootURL: URL) async throws -> [PrintableFile]
}
