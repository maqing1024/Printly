import Foundation

/// Tries Microsoft Office first, then LibreOffice, for Word/Excel conversion.
nonisolated struct CascadingOfficeConverter: FileConverting {
    var supportedKinds: Set<FileKind> { [.word, .excel] }

    private let primary: any FileConverting
    private let fallback: any FileConverting

    /// Creates a cascading Office converter.
    /// - Parameters:
    ///   - primary: Preferred converter (typically Microsoft Office).
    ///   - fallback: Fallback converter (typically LibreOffice).
    init(
        primary: any FileConverting = MicrosoftOfficeConverter(),
        fallback: any FileConverting = LibreOfficeConverter()
    ) {
        self.primary = primary
        self.fallback = fallback
    }

    func convertToPDF(_ file: PrintableFile) async throws -> URL {
        do {
            return try await primary.convertToPDF(file)
        } catch {
            // Prefer LibreOffice when Word/Excel is missing or automation fails.
        }

        do {
            return try await fallback.convertToPDF(file)
        } catch PrintBatchError.libreOfficeMissing {
            throw PrintBatchError.libreOfficeMissing
        }
    }
}
