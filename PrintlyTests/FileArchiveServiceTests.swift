import Foundation
import Testing
@testable import Printly

struct FileArchiveServiceTests {
    @Test func archive_copiesIntoDatedSubfolder() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrintlyArchive-\(UUID().uuidString)", isDirectory: true)
        let source = root.appendingPathComponent("source", isDirectory: true)
        let dest = root.appendingPathComponent("dest", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let fileURL = source.appendingPathComponent("note.pdf")
        try Data("%PDF".utf8).write(to: fileURL)
        let file = PrintableFile(
            url: fileURL,
            kind: .pdf,
            displayName: "note.pdf",
            relativePath: "note.pdf"
        )

        try FileArchiveService().archive([file], to: dest)

        let children = try FileManager.default.contentsOfDirectory(at: dest, includingPropertiesForKeys: nil)
        #expect(children.count == 1)
        let archived = try FileManager.default.contentsOfDirectory(at: children[0], includingPropertiesForKeys: nil)
        #expect(archived.map(\.lastPathComponent) == ["note.pdf"])
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }
}
