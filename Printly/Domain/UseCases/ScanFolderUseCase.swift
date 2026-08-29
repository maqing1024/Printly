import Foundation

/// Coordinates folder scanning for the batch print feature.
nonisolated struct ScanFolderUseCase: Sendable {
    private let scanner: any FolderScanning

    /// Creates a scan use case.
    /// - Parameter scanner: Folder scanning implementation.
    init(scanner: any FolderScanning) {
        self.scanner = scanner
    }

    /// Scans `rootURL` for supported printable files.
    /// - Parameter rootURL: Dropped or selected folder.
    /// - Returns: Classified and sorted files.
    func execute(_ rootURL: URL) async throws -> [PrintableFile] {
        try await scanner.scan(rootURL: rootURL)
    }
}
