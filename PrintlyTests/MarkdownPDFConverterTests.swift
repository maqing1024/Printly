import Foundation
import PDFKit
import Testing
@testable import Printly

struct MarkdownPDFConverterTests {
    @Test func convert_producesPDFWithVisibleText() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrintlyMD-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let mdURL = root.appendingPathComponent("sample.md")
        let markdown = """
        # Title

        Hello **Printly**.

        - one
        - two
        """
        try markdown.data(using: .utf8)!.write(to: mdURL)

        let file = PrintableFile(
            url: mdURL,
            kind: .markdown,
            displayName: "sample.md",
            relativePath: "sample.md"
        )

        let pdfURL = try await MarkdownPDFConverter().convertToPDF(file)
        defer { try? FileManager.default.removeItem(at: pdfURL) }

        let document = try #require(PDFDocument(url: pdfURL))
        #expect(document.pageCount >= 1)

        let pageText = (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(pageText.contains("Title") || pageText.contains("Printly"))
    }
}
