import Foundation
import Testing
@testable import Printly

struct ScanFolderUseCaseTests {
    @Test func scan_discoversNestedSupportedFilesAndIgnoresOthers() async throws {
        let root = try makeTempFolder()
        defer { try? FileManager.default.removeItem(at: root) }

        try write(root.appendingPathComponent("a.pdf"), contents: "%PDF")
        try write(root.appendingPathComponent("notes.txt"), contents: "x")
        try write(root.appendingPathComponent(".hidden.pdf"), contents: "%PDF")

        let nested = root.appendingPathComponent("sub", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try write(nested.appendingPathComponent("photo.png"), contents: "png")
        try write(nested.appendingPathComponent("sheet.xlsx"), contents: "xlsx")
        try write(nested.appendingPathComponent("letter.docx"), contents: "docx")

        let macosx = root.appendingPathComponent("__MACOSX", isDirectory: true)
        try FileManager.default.createDirectory(at: macosx, withIntermediateDirectories: true)
        try write(macosx.appendingPathComponent("junk.pdf"), contents: "%PDF")

        let useCase = ScanFolderUseCase(scanner: RecursiveFolderScanner())
        let files = try await useCase.execute(root)

        #expect(files.count == 4)
        #expect(files.map(\.displayName) == ["a.pdf", "letter.docx", "photo.png", "sheet.xlsx"])
        #expect(Set(files.map(\.kind)) == [.pdf, .word, .image, .excel])
    }

    @Test func scan_emptyFolderReturnsEmpty() async throws {
        let root = try makeTempFolder()
        defer { try? FileManager.default.removeItem(at: root) }

        let useCase = ScanFolderUseCase(scanner: RecursiveFolderScanner())
        let files = try await useCase.execute(root)
        #expect(files.isEmpty)
    }

    private func makeTempFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrintlyScan-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func write(_ url: URL, contents: String) throws {
        try contents.data(using: .utf8)!.write(to: url)
    }
}
