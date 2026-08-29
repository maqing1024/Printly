import Foundation

/// Persisted user preferences for the batch printer.
nonisolated struct AppSettings: Sendable, Equatable, Codable {
    var presets: [PrintPreset]
    var history: [PrintHistoryRecord]
    var sortOrder: FileSortOrder
    var enabledKinds: [FileKind]
    var archiveEnabled: Bool
    var archiveFolderPath: String?
    var hotFolderEnabled: Bool
    var hotFolderPath: String?
    var hotFolderAutoPrint: Bool

    static let `default` = AppSettings(
        presets: [],
        history: [],
        sortOrder: .name,
        enabledKinds: FileKind.allCases,
        archiveEnabled: false,
        archiveFolderPath: nil,
        hotFolderEnabled: false,
        hotFolderPath: nil,
        hotFolderAutoPrint: false
    )

    /// Kinds that should appear in the queue. Empty input is treated as all kinds.
    var enabledKindSet: Set<FileKind> {
        let set = Set(enabledKinds)
        return set.isEmpty ? Set(FileKind.allCases) : set
    }
}
