import Foundation

/// Errors raised by the batch print pipeline.
nonisolated enum PrintBatchError: Error, LocalizedError, Sendable, Equatable {
    case conversionFailed(String)
    case printFailed(String)
    case libreOfficeMissing

    var errorDescription: String? {
        switch self {
        case .conversionFailed(let message):
            message
        case .printFailed(let message):
            message
        case .libreOfficeMissing:
            String(localized: "error.libreOfficeMissing")
        }
    }
}

/// Converts files to PDF and prints them serially with one automatic retry.
nonisolated struct PrintBatchUseCase: Sendable {
    private let converter: any FileConverting
    private let printService: any PrintServing
    private let maxAttempts: Int

    /// Creates a batch print use case.
    /// - Parameters:
    ///   - converter: PDF conversion pipeline.
    ///   - printService: Silent print backend.
    ///   - maxAttempts: Attempts per file (default 2 = initial + 1 retry).
    init(
        converter: any FileConverting,
        printService: any PrintServing,
        maxAttempts: Int = 2
    ) {
        self.converter = converter
        self.printService = printService
        self.maxAttempts = maxAttempts
    }

    /// Prints `files` to `printer`, reporting progress after each phase change.
    /// - Parameters:
    ///   - files: Ordered files to print.
    ///   - printer: Target printer.
    ///   - settings: Batch-wide copies, duplex, color, and page range.
    ///   - onProgress: Progress callback (may be invoked off the main actor).
    /// - Returns: Success and failure lists.
    func execute(
        _ files: [PrintableFile],
        printer: PrinterInfo,
        settings: PrintSettings = .default,
        onProgress: @Sendable (BatchPrintProgress) -> Void
    ) async throws -> BatchPrintResult {
        var succeeded: [PrintableFile] = []
        var failed: [(file: PrintableFile, message: String)] = []
        let total = files.count

        for (index, file) in files.enumerated() {
            try Task.checkCancellation()

            let outcome = try await printFile(
                file,
                printer: printer,
                settings: settings,
                index: index,
                total: total,
                succeededCount: succeeded.count,
                failedCount: failed.count,
                onProgress: onProgress
            )

            switch outcome {
            case .success:
                succeeded.append(file)
            case .failure(let message):
                failed.append((file, message))
            }

            onProgress(
                BatchPrintProgress(
                    currentIndex: index + 1,
                    totalCount: total,
                    currentFileID: file.id,
                    currentFileName: file.displayName,
                    phase: outcome.isSuccess ? .succeeded : .failed(outcome.failureMessage ?? ""),
                    succeededCount: succeeded.count,
                    failedCount: failed.count
                )
            )
        }

        return BatchPrintResult(succeeded: succeeded, failed: failed)
    }

    private enum FileOutcome {
        case success
        case failure(String)

        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }

        var failureMessage: String? {
            if case .failure(let message) = self { return message }
            return nil
        }
    }

    private func printFile(
        _ file: PrintableFile,
        printer: PrinterInfo,
        settings: PrintSettings,
        index: Int,
        total: Int,
        succeededCount: Int,
        failedCount: Int,
        onProgress: @Sendable (BatchPrintProgress) -> Void
    ) async throws -> FileOutcome {
        var lastError = String(localized: "error.unknown")

        for attempt in 1...maxAttempts {
            do {
                try Task.checkCancellation()

                onProgress(
                    BatchPrintProgress(
                        currentIndex: index + 1,
                        totalCount: total,
                        currentFileID: file.id,
                        currentFileName: file.displayName,
                        phase: .converting,
                        succeededCount: succeededCount,
                        failedCount: failedCount
                    )
                )

                let pdfURL = try await converter.convertToPDF(file)
                defer {
                    // Only delete temporary copies; never delete the user's original PDF.
                    if pdfURL != file.url {
                        try? FileManager.default.removeItem(at: pdfURL)
                    }
                }

                try Task.checkCancellation()

                onProgress(
                    BatchPrintProgress(
                        currentIndex: index + 1,
                        totalCount: total,
                        currentFileID: file.id,
                        currentFileName: file.displayName,
                        phase: .printing,
                        succeededCount: succeededCount,
                        failedCount: failedCount
                    )
                )

                try await printService.printPDF(at: pdfURL, using: printer, settings: settings)
                return .success
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error.localizedDescription
                if attempt < maxAttempts {
                    continue
                }
            }
        }

        return .failure(lastError)
    }
}
