import Foundation

/// Lifecycle status of a single print job.
nonisolated enum PrintJobStatus: Sendable, Equatable {
    case pending
    case converting
    case printing
    case succeeded
    case failed(String)
}

/// A queued unit of work that prints one `PrintableFile`.
nonisolated struct PrintJob: Identifiable, Sendable, Equatable {
    let id: UUID
    let file: PrintableFile
    var status: PrintJobStatus
    var attemptCount: Int

    /// Creates a print job for a discovered file.
    /// - Parameters:
    ///   - id: Stable identity for progress tracking.
    ///   - file: Source file to convert and print.
    ///   - status: Current job status.
    ///   - attemptCount: How many print attempts have been made.
    init(
        id: UUID = UUID(),
        file: PrintableFile,
        status: PrintJobStatus = .pending,
        attemptCount: Int = 0
    ) {
        self.id = id
        self.file = file
        self.status = status
        self.attemptCount = attemptCount
    }
}

/// Progress snapshot emitted while a batch is running.
nonisolated struct BatchPrintProgress: Sendable, Equatable {
    let currentIndex: Int
    let totalCount: Int
    let currentFileName: String
    let phase: PrintJobStatus
    let succeededCount: Int
    let failedCount: Int
}

/// Final summary after a batch finishes (or is cancelled mid-way).
nonisolated struct BatchPrintResult: Sendable, Equatable {
    let succeeded: [PrintableFile]
    let failed: [(file: PrintableFile, message: String)]

    static func == (lhs: BatchPrintResult, rhs: BatchPrintResult) -> Bool {
        lhs.succeeded == rhs.succeeded
            && lhs.failed.map(\.file) == rhs.failed.map(\.file)
            && lhs.failed.map(\.message) == rhs.failed.map(\.message)
    }
}
