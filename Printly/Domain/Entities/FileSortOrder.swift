import Foundation

/// User-selectable order for the print queue.
nonisolated enum FileSortOrder: String, CaseIterable, Sendable, Equatable, Codable {
    case name
    case kind
    case path
}
