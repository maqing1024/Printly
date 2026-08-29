import Foundation
import Testing
@testable import Printly

struct FileSorterTests {
    @Test func sorted_usesNaturalCaseInsensitiveNameOrder() {
        let files = [
            makeFile(name: "file10.pdf"),
            makeFile(name: "File2.pdf"),
            makeFile(name: "file1.pdf"),
            makeFile(name: "b.png"),
            makeFile(name: "A.docx"),
        ]

        let sorted = FileSorter().sorted(files).map(\.displayName)
        #expect(sorted == ["A.docx", "b.png", "file1.pdf", "File2.pdf", "file10.pdf"])
    }

    @Test func sorted_breaksTiesWithRelativePath() {
        let files = [
            makeFile(name: "dup.pdf", relativePath: "z/dup.pdf"),
            makeFile(name: "dup.pdf", relativePath: "a/dup.pdf"),
        ]

        let sorted = FileSorter().sorted(files).map(\.relativePath)
        #expect(sorted == ["a/dup.pdf", "z/dup.pdf"])
    }

    private func makeFile(name: String, relativePath: String? = nil) -> PrintableFile {
        PrintableFile(
            url: URL(fileURLWithPath: "/tmp/\(relativePath ?? name)"),
            kind: .pdf,
            displayName: name,
            relativePath: relativePath ?? name
        )
    }
}
