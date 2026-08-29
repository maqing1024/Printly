import Foundation

/// Debounced directory watcher using `DispatchSource` (macOS 12.4+).
@MainActor
final class DirectoryWatcher: FolderWatching {
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var debounceTask: Task<Void, Never>?

    func start(url: URL, onChange: @escaping () -> Void) {
        stop()

        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        fileDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend],
            queue: DispatchQueue.main
        )
        source.setEventHandler { [weak self] in
            self?.debounceTask?.cancel()
            self?.debounceTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 800_000_000)
                guard !Task.isCancelled else { return }
                onChange()
            }
        }
        source.setCancelHandler {
            close(fd)
        }
        self.source = source
        source.resume()
    }

    func stop() {
        debounceTask?.cancel()
        debounceTask = nil
        source?.cancel()
        source = nil
        fileDescriptor = -1
    }
}
