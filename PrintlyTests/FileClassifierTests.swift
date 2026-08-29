import Foundation
import Testing
@testable import Printly

struct FileClassifierTests {
    private let classifier = FileClassifier()

    @Test(arguments: [
        ("report.pdf", FileKind.pdf),
        ("photo.JPG", FileKind.image),
        ("photo.jpeg", FileKind.image),
        ("shot.png", FileKind.image),
        ("scan.tif", FileKind.image),
        ("scan.TIFF", FileKind.image),
        ("raw.HEIC", FileKind.image),
        ("doc.docx", FileKind.word),
        ("sheet.xlsx", FileKind.excel),
        ("readme.md", FileKind.markdown),
        ("NOTES.markdown", FileKind.markdown),
    ])
    func classify_supportedExtensions(fileName: String, expected: FileKind) {
        let url = URL(fileURLWithPath: "/tmp/\(fileName)")
        #expect(classifier.classify(url) == expected)
    }

    @Test(arguments: ["notes.txt", "old.doc", "book.xls", "archive.zip", "readme"])
    func classify_unsupportedReturnsNil(fileName: String) {
        let url = URL(fileURLWithPath: "/tmp/\(fileName)")
        #expect(classifier.classify(url) == nil)
    }
}
