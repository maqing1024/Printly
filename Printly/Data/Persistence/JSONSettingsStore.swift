import Foundation

/// JSON file store for presets, history, and folder preferences.
nonisolated struct JSONSettingsStore: SettingsStoring {
    private let fileURL: URL
    private let historyLimit: Int

    /// Creates a settings store.
    /// - Parameters:
    ///   - fileURL: Destination JSON file.
    ///   - historyLimit: Maximum history rows to keep (newest first).
    init(fileURL: URL? = nil, historyLimit: Int = 200) {
        self.fileURL = fileURL ?? Self.defaultFileURL
        self.historyLimit = historyLimit
    }

    static var defaultFileURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return root
            .appendingPathComponent("Printly", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    func load() -> AppSettings {
        guard let data = try? Data(contentsOf: fileURL) else {
            return .default
        }
        return (try? JSONDecoder().decode(AppSettings.self, from: data)) ?? .default
    }

    func save(_ settings: AppSettings) {
        var trimmed = settings
        if trimmed.history.count > historyLimit {
            trimmed.history = Array(trimmed.history.prefix(historyLimit))
        }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(trimmed)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Persistence is best-effort; printing should still work.
        }
    }
}
