import AppKit
import Foundation
import PDFKit

/// Silent PDF printing via AppKit / PDFKit (CUPS under the hood).
nonisolated struct NSPrintService: PrintServing {
    func defaultPrinter() -> PrinterInfo? {
        let sharedPrinter = NSPrintInfo.shared.printer
        if !sharedPrinter.name.isEmpty {
            return PrinterInfo(name: sharedPrinter.name)
        }
        // Fall back to the first installed printer when no default is set.
        if let name = NSPrinter.printerNames.first {
            return PrinterInfo(name: name)
        }
        return nil
    }

    func availablePrinters() -> [PrinterInfo] {
        NSPrinter.printerNames.map { PrinterInfo(name: $0) }
    }

    func printPDF(at pdfURL: URL, using printer: PrinterInfo, settings: PrintSettings) async throws {
        try await MainActor.run {
            guard let document = PDFDocument(url: pdfURL) else {
                throw PrintBatchError.printFailed(String(localized: "error.pdfLoadFailed"))
            }

            guard document.pageCount > 0 else {
                throw PrintBatchError.printFailed(String(localized: "error.pdfEmpty"))
            }

            let pageRange: PageRange
            switch settings.resolvedPageRange {
            case .success(let range):
                pageRange = range
            case .failure:
                throw PrintBatchError.printFailed(String(localized: "error.invalidPageRange"))
            }
            let documentToPrint = try Self.applying(pageRange, to: document)

            let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
            if let nsPrinter = NSPrinter(name: printer.name) {
                printInfo.printer = nsPrinter
            }

            printInfo.jobDisposition = .spool
            Self.apply(settings, to: printInfo)

            guard let printOperation = documentToPrint.printOperation(
                for: printInfo,
                scalingMode: .pageScaleToFit,
                autoRotate: true
            ) else {
                throw PrintBatchError.printFailed(String(localized: "error.printOperationFailed"))
            }

            printOperation.showsPrintPanel = false
            printOperation.showsProgressPanel = false

            let success = printOperation.run()
            if !success {
                throw PrintBatchError.printFailed(String(localized: "error.printSpoolFailed"))
            }
        }
    }

    /// Builds a subset PDF when the user asked for specific pages.
    static func applying(_ pageRange: PageRange, to document: PDFDocument) throws -> PDFDocument {
        if pageRange.isAllPages {
            return document
        }

        let subset = PDFDocument()
        for index in 0..<document.pageCount {
            let pageNumber = index + 1
            guard pageRange.contains(pageNumber), let page = document.page(at: index) else {
                continue
            }
            subset.insert(page, at: subset.pageCount)
        }

        guard subset.pageCount > 0 else {
            throw PrintBatchError.printFailed(String(localized: "error.pageRangeEmpty"))
        }
        return subset
    }

    /// Writes copies, duplex, and color onto `printInfo` for macOS 12.4+.
    static func apply(_ settings: PrintSettings, to printInfo: NSPrintInfo) {
        var copies = settings.copies
        copies = min(99, max(1, copies))
        printInfo.dictionary()[NSPrintInfo.AttributeKey.copies] = copies

        // CUPS / Print Core keys — NSPrintInfo.duplex is not available on macOS 12.4.
        switch settings.duplex {
        case .simplex:
            printInfo.printSettings["com.apple.print.PrintSettings.PMDuplexing"] = 1
            printInfo.printSettings["sides"] = "one-sided"
        case .longEdge:
            printInfo.printSettings["com.apple.print.PrintSettings.PMDuplexing"] = 2
            printInfo.printSettings["sides"] = "two-sided-long-edge"
        case .shortEdge:
            printInfo.printSettings["com.apple.print.PrintSettings.PMDuplexing"] = 3
            printInfo.printSettings["sides"] = "two-sided-short-edge"
        }

        switch settings.colorMode {
        case .color:
            printInfo.printSettings["com.apple.print.PrintSettings.PMColorMode"] = 1
            printInfo.printSettings["print-color-mode"] = "color"
        case .blackAndWhite:
            printInfo.printSettings["com.apple.print.PrintSettings.PMColorMode"] = 2
            printInfo.printSettings["print-color-mode"] = "monochrome"
        }
    }
}
