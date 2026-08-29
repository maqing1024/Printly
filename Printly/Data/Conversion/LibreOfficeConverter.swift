import Foundation

/// Converts DOCX/XLSX to PDF via a local LibreOffice (`soffice`) install.
nonisolated struct LibreOfficeConverter: FileConverting {
    var supportedKinds: Set<FileKind> { [.word, .excel] }

    private let sofficeCandidates: [URL]

    /// Creates a LibreOffice-backed converter.
    /// - Parameter sofficeCandidates: Candidate paths for the `soffice` binary.
    init(sofficeCandidates: [URL] = LibreOfficeConverter.defaultCandidates) {
        self.sofficeCandidates = sofficeCandidates
    }

    static let defaultCandidates: [URL] = [
        URL(fileURLWithPath: "/Applications/LibreOffice.app/Contents/MacOS/soffice"),
        URL(fileURLWithPath: "/opt/homebrew/bin/soffice"),
        URL(fileURLWithPath: "/usr/local/bin/soffice"),
    ]

    /// Returns whether a usable LibreOffice `soffice` binary is present.
    static var isInstalled: Bool {
        defaultCandidates.contains {
            FileManager.default.isExecutableFile(atPath: $0.path)
        }
    }

    func convertToPDF(_ file: PrintableFile) async throws -> URL {
        guard let soffice = resolveSoffice() else {
            throw PrintBatchError.libreOfficeMissing
        }

        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Printly-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = soffice
        process.arguments = [
            "--headless",
            "--nologo",
            "--nofirststartwizard",
            "--convert-to", "pdf",
            "--outdir", outputDirectory.path,
            file.url.path,
        ]

        let stderr = Pipe()
        process.standardError = stderr
        process.standardOutput = Pipe()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
                return
            }

            process.terminationHandler = { finished in
                if finished.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let data = stderr.fileHandleForReading.readDataToEndOfFile()
                    let message = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(
                        throwing: PrintBatchError.conversionFailed(
                            message?.isEmpty == false
                                ? message!
                                : String(localized: "error.officeConversionFailed")
                        )
                    )
                }
            }
        }

        let expectedName = file.url.deletingPathExtension().lastPathComponent + ".pdf"
        let pdfURL = outputDirectory.appendingPathComponent(expectedName)

        guard FileManager.default.fileExists(atPath: pdfURL.path) else {
            throw PrintBatchError.conversionFailed(
                String(localized: "error.officeConversionFailed")
            )
        }

        return pdfURL
    }

    private func resolveSoffice() -> URL? {
        sofficeCandidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}
