import Foundation

/// Observes a directory for content changes (hot folder).
@MainActor
protocol FolderWatching: AnyObject {
    /// Starts watching `url` and invokes `onChange` after a short debounce.
    func start(url: URL, onChange: @escaping () -> Void)
    /// Stops the current watch, if any.
    func stop()
}
