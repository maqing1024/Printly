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
    private let settingsStore: any SettingsStoring
    private let archiver: any FileArchiving
    private let folderWatcher: any FolderWatching
    private let sorter = FileSorter()

    private var scanTask: Task<Void, Never>?
    private var printTask: Task<Void, Never>?
    private var installTask: Task<Void, Never>?
    private var hotFolderKnownPaths = Set<String>()

    /// Creates the batch print view model.
    init(
        scanFolder: ScanFolderUseCase,
        printBatch: PrintBatchUseCase,
        printService: any PrintServing,
        libreOfficeInstaller: LibreOfficeInstaller = LibreOfficeInstaller(),
        settingsStore: any SettingsStoring = JSONSettingsStore(),
        archiver: any FileArchiving = FileArchiveService(),
        folderWatcher: any FolderWatching
    ) {
        self.scanFolder = scanFolder
        self.printBatch = printBatch
        self.printService = printService
        self.libreOfficeInstaller = libreOfficeInstaller
        self.settingsStore = settingsStore
        self.archiver = archiver
        self.folderWatcher = folderWatcher
        applySettings(settingsStore.load())
        refreshPrinter()
        refreshOfficeAvailability()
        restoreHotFolderWatchIfNeeded()
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
    func selectPrinter(_ name: String) {
        guard state.availablePrinters.contains(where: { $0.name == name }) else { return }
        state.printerName = name
        persistSettings()
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
    func handleFolderDrop(_ url: URL) {
        handleDroppedURLs([url])
    }

    /// Handles dropped or chosen files and folders.
    func handleDroppedURLs(_ urls: [URL]) {
        guard state.isDropEnabled else { return }
        guard !state.libreOfficeInstallPhase.isInProgress else { return }
        guard !urls.isEmpty else { return }

        scanTask?.cancel()
        printTask?.cancel()

        state.phase = .scanning
        state.folderName = Self.displayName(for: urls)
        state.files = []
        state.jobs = []
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
                let files = try await scanFolder.execute(urls)
                try Task.checkCancellation()
                applyScannedFiles(files)
                state.errorMessage = state.jobs.isEmpty
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
                state.jobs = []
                state.errorMessage = error.localizedDescription
                state.isDropEnabled = true
            }
        }
    }

    /// Updates the number of copies (1...99).
    func setCopies(_ copies: Int) {
        state.printSettings.copies = copies
        state.printSettings.clampCopies()
        persistSettings()
    }

    /// Updates two-sided printing.
    func setDuplex(_ duplex: DuplexMode) {
        state.printSettings.duplex = duplex
        persistSettings()
    }

    /// Updates color versus black-and-white output.
    func setColorMode(_ colorMode: ColorMode) {
        state.printSettings.colorMode = colorMode
        persistSettings()
    }

    /// Updates the page-range text (blank means all pages).
    func setPageRangeText(_ text: String) {
        state.printSettings.pageRangeText = text
        if state.isPageRangeValid {
            if state.errorMessage == String(localized: "error.invalidPageRange") {
                state.errorMessage = nil
            }
        }
        persistSettings()
    }

    /// Updates queue sort order.
    func setSortOrder(_ order: FileSortOrder) {
        state.sortOrder = order
        rebuildQueue(resetStatuses: state.phase != .printing)
        persistSettings()
    }

    /// Enables or disables a file kind in the queue.
    func setKind(_ kind: FileKind, enabled: Bool) {
        if enabled {
            state.enabledKinds.insert(kind)
        } else {
            state.enabledKinds.remove(kind)
        }
        rebuildQueue(resetStatuses: state.phase != .printing)
        persistSettings()
    }

    /// Saves the current printer and options as a named preset.
    func savePreset(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let preset = PrintPreset(
            name: trimmed,
            printerName: state.printerName,
            settings: state.printSettings
        )
        if let index = state.presets.firstIndex(where: { $0.name == trimmed }) {
            var updated = preset
            updated.id = state.presets[index].id
            state.presets[index] = updated
            state.selectedPresetID = updated.id
        } else {
            state.presets.append(preset)
            state.selectedPresetID = preset.id
        }
        persistSettings()
    }

    /// Applies a saved preset.
    func applyPreset(id: UUID) {
        guard let preset = state.presets.first(where: { $0.id == id }) else { return }
        state.selectedPresetID = id
        state.printSettings = preset.settings
        if let printerName = preset.printerName,
           state.availablePrinters.contains(where: { $0.name == printerName }) {
            state.printerName = printerName
        }
        persistSettings()
    }

    /// Deletes a saved preset.
    func deletePreset(id: UUID) {
        state.presets.removeAll { $0.id == id }
        if state.selectedPresetID == id {
            state.selectedPresetID = nil
        }
        persistSettings()
    }

    /// Starts printing the visible (filtered) queue.
    func startPrinting() {
        guard state.canStartPrint else { return }
        guard let printerName = state.printerName else { return }
        guard state.isPageRangeValid else {
            state.errorMessage = String(localized: "error.invalidPageRange")
            return
        }
        runPrint(files: state.jobs.map(\.file), printer: PrinterInfo(name: printerName))
    }

    /// Retries only the files that failed in the last batch.
    func retryFailed() {
        guard state.phase == .finished else { return }
        let failed = state.failedFiles
        guard !failed.isEmpty else { return }
        retry(files: failed)
    }

    /// Retries a single failed queue item.
    func retryJob(id: UUID) {
        guard state.phase != .printing else { return }
        guard let job = state.jobs.first(where: { $0.id == id }) else { return }
        guard case .failed = job.status else { return }
        retry(files: [job.file])
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

    /// Presents an open-panel to pick files or folders.
    func pickFolder() {
        guard state.isDropEnabled else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = String(localized: "button.selectFolder")
        guard panel.runModal() == .OK else { return }
        handleDroppedURLs(panel.urls)
    }

    /// Enables or disables copying successful prints to the archive folder.
    func setArchiveEnabled(_ enabled: Bool) {
        state.archiveEnabled = enabled
        persistSettings()
    }

    /// Sets the archive destination path (used by the folder picker and tests).
    func setArchiveFolderPath(_ path: String) {
        state.archiveFolderPath = path
        persistSettings()
    }

    /// Lets the user choose the archive destination folder.
    func pickArchiveFolder() {
        guard let url = pickDirectory(promptKey: "button.chooseArchiveFolder") else { return }
        setArchiveFolderPath(url.path)
    }

    /// Enables or disables hot-folder watching.
    func setHotFolderEnabled(_ enabled: Bool) {
        state.hotFolderEnabled = enabled
        persistSettings()
        if enabled {
            restoreHotFolderWatchIfNeeded()
        } else {
            folderWatcher.stop()
        }
    }

    /// Enables or disables auto-print for newly arrived hot-folder files.
    func setHotFolderAutoPrint(_ enabled: Bool) {
        state.hotFolderAutoPrint = enabled
        persistSettings()
    }

    /// Lets the user choose the watched hot folder.
    func pickHotFolder() {
        guard let url = pickDirectory(promptKey: "button.chooseHotFolder") else { return }
        state.hotFolderPath = url.path
        persistSettings()
        hotFolderKnownPaths.removeAll()
        if state.hotFolderEnabled {
            restoreHotFolderWatchIfNeeded()
        }
    }

    /// Removes all stored history rows.
    func clearHistory() {
        state.history = []
        persistSettings()
    }

    private func retry(files: [PrintableFile]) {
        guard state.isPageRangeValid else {
            state.errorMessage = String(localized: "error.invalidPageRange")
            return
        }
        guard let printerName = state.printerName ?? printService.defaultPrinter()?.name else {
            state.errorMessage = String(localized: "error.noPrinter")
            return
        }
        refreshPrinter()
        runPrint(files: files, printer: PrinterInfo(name: printerName))
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
        state.jobs = files.map { PrintJob(file: $0) }
        state.progress = BatchPrintProgress(
            currentIndex: 0,
            totalCount: files.count,
            currentFileID: nil,
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
                let result = try await printBatch.execute(
                    files,
                    printer: printer,
                    settings: state.printSettings
                ) { progress in
                    Task { @MainActor [weak self] in
                        self?.applyProgress(progress)
                    }
                }
                try Task.checkCancellation()
                state.lastResult = result
                state.phase = .finished
                state.isDropEnabled = true
                refreshOfficeAvailability()
                appendHistory(result, printerName: printer.name)
                archiveSucceeded(result.succeeded)
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

    private func applyProgress(_ progress: BatchPrintProgress) {
        state.progress = progress
        guard let fileID = progress.currentFileID,
              let index = state.jobs.firstIndex(where: { $0.file.id == fileID })
        else { return }
        state.jobs[index].status = progress.phase
    }

    private func applyScannedFiles(_ files: [PrintableFile]) {
        state.files = files
        rebuildQueue(resetStatuses: true)
        state.phase = .ready
    }

    private func rebuildQueue(resetStatuses: Bool) {
        let visible = sorter.sorted(
            state.files.filter { state.enabledKinds.contains($0.kind) },
            order: state.sortOrder
        )
        if resetStatuses {
            state.jobs = visible.map { PrintJob(file: $0) }
            return
        }
        let statusByID = Dictionary(uniqueKeysWithValues: state.jobs.map { ($0.file.id, $0.status) })
        state.jobs = visible.map { file in
            PrintJob(file: file, status: statusByID[file.id] ?? .pending)
        }
    }

    private func appendHistory(_ result: BatchPrintResult, printerName: String) {
        let succeeded = result.succeeded.map {
            PrintHistoryRecord(
                fileName: $0.displayName,
                kind: $0.kind,
                printerName: printerName,
                succeeded: true
            )
        }
        let failed = result.failed.map {
            PrintHistoryRecord(
                fileName: $0.file.displayName,
                kind: $0.file.kind,
                printerName: printerName,
                succeeded: false,
                message: $0.message
            )
        }
        state.history = (failed + succeeded + state.history)
        persistSettings()
    }

    private func archiveSucceeded(_ files: [PrintableFile]) {
        guard state.archiveEnabled, let path = state.archiveFolderPath, !files.isEmpty else { return }
        do {
            try archiver.archive(files, to: URL(fileURLWithPath: path))
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

    private func applySettings(_ settings: AppSettings) {
        state.presets = settings.presets
        state.history = settings.history
        state.sortOrder = settings.sortOrder
        state.enabledKinds = settings.enabledKindSet
        state.archiveEnabled = settings.archiveEnabled
        state.archiveFolderPath = settings.archiveFolderPath
        state.hotFolderEnabled = settings.hotFolderEnabled
        state.hotFolderPath = settings.hotFolderPath
        state.hotFolderAutoPrint = settings.hotFolderAutoPrint
    }

    private func persistSettings() {
        settingsStore.save(
            AppSettings(
                presets: state.presets,
                history: state.history,
                sortOrder: state.sortOrder,
                enabledKinds: FileKind.allCases.filter { state.enabledKinds.contains($0) },
                archiveEnabled: state.archiveEnabled,
                archiveFolderPath: state.archiveFolderPath,
                hotFolderEnabled: state.hotFolderEnabled,
                hotFolderPath: state.hotFolderPath,
                hotFolderAutoPrint: state.hotFolderAutoPrint
            )
        )
    }

    private func restoreHotFolderWatchIfNeeded() {
        folderWatcher.stop()
        guard state.hotFolderEnabled, let path = state.hotFolderPath else { return }
        let url = URL(fileURLWithPath: path)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else { return }

        ingestHotFolder(url, printNewFiles: false)
        folderWatcher.start(url: url) { [weak self] in
            self?.ingestHotFolder(url, printNewFiles: true)
        }
    }

    private func ingestHotFolder(_ url: URL, printNewFiles: Bool) {
        scanTask?.cancel()
        scanTask = Task { [weak self] in
            guard let self else { return }
            guard state.phase != .printing else { return }
            do {
                let files = try await scanFolder.execute(url)
                try Task.checkCancellation()
                let newFiles = files.filter { !hotFolderKnownPaths.contains($0.url.path) }
                hotFolderKnownPaths.formUnion(files.map(\.url.path))
                mergeFiles(files)
                state.folderName = url.lastPathComponent
                if printNewFiles, state.hotFolderAutoPrint, !newFiles.isEmpty, state.canAutoPrintHotFolder {
                    let printable = sorter.sorted(
                        newFiles.filter { state.enabledKinds.contains($0.kind) },
                        order: state.sortOrder
                    )
                    if !printable.isEmpty, let printerName = state.printerName {
                        runPrint(files: printable, printer: PrinterInfo(name: printerName))
                    }
                }
            } catch {
                if state.phase != .printing {
                    state.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func mergeFiles(_ incoming: [PrintableFile]) {
        var byPath = Dictionary(uniqueKeysWithValues: state.files.map { ($0.url.path, $0) })
        for file in incoming where byPath[file.url.path] == nil {
            byPath[file.url.path] = file
        }
        state.files = Array(byPath.values)
        rebuildQueue(resetStatuses: state.phase != .finished)
        if state.phase == .idle || state.phase == .scanning {
            state.phase = state.jobs.isEmpty ? .idle : .ready
        }
    }

    private func pickDirectory(promptKey: String.LocalizationValue) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: promptKey)
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    private static func displayName(for urls: [URL]) -> String {
        if urls.count == 1 {
            return urls[0].lastPathComponent
        }
        return String(localized: "summary.itemCount \(urls.count)")
    }
}
