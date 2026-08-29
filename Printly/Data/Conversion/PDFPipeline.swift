import Foundation

/// Passes PDF files through unchanged for the print stage.
nonisolated struct PassthroughPDFConverter: FileConverting {
    var supportedKinds: Set<FileKind> { [.pdf] }

    func convertToPDF(_ file: PrintableFile) async throws -> URL {
        file.url
    }
}

/// Routes each file to the appropriate converter by `FileKind`.
nonisolated struct PDFPipeline: FileConverting {
    private let converters: [any FileConverting]

    var supportedKinds: Set<FileKind> {
        Set(converters.flatMap(\.supportedKinds))
    }

    /// Creates a composite PDF conversion pipeline.
    /// - Parameter converters: Ordered converter adapters.
    init(converters: [any FileConverting]) {
        self.converters = converters
    }

    /// Builds the default MVP pipeline (PDF / image / Markdown / Office cascade).
    static func makeDefault() -> PDFPipeline {
        PDFPipeline(
            converters: [
                PassthroughPDFConverter(),
                ImagePDFConverter(),
                MarkdownPDFConverter(),
                CascadingOfficeConverter(),
            ]
        )
    }

    func convertToPDF(_ file: PrintableFile) async throws -> URL {
        guard let converter = converters.first(where: { $0.supportedKinds.contains(file.kind) }) else {
            throw PrintBatchError.conversionFailed(
                String(localized: "error.unsupportedKind")
            )
        }
        return try await converter.convertToPDF(file)
    }
}
