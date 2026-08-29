import AppKit
import Foundation
import PDFKit
import Testing
@testable import Printly

struct NSPrintServiceTests {
    @Test func applying_allPagesReturnsOriginalDocument() throws {
        let document = try makePDF(pageCount: 3)
        let result = try NSPrintService.applying(.all, to: document)
        #expect(result.pageCount == 3)
        #expect(result === document)
    }

    @Test func applying_contiguousRangeKeepsThosePages() throws {
        let document = try makePDF(pageCount: 4)
        guard case .success(let range) = PageRange.parse("2-3") else {
            Issue.record("Failed to parse range")
            return
        }

        let result = try NSPrintService.applying(range, to: document)
        #expect(result.pageCount == 2)
    }

    @Test func applying_outOfRangeThrows() throws {
        let document = try makePDF(pageCount: 2)
        guard case .success(let range) = PageRange.parse("8-10") else {
            Issue.record("Failed to parse range")
            return
        }

        #expect(throws: PrintBatchError.printFailed(String(localized: "error.pageRangeEmpty"))) {
            _ = try NSPrintService.applying(range, to: document)
        }
    }

    @Test func apply_clampsCopiesAndSetsPrintInfo() {
        let printInfo = NSPrintInfo()
        var settings = PrintSettings.default
        settings.copies = 4
        settings.duplex = .longEdge
        settings.colorMode = .blackAndWhite

        NSPrintService.apply(settings, to: printInfo)

        #expect(printInfo.dictionary()[NSPrintInfo.AttributeKey.copies] as? Int == 4)
        #expect(printInfo.printSettings["sides"] as? String == "two-sided-long-edge")
        #expect(printInfo.printSettings["print-color-mode"] as? String == "monochrome")
    }

    private func makePDF(pageCount: Int) throws -> PDFDocument {
        let document = PDFDocument()
        for _ in 0..<pageCount {
            let page = PDFPage()
            document.insert(page, at: document.pageCount)
        }
        #expect(document.pageCount == pageCount)
        return document
    }
}
