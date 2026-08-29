import Foundation

/// Two-sided printing mode sent to the printer.
nonisolated enum DuplexMode: String, CaseIterable, Sendable, Equatable, Codable {
    case simplex
    case longEdge
    case shortEdge
}

/// Color output requested for the batch.
nonisolated enum ColorMode: String, CaseIterable, Sendable, Equatable, Codable {
    case color
    case blackAndWhite
}

/// Batch-wide print options applied to every job in the queue.
nonisolated struct PrintSettings: Sendable, Equatable, Codable {
    var copies: Int
    var duplex: DuplexMode
    var colorMode: ColorMode
    var pageRangeText: String

    static let `default` = PrintSettings(
        copies: 1,
        duplex: .simplex,
        colorMode: .color,
        pageRangeText: ""
    )

    /// Parsed page range, or a parse failure for invalid user input.
    var resolvedPageRange: Result<PageRange, PageRangeParseError> {
        PageRange.parse(pageRangeText)
    }

    /// Clamps copies into the supported 1...99 range.
    mutating func clampCopies() {
        copies = min(99, max(1, copies))
    }
}
