import Foundation

/// Composition root that wires live dependencies for the app.
@MainActor
final class AppContainer {
    private let printService: any PrintServing
    private let converter: any FileConverting
    private let scanner: any FolderScanning

    /// Shared live container used by the app entry point.
    static let live = AppContainer()

    /// Creates an app dependency container.
    /// - Parameters:
    ///   - printService: Print backend.
    ///   - converter: PDF conversion pipeline.
    ///   - scanner: Folder scanner.
    init(
        printService: any PrintServing = NSPrintService(),
        converter: any FileConverting = PDFPipeline.makeDefault(),
        scanner: any FolderScanning = RecursiveFolderScanner()
    ) {
        self.printService = printService
        self.converter = converter
        self.scanner = scanner
    }

    /// Builds a fully wired batch print view model.
    func makeBatchPrintViewModel() -> BatchPrintViewModel {
        BatchPrintViewModel(
            scanFolder: ScanFolderUseCase(scanner: scanner),
            printBatch: PrintBatchUseCase(
                converter: converter,
                printService: printService
            ),
            printService: printService,
            libreOfficeInstaller: LibreOfficeInstaller(),
            settingsStore: JSONSettingsStore(),
            archiver: FileArchiveService(),
            folderWatcher: DirectoryWatcher()
        )
    }
}
