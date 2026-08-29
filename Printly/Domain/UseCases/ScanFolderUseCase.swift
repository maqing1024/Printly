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
    /// - Parameter rootURL: Dropped or selected folder or file.
    /// - Returns: Classified and sorted files.
    func execute(_ rootURL: URL) async throws -> [PrintableFile] {
        try await execute([rootURL])
    }

    /// Scans each URL (file or folder) and returns a merged, sorted list.
    /// - Parameter urls: Dropped or selected items.
    /// - Returns: Deduplicated classified files.
    func execute(_ urls: [URL]) async throws -> [PrintableFile] {
        var discovered: [PrintableFile] = []
        var seenPaths = Set<String>()

        for url in urls {
            let files = try await scanner.scan(rootURL: url)
            for file in files {
                let path = file.url.standardizedFileURL.path
                if seenPaths.insert(path).inserted {
                    discovered.append(file)
                }
            }
        }

        return FileSorter().sorted(discovered)
    }
}
