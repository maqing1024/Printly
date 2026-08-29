import Foundation

/// Sorts printable files by natural file-name order (case-insensitive).
nonisolated struct FileSorter: Sendable {
    /// Returns files sorted by display name using natural comparison.
    /// - Parameter files: Unsorted printable files.
    /// - Returns: Stably sorted copy; ties broken by relative path.
    func sorted(_ files: [PrintableFile]) -> [PrintableFile] {
        files.sorted { lhs, rhs in
            let nameOrder = lhs.displayName.compare(
                rhs.displayName,
                options: [.numeric, .caseInsensitive]
            )
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }
            return lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
        }
    }
}
