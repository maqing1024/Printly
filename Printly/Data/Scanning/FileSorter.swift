import Foundation

/// Sorts printable files by the user-selected order.
nonisolated struct FileSorter: Sendable {
    /// Returns files sorted by `order`.
    /// - Parameters:
    ///   - files: Unsorted printable files.
    ///   - order: Name, kind, or relative path.
    /// - Returns: Stably sorted copy; remaining ties use relative path.
    func sorted(_ files: [PrintableFile], order: FileSortOrder = .name) -> [PrintableFile] {
        files.sorted { lhs, rhs in
            switch order {
            case .name:
                return compareNameThenPath(lhs, rhs)
            case .kind:
                let kindOrder = lhs.kind.rawValue.compare(rhs.kind.rawValue)
                if kindOrder != .orderedSame {
                    return kindOrder == .orderedAscending
                }
                return compareNameThenPath(lhs, rhs)
            case .path:
                let pathOrder = lhs.relativePath.localizedStandardCompare(rhs.relativePath)
                if pathOrder != .orderedSame {
                    return pathOrder == .orderedAscending
                }
                return compareNameThenPath(lhs, rhs)
            }
        }
    }

    private func compareNameThenPath(_ lhs: PrintableFile, _ rhs: PrintableFile) -> Bool {
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
