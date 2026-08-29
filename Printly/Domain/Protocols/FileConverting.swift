import Foundation

/// Converts a source file into a PDF suitable for printing.
nonisolated protocol FileConverting: Sendable {
    /// File kinds this converter can handle.
    var supportedKinds: Set<FileKind> { get }

    /// Converts `file` to a PDF on disk.
    /// - Parameter file: Source printable file.
    /// - Returns: URL of a PDF (temporary or original for native PDFs).
    func convertToPDF(_ file: PrintableFile) async throws -> URL
}
