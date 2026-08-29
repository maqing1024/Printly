import Foundation

/// Recursively walks a folder, classifies supported files, and sorts them.
nonisolated struct RecursiveFolderScanner: FolderScanning {
    private let classifier: FileClassifier
    private let sorter: FileSorter

    /// Creates a recursive folder scanner.
    /// - Parameters:
    ///   - classifier: Extension classifier.
    ///   - sorter: File sorter.
    init(
        classifier: FileClassifier = FileClassifier(),
        sorter: FileSorter = FileSorter()
    ) {
        self.classifier = classifier
        self.sorter = sorter
    }

    func scan(rootURL: URL) async throws -> [PrintableFile] {
        let classifier = classifier
        let sorter = sorter
        return try await Task.detached(priority: .userInitiated) {
            try Self.scanSynchronously(
                rootURL: rootURL,
                classifier: classifier,
                sorter: sorter
            )
        }.value
    }

    /// Performs the directory walk on a cooperative background thread (sync FileManager APIs).
    private static func scanSynchronously(
        rootURL: URL,
        classifier: FileClassifier,
        sorter: FileSorter
    ) throws -> [PrintableFile] {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: rootURL.path, isDirectory: &isDirectory) else {
            throw ScanError.notADirectory
        }

        if !isDirectory.boolValue {
            return try classifySingleFile(
                rootURL,
                classifier: classifier
            )
        }

        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .isHiddenKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw ScanError.enumerationFailed
        }

        var discovered: [PrintableFile] = []

        while let fileURL = enumerator.nextObject() as? URL {
            let name = fileURL.lastPathComponent
            if name.hasPrefix(".") || name == "__MACOSX" {
                enumerator.skipDescendants()
                continue
            }

            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
            if values.isDirectory == true {
                if name == "__MACOSX" {
                    enumerator.skipDescendants()
                }
                continue
            }

            guard values.isRegularFile == true else { continue }
            guard let kind = classifier.classify(fileURL) else { continue }

            let relative = fileURL.path.replacingOccurrences(
                of: rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/",
                with: ""
            )

            discovered.append(
                PrintableFile(
                    url: fileURL,
                    kind: kind,
                    displayName: name,
                    relativePath: relative
                )
            )
        }

        return sorter.sorted(discovered)
    }

    private static func classifySingleFile(
        _ fileURL: URL,
        classifier: FileClassifier
    ) throws -> [PrintableFile] {
        let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true else {
            throw ScanError.notADirectory
        }
        guard let kind = classifier.classify(fileURL) else {
            return []
        }
        return [
            PrintableFile(
                url: fileURL,
                kind: kind,
                displayName: fileURL.lastPathComponent,
                relativePath: fileURL.lastPathComponent
            )
        ]
    }
}

nonisolated enum ScanError: Error, LocalizedError, Sendable {
    case notADirectory
    case enumerationFailed

    var errorDescription: String? {
        switch self {
        case .notADirectory:
            String(localized: "error.notADirectory")
        case .enumerationFailed:
            String(localized: "error.enumerationFailed")
        }
    }
}
