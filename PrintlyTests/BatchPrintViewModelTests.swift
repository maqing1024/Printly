import Foundation
import Testing
@testable import Printly

@MainActor
struct BatchPrintViewModelTests {
    @Test func scan_success_setsReadyAndFiles() async throws {
        let file = PrintableFile(
            url: URL(fileURLWithPath: "/tmp/a.pdf"),
            kind: .pdf,
            displayName: "a.pdf",
            relativePath: "a.pdf"
        )
        let scanner = StubScanner(result: .success([file]))
        let printService = StubPrintService(printer: PrinterInfo(name: "Test Printer"))
        let viewModel = makeViewModel(scanner: scanner, printService: printService)

        viewModel.handleFolderDrop(URL(fileURLWithPath: "/tmp/folder"))
        await waitUntil { viewModel.state.phase == .ready }

        #expect(viewModel.state.files.count == 1)
        #expect(viewModel.state.canStartPrint)
        #expect(viewModel.state.printerName == "Test Printer")
        #expect(viewModel.state.availablePrinters.map(\.name) == ["Test Printer"])
    }

    @Test func selectPrinter_updatesSelectionFromAvailableList() {
        let printService = StubPrintService(
            printer: PrinterInfo(name: "Office"),
            available: [
                PrinterInfo(name: "Office"),
                PrinterInfo(name: "Home"),
            ]
        )
        let viewModel = makeViewModel(
            scanner: StubScanner(result: .success([])),
            printService: printService
        )

        #expect(viewModel.state.printerName == "Office")
        viewModel.selectPrinter("Home")
        #expect(viewModel.state.printerName == "Home")
        viewModel.selectPrinter("Unknown")
        #expect(viewModel.state.printerName == "Home")
    }

    @Test func scan_emptyFolder_setsMessage() async throws {
        let scanner = StubScanner(result: .success([]))
        let viewModel = makeViewModel(scanner: scanner)

        viewModel.handleFolderDrop(URL(fileURLWithPath: "/tmp/empty"))
        await waitUntil { viewModel.state.phase == .ready }

        #expect(viewModel.state.files.isEmpty)
        #expect(viewModel.state.canStartPrint == false)
        #expect(viewModel.state.errorMessage != nil)
    }

    @Test func print_updatesProgressAndFinishes() async throws {
        let file = PrintableFile(
            url: URL(fileURLWithPath: "/tmp/a.pdf"),
            kind: .pdf,
            displayName: "a.pdf",
            relativePath: "a.pdf"
        )
        let scanner = StubScanner(result: .success([file]))
        let converter = StubConverter()
        let printService = StubPrintService(printer: PrinterInfo(name: "P1"))
        let viewModel = makeViewModel(
            scanner: scanner,
            converter: converter,
            printService: printService
        )

        viewModel.handleFolderDrop(URL(fileURLWithPath: "/tmp/folder"))
        await waitUntil { viewModel.state.phase == .ready }

        viewModel.startPrinting()
        await waitUntil { viewModel.state.phase == .finished }

        #expect(viewModel.state.lastResult?.succeeded.count == 1)
        #expect(viewModel.state.lastResult?.failed.isEmpty == true)
        #expect(printService.printCallCount == 1)
    }

    @Test func print_retriesOnceOnFailure() async throws {
        let file = PrintableFile(
            url: URL(fileURLWithPath: "/tmp/a.pdf"),
            kind: .pdf,
            displayName: "a.pdf",
            relativePath: "a.pdf"
        )
        let scanner = StubScanner(result: .success([file]))
        let converter = StubConverter()
        let printService = StubPrintService(
            printer: PrinterInfo(name: "P1"),
            failTimes: 1
        )
        let viewModel = makeViewModel(
            scanner: scanner,
            converter: converter,
            printService: printService
        )

        viewModel.handleFolderDrop(URL(fileURLWithPath: "/tmp/folder"))
        await waitUntil { viewModel.state.phase == .ready }

        viewModel.startPrinting()
        await waitUntil { viewModel.state.phase == .finished }

        #expect(printService.printCallCount == 2)
        #expect(viewModel.state.lastResult?.succeeded.count == 1)
    }

    @Test func print_recordsFailureAfterRetriesExhausted() async throws {
        let file = PrintableFile(
            url: URL(fileURLWithPath: "/tmp/a.pdf"),
            kind: .pdf,
            displayName: "a.pdf",
            relativePath: "a.pdf"
        )
        let scanner = StubScanner(result: .success([file]))
        let converter = StubConverter()
        let printService = StubPrintService(
            printer: PrinterInfo(name: "P1"),
            failTimes: 10
        )
        let viewModel = makeViewModel(
            scanner: scanner,
            converter: converter,
            printService: printService
        )

        viewModel.handleFolderDrop(URL(fileURLWithPath: "/tmp/folder"))
        await waitUntil { viewModel.state.phase == .ready }

        viewModel.startPrinting()
        await waitUntil { viewModel.state.phase == .finished }

        #expect(printService.printCallCount == 2)
        #expect(viewModel.state.lastResult?.failed.count == 1)
        #expect(viewModel.state.failedFiles.count == 1)
    }

    private func makeViewModel(
        scanner: StubScanner,
        converter: StubConverter = StubConverter(),
        printService: StubPrintService = StubPrintService(printer: PrinterInfo(name: "P"))
    ) -> BatchPrintViewModel {
        BatchPrintViewModel(
            scanFolder: ScanFolderUseCase(scanner: scanner),
            printBatch: PrintBatchUseCase(converter: converter, printService: printService),
            printService: printService
        )
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 2_000_000_000,
        condition: @MainActor () -> Bool
    ) async {
        let start = DispatchTime.now().uptimeNanoseconds
        while !condition() {
            if DispatchTime.now().uptimeNanoseconds - start > timeoutNanoseconds {
                Issue.record("Timed out waiting for condition")
                return
            }
            await Task.yield()
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

private struct StubScanner: FolderScanning {
    let result: Result<[PrintableFile], Error>

    func scan(rootURL: URL) async throws -> [PrintableFile] {
        try result.get()
    }
}

private struct StubConverter: FileConverting {
    var supportedKinds: Set<FileKind> { Set(FileKind.allCases) }

    func convertToPDF(_ file: PrintableFile) async throws -> URL {
        file.url
    }
}

/// Lock-based stub compatible with macOS 12.4 (no Synchronization.Mutex).
private final class StubPrintService: PrintServing, @unchecked Sendable {
    let printer: PrinterInfo?
    private let available: [PrinterInfo]
    private let lock = NSLock()
    private var remainingFailures: Int
    private var _printCallCount = 0

    init(printer: PrinterInfo?, failTimes: Int = 0, available: [PrinterInfo]? = nil) {
        self.printer = printer
        self.available = available ?? (printer.map { [$0] } ?? [])
        self.remainingFailures = failTimes
    }

    var printCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _printCallCount
    }

    func defaultPrinter() -> PrinterInfo? {
        printer
    }

    func availablePrinters() -> [PrinterInfo] {
        available
    }

    func printPDF(at pdfURL: URL, using printer: PrinterInfo) async throws {
        lock.lock()
        defer { lock.unlock() }
        _printCallCount += 1
        if remainingFailures > 0 {
            remainingFailures -= 1
            throw PrintBatchError.printFailed("simulated failure")
        }
    }
}
