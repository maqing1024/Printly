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
        #expect(viewModel.state.jobs.count == 1)
        #expect(viewModel.state.printerName == "Test Printer")
        #expect(viewModel.state.availablePrinters.map(\.name) == ["Test Printer"])
    }

    @Test func printSettings_updateCopiesDuplexColorAndPageRange() async throws {
        let file = PrintableFile(
            url: URL(fileURLWithPath: "/tmp/a.pdf"),
            kind: .pdf,
            displayName: "a.pdf",
            relativePath: "a.pdf"
        )
        let viewModel = makeViewModel(scanner: StubScanner(result: .success([file])))
        viewModel.handleFolderDrop(URL(fileURLWithPath: "/tmp/folder"))
        await waitUntil { viewModel.state.phase == .ready }

        viewModel.setCopies(3)
        viewModel.setDuplex(.longEdge)
        viewModel.setColorMode(.blackAndWhite)
        viewModel.setPageRangeText("1-3,5")

        #expect(viewModel.state.printSettings.copies == 3)
        #expect(viewModel.state.printSettings.duplex == .longEdge)
        #expect(viewModel.state.printSettings.colorMode == .blackAndWhite)
        #expect(viewModel.state.isPageRangeValid)
        #expect(viewModel.state.canStartPrint)

        viewModel.setCopies(0)
        #expect(viewModel.state.printSettings.copies == 1)

        viewModel.setPageRangeText("3-1")
        #expect(viewModel.state.isPageRangeValid == false)
        #expect(viewModel.state.canStartPrint == false)
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
        #expect(printService.lastSettings?.copies == 1)
    }

    @Test func print_forwardsCustomSettings() async throws {
        let file = PrintableFile(
            url: URL(fileURLWithPath: "/tmp/a.pdf"),
            kind: .pdf,
            displayName: "a.pdf",
            relativePath: "a.pdf"
        )
        let scanner = StubScanner(result: .success([file]))
        let printService = StubPrintService(printer: PrinterInfo(name: "P1"))
        let viewModel = makeViewModel(
            scanner: scanner,
            printService: printService
        )

        viewModel.handleFolderDrop(URL(fileURLWithPath: "/tmp/folder"))
        await waitUntil { viewModel.state.phase == .ready }

        viewModel.setCopies(4)
        viewModel.setDuplex(.shortEdge)
        viewModel.setColorMode(.blackAndWhite)
        viewModel.setPageRangeText("2-4")
        viewModel.startPrinting()
        await waitUntil { viewModel.state.phase == .finished }

        let settings = try #require(printService.lastSettings)
        #expect(settings.copies == 4)
        #expect(settings.duplex == .shortEdge)
        #expect(settings.colorMode == .blackAndWhite)
        #expect(settings.pageRangeText == "2-4")
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

    @Test func filter_hidesDisabledKindsFromQueue() async throws {
        let pdf = PrintableFile(
            url: URL(fileURLWithPath: "/tmp/a.pdf"),
            kind: .pdf,
            displayName: "a.pdf",
            relativePath: "a.pdf"
        )
        let image = PrintableFile(
            url: URL(fileURLWithPath: "/tmp/b.png"),
            kind: .image,
            displayName: "b.png",
            relativePath: "b.png"
        )
        let viewModel = makeViewModel(
            scanner: StubScanner(result: .success([pdf, image]))
        )
        viewModel.handleFolderDrop(URL(fileURLWithPath: "/tmp/folder"))
        await waitUntil { viewModel.state.phase == .ready }

        #expect(viewModel.state.jobs.count == 2)
        viewModel.setKind(.image, enabled: false)
        #expect(viewModel.state.jobs.map(\.file.kind) == [.pdf])
        #expect(viewModel.state.canStartPrint)
    }

    @Test func sort_reordersQueueByKind() async throws {
        let pdf = PrintableFile(
            url: URL(fileURLWithPath: "/tmp/z.pdf"),
            kind: .pdf,
            displayName: "z.pdf",
            relativePath: "z.pdf"
        )
        let word = PrintableFile(
            url: URL(fileURLWithPath: "/tmp/a.docx"),
            kind: .word,
            displayName: "a.docx",
            relativePath: "a.docx"
        )
        let viewModel = makeViewModel(
            scanner: StubScanner(result: .success([pdf, word]))
        )
        viewModel.handleFolderDrop(URL(fileURLWithPath: "/tmp/folder"))
        await waitUntil { viewModel.state.phase == .ready }

        viewModel.setSortOrder(.kind)
        #expect(viewModel.state.jobs.map(\.file.displayName) == ["z.pdf", "a.docx"])
    }

    @Test func preset_savesAndAppliesSettings() {
        let viewModel = makeViewModel(scanner: StubScanner(result: .success([])))
        viewModel.setCopies(5)
        viewModel.setDuplex(.longEdge)
        viewModel.savePreset(named: "Office")

        #expect(viewModel.state.presets.count == 1)
        viewModel.setCopies(1)
        viewModel.setDuplex(.simplex)
        viewModel.applyPreset(id: viewModel.state.presets[0].id)

        #expect(viewModel.state.printSettings.copies == 5)
        #expect(viewModel.state.printSettings.duplex == .longEdge)
    }

    @Test func print_writesHistoryAndArchivesSuccesses() async throws {
        let file = PrintableFile(
            url: URL(fileURLWithPath: "/tmp/a.pdf"),
            kind: .pdf,
            displayName: "a.pdf",
            relativePath: "a.pdf"
        )
        let archiver = RecordingArchiver()
        let viewModel = makeViewModel(
            scanner: StubScanner(result: .success([file])),
            archiver: archiver
        )
        viewModel.setArchiveEnabled(true)
        viewModel.setArchiveFolderPath("/tmp/archive")
        viewModel.handleFolderDrop(URL(fileURLWithPath: "/tmp/folder"))
        await waitUntil { viewModel.state.phase == .ready }

        viewModel.startPrinting()
        await waitUntil { viewModel.state.phase == .finished }

        #expect(viewModel.state.history.count == 1)
        #expect(viewModel.state.history[0].succeeded)
        #expect(archiver.archivedNames == ["a.pdf"])
    }

    private func makeViewModel(
        scanner: StubScanner,
        converter: StubConverter = StubConverter(),
        printService: StubPrintService = StubPrintService(printer: PrinterInfo(name: "P")),
        settingsStore: any SettingsStoring = InMemorySettingsStore(),
        archiver: any FileArchiving = FileArchiveService(),
        folderWatcher: (any FolderWatching)? = nil
    ) -> BatchPrintViewModel {
        BatchPrintViewModel(
            scanFolder: ScanFolderUseCase(scanner: scanner),
            printBatch: PrintBatchUseCase(converter: converter, printService: printService),
            printService: printService,
            settingsStore: settingsStore,
            archiver: archiver,
            folderWatcher: folderWatcher ?? NoopFolderWatcher()
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

    private var _lastSettings: PrintSettings?

    var lastSettings: PrintSettings? {
        lock.lock()
        defer { lock.unlock() }
        return _lastSettings
    }

    func printPDF(at pdfURL: URL, using printer: PrinterInfo, settings: PrintSettings) async throws {
        lock.lock()
        defer { lock.unlock() }
        _printCallCount += 1
        _lastSettings = settings
        if remainingFailures > 0 {
            remainingFailures -= 1
            throw PrintBatchError.printFailed("simulated failure")
        }
    }
}

private final class InMemorySettingsStore: SettingsStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var settings = AppSettings.default

    func load() -> AppSettings {
        lock.lock()
        defer { lock.unlock() }
        return settings
    }

    func save(_ settings: AppSettings) {
        lock.lock()
        defer { lock.unlock() }
        self.settings = settings
    }
}

@MainActor
private final class NoopFolderWatcher: FolderWatching {
    func start(url: URL, onChange: @escaping () -> Void) {}
    func stop() {}
}

private final class RecordingArchiver: FileArchiving, @unchecked Sendable {
    private let lock = NSLock()
    private var _archivedNames: [String] = []

    var archivedNames: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _archivedNames
    }

    func archive(_ files: [PrintableFile], to folder: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        _archivedNames.append(contentsOf: files.map(\.displayName))
    }
}
