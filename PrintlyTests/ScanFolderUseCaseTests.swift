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
        try write(nested.appendingPathComponent("scan.tiff"), contents: "tiff")

        let macosx = root.appendingPathComponent("__MACOSX", isDirectory: true)
        try FileManager.default.createDirectory(at: macosx, withIntermediateDirectories: true)
        try write(macosx.appendingPathComponent("junk.pdf"), contents: "%PDF")

        let useCase = ScanFolderUseCase(scanner: RecursiveFolderScanner())
        let files = try await useCase.execute(root)

        #expect(files.count == 5)
        #expect(files.map(\.displayName) == ["a.pdf", "letter.docx", "photo.png", "scan.tiff", "sheet.xlsx"])
        #expect(Set(files.map(\.kind)) == [.pdf, .word, .image, .excel])
    }

    @Test func scan_singleFileReturnsThatFile() async throws {
        let root = try makeTempFolder()
        defer { try? FileManager.default.removeItem(at: root) }

        let fileURL = root.appendingPathComponent("solo.pdf")
        try write(fileURL, contents: "%PDF")

        let useCase = ScanFolderUseCase(scanner: RecursiveFolderScanner())
        let files = try await useCase.execute(fileURL)

        #expect(files.count == 1)
        #expect(files[0].displayName == "solo.pdf")
        #expect(files[0].kind == .pdf)
    }

    @Test func scan_multipleRootsMergesAndDeduplicates() async throws {
        let root = try makeTempFolder()
        defer { try? FileManager.default.removeItem(at: root) }

        let first = root.appendingPathComponent("a.pdf")
        let second = root.appendingPathComponent("b.png")
        try write(first, contents: "%PDF")
        try write(second, contents: "png")

        let useCase = ScanFolderUseCase(scanner: RecursiveFolderScanner())
        let files = try await useCase.execute([first, second, first])

        #expect(files.map(\.displayName) == ["a.pdf", "b.png"])
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
