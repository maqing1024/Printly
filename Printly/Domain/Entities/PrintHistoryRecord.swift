import Foundation

/// One finished print attempt stored for later review.
nonisolated struct PrintHistoryRecord: Identifiable, Sendable, Equatable, Codable {
    var id: UUID
    var date: Date
    var fileName: String
    var kind: FileKind
    var printerName: String
    var succeeded: Bool
    var message: String?

    /// Creates a history record.
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        fileName: String,
        kind: FileKind,
        printerName: String,
        succeeded: Bool,
        message: String? = nil
    ) {
        self.id = id
        self.date = date
        self.fileName = fileName
        self.kind = kind
        self.printerName = printerName
        self.succeeded = succeeded
        self.message = message
    }
}
