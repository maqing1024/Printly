import Foundation

/// Progress events while downloading and installing LibreOffice.
nonisolated enum LibreOfficeInstallProgress: Sendable, Equatable {
    case downloading(fraction: Double)
    case mounting
    case copying
    case cleaningUp
    case finished
}

/// Errors raised while installing LibreOffice.
nonisolated enum LibreOfficeInstallError: Error, LocalizedError, Sendable {
    case invalidDownloadURL
    case downloadFailed(String)
    case mountFailed
    case appNotFoundInDiskImage
    case copyFailed(String)
    case verificationFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidDownloadURL:
            String(localized: "error.libreOfficeInstallInvalidURL")
        case .downloadFailed(let message):
            message
        case .mountFailed:
            String(localized: "error.libreOfficeInstallMountFailed")
        case .appNotFoundInDiskImage:
            String(localized: "error.libreOfficeInstallAppMissing")
        case .copyFailed(let message):
            message
        case .verificationFailed:
            String(localized: "error.libreOfficeInstallVerifyFailed")
        case .cancelled:
            String(localized: "error.libreOfficeInstallCancelled")
        }
    }
}

/// Downloads the official LibreOffice DMG and installs it into `/Applications`.
nonisolated final class LibreOfficeInstaller: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let fileManager: FileManager
    private let downloadURL: URL
    private let applicationsDirectory: URL

    private var progressHandler: (@Sendable (LibreOfficeInstallProgress) -> Void)?
    private var continuation: CheckedContinuation<URL, Error>?
    private var session: URLSession?
    private var downloadTask: URLSessionDownloadTask?

    /// Creates an installer targeting the official Document Foundation build.
    /// - Parameters:
    ///   - downloadURL: DMG URL. Defaults to the current stable build for this Mac architecture.
    ///   - applicationsDirectory: Install destination (usually `/Applications`).
    ///   - fileManager: File system accessor.
    init(
        downloadURL: URL = LibreOfficeInstaller.defaultDownloadURL,
        applicationsDirectory: URL = URL(fileURLWithPath: "/Applications", isDirectory: true),
        fileManager: FileManager = .default
    ) {
        self.downloadURL = downloadURL
        self.applicationsDirectory = applicationsDirectory
        self.fileManager = fileManager
    }

    /// Default official DMG for the running CPU architecture.
    static var defaultDownloadURL: URL {
        let version = "26.2.4"
        #if arch(arm64)
        let archToken = "aarch64"
        let fileName = "LibreOffice_\(version)_MacOS_aarch64.dmg"
        #else
        let archToken = "x86_64"
        let fileName = "LibreOffice_\(version)_MacOS_x86-64.dmg"
        #endif
        return URL(string:
            "https://download.documentfoundation.org/libreoffice/stable/\(version)/mac/\(archToken)/\(fileName)"
        )!
    }

    /// Returns whether a usable `soffice` binary is already installed.
    static var isLibreOfficeInstalled: Bool {
        LibreOfficeConverter.isInstalled
    }

    /// Downloads and installs LibreOffice, reporting progress.
    /// - Parameter onProgress: Progress callback (may be invoked off the main actor).
    func install(
        onProgress: @escaping @Sendable (LibreOfficeInstallProgress) -> Void
    ) async throws {
        progressHandler = onProgress
        onProgress(.downloading(fraction: 0))

        let dmgURL = try await downloadDMG()
        defer { try? fileManager.removeItem(at: dmgURL) }

        try Task.checkCancellation()
        onProgress(.mounting)
        let mountPoint = try await mountDMG(at: dmgURL)
        defer { _ = try? detachDMG(at: mountPoint) }

        try Task.checkCancellation()
        guard let appURL = findLibreOfficeApp(in: mountPoint) else {
            throw LibreOfficeInstallError.appNotFoundInDiskImage
        }

        onProgress(.copying)
        let destination = applicationsDirectory.appendingPathComponent("LibreOffice.app", isDirectory: true)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        do {
            try fileManager.copyItem(at: appURL, to: destination)
        } catch {
            throw LibreOfficeInstallError.copyFailed(error.localizedDescription)
        }

        onProgress(.cleaningUp)
        guard Self.isLibreOfficeInstalled else {
            throw LibreOfficeInstallError.verificationFailed
        }

        onProgress(.finished)
    }

    /// Cancels an in-flight download, if any.
    func cancel() {
        downloadTask?.cancel()
        if let continuation {
            self.continuation = nil
            continuation.resume(throwing: LibreOfficeInstallError.cancelled)
        }
    }

    // MARK: - Download

    private func downloadDMG() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let config = URLSessionConfiguration.ephemeral
            let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
            self.session = session
            let task = session.downloadTask(with: downloadURL)
            self.downloadTask = task
            task.resume()
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = min(1, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
        progressHandler?(.downloading(fraction: fraction))
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            let destination = fileManager.temporaryDirectory
                .appendingPathComponent("Printly-LibreOffice-\(UUID().uuidString).dmg")
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: location, to: destination)
            progressHandler?(.downloading(fraction: 1))
            let cont = continuation
            continuation = nil
            cont?.resume(returning: destination)
        } catch {
            let cont = continuation
            continuation = nil
            cont?.resume(throwing: LibreOfficeInstallError.downloadFailed(error.localizedDescription))
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        let cont = continuation
        continuation = nil
        if (error as NSError).code == NSURLErrorCancelled {
            cont?.resume(throwing: LibreOfficeInstallError.cancelled)
        } else {
            cont?.resume(throwing: LibreOfficeInstallError.downloadFailed(error.localizedDescription))
        }
    }

    // MARK: - DMG helpers

    private func mountDMG(at dmgURL: URL) async throws -> URL {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = [
            "attach", dmgURL.path,
            "-nobrowse",
            "-readonly",
            "-plist",
        ]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw LibreOfficeInstallError.mountFailed
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]]
        else {
            throw LibreOfficeInstallError.mountFailed
        }

        for entity in entities {
            if let mountPoint = entity["mount-point"] as? String {
                return URL(fileURLWithPath: mountPoint, isDirectory: true)
            }
        }
        throw LibreOfficeInstallError.mountFailed
    }

    private func detachDMG(at mountPoint: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["detach", mountPoint.path, "-quiet"]
        try process.run()
        process.waitUntilExit()
    }

    private func findLibreOfficeApp(in mountPoint: URL) -> URL? {
        let candidate = mountPoint.appendingPathComponent("LibreOffice.app", isDirectory: true)
        if fileManager.fileExists(atPath: candidate.path) {
            return candidate
        }
        let contents = (try? fileManager.contentsOfDirectory(
            at: mountPoint,
            includingPropertiesForKeys: nil
        )) ?? []
        return contents.first { $0.pathExtension == "app" && $0.lastPathComponent.contains("LibreOffice") }
    }
}
