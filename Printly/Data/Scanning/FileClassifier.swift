import Foundation

/// Maps file extensions to `FileKind`, ignoring unsupported types.
nonisolated struct FileClassifier: Sendable {
    private static let extensionMap: [String: FileKind] = [
        "pdf": .pdf,
        "jpg": .image,
        "jpeg": .image,
        "png": .image,
        "heic": .image,
        "docx": .word,
        "xlsx": .excel,
        "md": .markdown,
        "markdown": .markdown,
    ]

    /// Classifies a file by its path extension.
    /// - Parameter url: File URL to classify.
    /// - Returns: Matching kind, or `nil` if unsupported.
    func classify(_ url: URL) -> FileKind? {
        let ext = url.pathExtension.lowercased()
        return Self.extensionMap[ext]
    }
}
