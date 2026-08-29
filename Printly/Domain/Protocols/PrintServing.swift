import Foundation

/// Describes the system printer used for silent printing.
nonisolated struct PrinterInfo: Sendable, Equatable, Identifiable, Hashable {
    var id: String { name }
    let name: String
}

/// Sends PDF documents to the system print subsystem (CUPS).
nonisolated protocol PrintServing: Sendable {
    /// Returns the current default printer, if any.
    func defaultPrinter() -> PrinterInfo?

    /// Returns printers the system can currently send jobs to (USB and nearby/network queues).
    func availablePrinters() -> [PrinterInfo]

    /// Silently prints the PDF at `pdfURL`.
    /// - Parameters:
    ///   - pdfURL: Local PDF file URL.
    ///   - printer: Target printer.
    ///   - settings: Copies, duplex, color, and page range.
    func printPDF(at pdfURL: URL, using printer: PrinterInfo, settings: PrintSettings) async throws
}
