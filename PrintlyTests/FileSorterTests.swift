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

    @Test func sorted_byKindThenName() {
        let files = [
            makeFile(name: "z.pdf", kind: .pdf),
            makeFile(name: "a.docx", kind: .word),
            makeFile(name: "b.png", kind: .image),
        ]

        let sorted = FileSorter().sorted(files, order: .kind).map(\.displayName)
        #expect(sorted == ["b.png", "z.pdf", "a.docx"])
    }

    @Test func sorted_byPath() {
        let files = [
            makeFile(name: "b.pdf", relativePath: "z/b.pdf"),
            makeFile(name: "a.pdf", relativePath: "a/a.pdf"),
        ]

        let sorted = FileSorter().sorted(files, order: .path).map(\.relativePath)
        #expect(sorted == ["a/a.pdf", "z/b.pdf"])
    }

    private func makeFile(
        name: String,
        kind: FileKind = .pdf,
        relativePath: String? = nil
    ) -> PrintableFile {
        PrintableFile(
            url: URL(fileURLWithPath: "/tmp/\(relativePath ?? name)"),
            kind: kind,
            displayName: name,
            relativePath: relativePath ?? name
        )
    }
}
