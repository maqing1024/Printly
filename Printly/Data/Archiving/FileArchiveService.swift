import Foundation

/// Copies printed files into `archive/yyyy-MM-dd/`.
nonisolated struct FileArchiveService: FileArchiving {
    func archive(_ files: [PrintableFile], to folder: URL) throws {
        guard !files.isEmpty else { return }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let dayFolder = folder.appendingPathComponent(formatter.string(from: Date()), isDirectory: true)
        try FileManager.default.createDirectory(at: dayFolder, withIntermediateDirectories: true)

        for file in files {
            let destination = uniqueURL(in: dayFolder, preferredName: file.displayName)
            try FileManager.default.copyItem(at: file.url, to: destination)
        }
    }

    private func uniqueURL(in folder: URL, preferredName: String) -> URL {
        let preferred = folder.appendingPathComponent(preferredName)
        if !FileManager.default.fileExists(atPath: preferred.path) {
            return preferred
        }
        let stem = (preferredName as NSString).deletingPathExtension
        let ext = (preferredName as NSString).pathExtension
        var index = 2
        while true {
            let name = ext.isEmpty ? "\(stem)-\(index)" : "\(stem)-\(index).\(ext)"
            let candidate = folder.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }
}
