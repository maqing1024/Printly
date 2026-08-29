import AppKit
import Combine
import Foundation

/// Owns batch-print screen state and coordinates scan / print use cases.
@MainActor
final class BatchPrintViewModel: ObservableObject {
    @Published private(set) var state = BatchPrintState()

    private let scanFolder: ScanFolderUseCase
    private let printBatch: PrintBatchUseCase
    private let printService: any PrintServing
    private let libreOfficeInstaller: LibreOfficeInstaller

    private var scanTask: Task<Void, Never>?
    private var printTask: Task<Void, Never>?
    private var installTask: Task<Void, Never>?

    /// Creates the batch print view model.
    /// - Parameters:
    ///   - scanFolder: Folder scan use case.
    ///   - printBatch: Batch print use case.
    ///   - printService: Printer discovery / printing backend.
    ///   - libreOfficeInstaller: One-click LibreOffice installer.
    init(
        scanFolder: ScanFolderUseCase,
        printBatch: PrintBatchUseCase,
        printService: any PrintServing,
        libreOfficeInstaller: LibreOfficeInstaller = LibreOfficeInstaller()
    ) {
        self.scanFolder = scanFolder
        self.printBatch = printBatch
        self.printService = printService
        self.libreOfficeInstaller = libreOfficeInstaller
        refreshPrinter()
        refreshOfficeAvailability()
    }

    /// Reloads available printers and keeps a valid selection.
    func refreshPrinter() {
        let printers = printService.availablePrinters()
        state.availablePrinters = printers
        if let selected = state.printerName, printers.contains(where: { $0.name == selected }) {
            return
        }
        state.printerName = printService.defaultPrinter()?.name
            ?? printers.first?.name
    }

    /// Selects the printer used for the next batch.
    /// - Parameter name: Printer name from the available list.
    func selectPrinter(_ name: String) {
        guard state.availablePrinters.contains(where: { $0.name == name }) else { return }
        state.printerName = name
    }

    /// Opens System Settings / Preferences so the user can add a nearby printer.
    func openPrinterSettings() {
        let prefPane = URL(fileURLWithPath: "/System/Library/PreferencePanes/PrintAndScan.prefPane")
        if FileManager.default.fileExists(atPath: prefPane.path) {
            NSWorkspace.shared.open(prefPane)
            return
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.Print-Scan-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Reloads Microsoft Office / LibreOffice availability.
    func refreshOfficeAvailability() {
        state.isLibreOfficeInstalled = LibreOfficeConverter.isInstalled
        state.isMicrosoftOfficeInstalled = MicrosoftOfficeConverter.isInstalled
    }

    /// Handles a dropped or selected folder URL.
    /// - Parameter url: Folder root.
    func handleFolderDrop(_ url: URL) {
        guard state.isDropEnabled else { return }
        guard !state.libreOfficeInstallPhase.isInProgress else { return }

        scanTask?.cancel()
        printTask?.cancel()

        state.phase = .scanning
        state.folderName = url.lastPathComponent
        state.files = []
        state.progress = nil
        state.lastResult = nil
        state.errorMessage = nil
        state.isDropEnabled = false
        if case .succeeded = state.libreOfficeInstallPhase {
            // Keep success banner until next explicit install.
        } else if case .failed = state.libreOfficeInstallPhase {
            state.libreOfficeInstallPhase = .idle
        }

        scanTask = Task { [weak self] in
            guard let self else { return }
            do {
                let files = try await scanFolder.execute(url)
                try Task.checkCancellation()
                state.files = files
                state.phase = .ready
                state.errorMessage = files.isEmpty
                    ? String(localized: "message.noSupportedFiles")
                    : nil
                state.isDropEnabled = true
                refreshPrinter()
                refreshOfficeAvailability()
            } catch is CancellationError {
                state.phase = .idle
                state.isDropEnabled = true
            } catch {
                state.phase = .idle
                state.files = []
                state.errorMessage = error.localizedDescription
                state.isDropEnabled = true
            }
        }
    }

    /// Starts printing all scanned files.
    func startPrinting() {
        guard state.canStartPrint else { return }
        guard let printerName = state.printerName else { return }
        let printer = PrinterInfo(name: printerName)
        runPrint(files: state.files, printer: printer)
    }

    /// Retries only the files that failed in the last batch.
    func retryFailed() {
        guard state.phase == .finished else { return }
        let failed = state.failedFiles
        guard !failed.isEmpty else { return }
        guard let printerName = state.printerName ?? printService.defaultPrinter()?.name else {
            state.errorMessage = String(localized: "error.noPrinter")
            return
        }
        refreshPrinter()
        runPrint(files: failed, printer: PrinterInfo(name: printerName))
    }

    /// Cancels an in-flight print batch.
    func cancelPrinting() {
        printTask?.cancel()
    }

    /// Starts one-click LibreOffice download and install.
    func installLibreOffice() {
        guard !state.libreOfficeInstallPhase.isInProgress else { return }
        guard !state.isLibreOfficeInstalled else {
            state.libreOfficeInstallPhase = .succeeded
            return
        }

        installTask?.cancel()
        state.libreOfficeInstallPhase = .downloading(fraction: 0)
        state.errorMessage = nil
        state.isDropEnabled = false

        installTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await libreOfficeInstaller.install { progress in
                    Task { @MainActor [weak self] in
                        self?.applyInstallProgress(progress)
                    }
                }
                try Task.checkCancellation()
                refreshOfficeAvailability()
                state.libreOfficeInstallPhase = .succeeded
                state.isDropEnabled = state.phase != .printing
            } catch is CancellationError {
                state.libreOfficeInstallPhase = .idle
                state.isDropEnabled = state.phase != .printing
            } catch let error as LibreOfficeInstallError {
                if case .cancelled = error {
                    state.libreOfficeInstallPhase = .idle
                } else {
                    state.libreOfficeInstallPhase = .failed(error.localizedDescription)
                }
                state.isDropEnabled = state.phase != .printing
            } catch {
                state.libreOfficeInstallPhase = .failed(error.localizedDescription)
                state.isDropEnabled = state.phase != .printing
            }
        }
    }

