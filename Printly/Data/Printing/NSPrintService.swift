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

    func printPDF(at pdfURL: URL, using printer: PrinterInfo) async throws {
        try await MainActor.run {
            guard let document = PDFDocument(url: pdfURL) else {
                throw PrintBatchError.printFailed(String(localized: "error.pdfLoadFailed"))
            }

            guard document.pageCount > 0 else {
                throw PrintBatchError.printFailed(String(localized: "error.pdfEmpty"))
            }

            let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
            if let nsPrinter = NSPrinter(name: printer.name) {
                printInfo.printer = nsPrinter
            }

            printInfo.jobDisposition = .spool

            guard let printOperation = document.printOperation(
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
}
