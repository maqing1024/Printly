import Foundation
import Testing
@testable import Printly

struct CascadingOfficeConverterTests {
    @Test func convert_usesPrimaryWhenItSucceeds() async throws {
        let primary = RecordingConverter(shouldSucceed: true)
        let fallback = RecordingConverter(shouldSucceed: true)
        let sut = CascadingOfficeConverter(primary: primary, fallback: fallback)
        let file = makeWordFile()

        let url = try await sut.convertToPDF(file)
        #expect(url.pathExtension == "pdf")
        #expect(primary.callCount == 1)
        #expect(fallback.callCount == 0)
    }

    @Test func convert_fallsBackWhenPrimaryFails() async throws {
        let primary = RecordingConverter(shouldSucceed: false)
        let fallback = RecordingConverter(shouldSucceed: true)
        let sut = CascadingOfficeConverter(primary: primary, fallback: fallback)
        let file = makeWordFile()

        let url = try await sut.convertToPDF(file)
        #expect(url.pathExtension == "pdf")
        #expect(primary.callCount == 1)
        #expect(fallback.callCount == 1)
    }

    @Test func convert_surfacesLibreOfficeMissingFromFallback() async throws {
        let primary = RecordingConverter(shouldSucceed: false)
        let fallback = MissingLibreOfficeConverter()
        let sut = CascadingOfficeConverter(primary: primary, fallback: fallback)
        let file = makeWordFile()

        await #expect(throws: PrintBatchError.libreOfficeMissing) {
            _ = try await sut.convertToPDF(file)
        }
    }

    private func makeWordFile() -> PrintableFile {
        PrintableFile(
            url: URL(fileURLWithPath: "/tmp/a.docx"),
            kind: .word,
            displayName: "a.docx",
            relativePath: "a.docx"
        )
    }
}

private final class RecordingConverter: FileConverting, @unchecked Sendable {
    let shouldSucceed: Bool
    private(set) var callCount = 0

    init(shouldSucceed: Bool) {
        self.shouldSucceed = shouldSucceed
    }

    var supportedKinds: Set<FileKind> { [.word, .excel] }

    func convertToPDF(_ file: PrintableFile) async throws -> URL {
        callCount += 1
        if shouldSucceed {
            return URL(fileURLWithPath: "/tmp/\(UUID().uuidString).pdf")
        }
        throw PrintBatchError.conversionFailed("primary failed")
    }
}

private struct MissingLibreOfficeConverter: FileConverting {
    var supportedKinds: Set<FileKind> { [.word, .excel] }

    func convertToPDF(_ file: PrintableFile) async throws -> URL {
        throw PrintBatchError.libreOfficeMissing
    }
}