    /// Cancels LibreOffice download/install.
    func cancelLibreOfficeInstall() {
        libreOfficeInstaller.cancel()
        installTask?.cancel()
        installTask = nil
        state.libreOfficeInstallPhase = .idle
        state.isDropEnabled = state.phase != .printing && state.phase != .scanning
    }

    /// Presents an open-panel to pick a folder.
    func pickFolder() {
        guard state.isDropEnabled else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "button.selectFolder")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        handleFolderDrop(url)
    }

    private func applyInstallProgress(_ progress: LibreOfficeInstallProgress) {
        switch progress {
        case .downloading(let fraction):
            state.libreOfficeInstallPhase = .downloading(fraction: fraction)
        case .mounting:
            state.libreOfficeInstallPhase = .mounting
        case .copying:
            state.libreOfficeInstallPhase = .copying
        case .cleaningUp:
            state.libreOfficeInstallPhase = .cleaningUp
        case .finished:
            state.libreOfficeInstallPhase = .succeeded
        }
    }

    private func runPrint(files: [PrintableFile], printer: PrinterInfo) {
        printTask?.cancel()

        state.phase = .printing
        state.isDropEnabled = false
        state.progress = BatchPrintProgress(
            currentIndex: 0,
            totalCount: files.count,
            currentFileName: "",
            phase: .pending,
            succeededCount: 0,
            failedCount: 0
        )
        state.lastResult = nil
        state.errorMessage = nil

        printTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await printBatch.execute(files, printer: printer) { progress in
                    Task { @MainActor [weak self] in
                        self?.state.progress = progress
                    }
                }
                try Task.checkCancellation()
                state.lastResult = result
                state.phase = .finished
                state.isDropEnabled = true
                refreshOfficeAvailability()
                if !result.failed.isEmpty {
                    state.errorMessage = String(
                        localized: "message.failedCount \(result.failed.count)"
                    )
                }
            } catch is CancellationError {
                state.phase = .finished
                state.isDropEnabled = true
                state.errorMessage = String(localized: "message.cancelled")
            } catch {
                state.phase = .finished
                state.isDropEnabled = true
                state.errorMessage = error.localizedDescription
            }
        }
    }
}
