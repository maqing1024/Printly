import Foundation

/// Supported printable file categories for the batch printer.
nonisolated enum FileKind: String, Sendable, CaseIterable, Equatable, Codable {
    case pdf
    case word
    case excel
    case image
    case markdown
}
