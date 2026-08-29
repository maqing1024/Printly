import Foundation

/// Error raised when a page-range string cannot be parsed.
nonisolated enum PageRangeParseError: Error, Equatable, Sendable {
    case invalid
}

/// 1-based inclusive page segments. An empty list means every page.
nonisolated struct PageRange: Sendable, Equatable {
    let segments: [ClosedRange<Int>]

    static let all = PageRange(segments: [])

    var isAllPages: Bool { segments.isEmpty }

    /// Returns whether 1-based `pageNumber` is included.
    func contains(_ pageNumber: Int) -> Bool {
        isAllPages || segments.contains { $0.contains(pageNumber) }
    }

    /// Parses `text` such as `1-3,5,8-10`. Blank input means all pages.
    static func parse(_ text: String) -> Result<PageRange, PageRangeParseError> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .success(.all) }

        var segments: [ClosedRange<Int>] = []
        for rawPart in trimmed.split(separator: ",", omittingEmptySubsequences: false) {
            let piece = rawPart.trimmingCharacters(in: .whitespaces)
            if piece.isEmpty { return .failure(.invalid) }

            if let dash = piece.firstIndex(of: "-") {
                let startText = piece[..<dash].trimmingCharacters(in: .whitespaces)
                let endText = piece[piece.index(after: dash)...].trimmingCharacters(in: .whitespaces)
                guard let start = Int(startText), let end = Int(endText), start >= 1, end >= start else {
                    return .failure(.invalid)
                }
                segments.append(start...end)
            } else {
                guard let page = Int(piece), page >= 1 else {
                    return .failure(.invalid)
                }
                segments.append(page...page)
            }
        }

        return .success(PageRange(segments: segments))
    }
}
