import Foundation

/// A named snapshot of printer + print options.
nonisolated struct PrintPreset: Identifiable, Sendable, Equatable, Codable {
    var id: UUID
    var name: String
    var printerName: String?
    var settings: PrintSettings

    /// Creates a print preset.
    init(
        id: UUID = UUID(),
        name: String,
        printerName: String?,
        settings: PrintSettings
    ) {
        self.id = id
        self.name = name
        self.printerName = printerName
        self.settings = settings
    }
}
