import Foundation

/// High-level phase of the batch print screen.
enum BatchPrintPhase: Equatable, Sendable {
    case idle
    case scanning
    case ready
    case printing
    case finished
}

/// UI phase while installing LibreOffice from inside the app.
enum LibreOfficeInstallUIPhase: Equatable, Sendable {
    case idle
    case downloading(fraction: Double)
    case mounting
    case copying
    case cleaningUp
    case succeeded
    case failed(String)

    var isInProgress: Bool {
        switch self {
        case .downloading, .mounting, .copying, .cleaningUp:
            true
        default:
            false
        }
    }
}

/// Presentation state for the batch print screen.
struct BatchPrintState: Equatable, Sendable {
    var phase: BatchPrintPhase = .idle
    var folderName: String?
    var files: [PrintableFile] = []
    var jobs: [PrintJob] = []
    var printSettings: PrintSettings = .default
    var printerName: String?
    var availablePrinters: [PrinterInfo] = []
    var progress: BatchPrintProgress?
    var lastResult: BatchPrintResult?
    var errorMessage: String?
    var isDropEnabled: Bool = true
    var isLibreOfficeInstalled: Bool = LibreOfficeConverter.isInstalled
    var isMicrosoftOfficeInstalled: Bool = MicrosoftOfficeConverter.isInstalled
    var libreOfficeInstallPhase: LibreOfficeInstallUIPhase = .idle

    var sortOrder: FileSortOrder = .name
    var enabledKinds: Set<FileKind> = Set(FileKind.allCases)
    var presets: [PrintPreset] = []
    var selectedPresetID: UUID?
    var history: [PrintHistoryRecord] = []

    var archiveEnabled: Bool = false
    var archiveFolderPath: String?
    var hotFolderEnabled: Bool = false
    var hotFolderPath: String?
    var hotFolderAutoPrint: Bool = false

    var totalCount: Int { jobs.count }

    var pdfCount: Int { jobs.filter { $0.file.kind == .pdf }.count }
    var wordCount: Int { jobs.filter { $0.file.kind == .word }.count }
    var excelCount: Int { jobs.filter { $0.file.kind == .excel }.count }
    var imageCount: Int { jobs.filter { $0.file.kind == .image }.count }
    var markdownCount: Int { jobs.filter { $0.file.kind == .markdown }.count }

    var hasOfficeFiles: Bool {
        wordCount > 0 || excelCount > 0
    }

    /// Show one-click LibreOffice install when Office docs are present and LO is missing.
    var showsLibreOfficeInstall: Bool {
        hasOfficeFiles && !isLibreOfficeInstalled
    }

    var isPageRangeValid: Bool {
        if case .success = printSettings.resolvedPageRange {
            true
        } else {
            false
        }
    }

    var archiveFolderName: String? {
        archiveFolderPath.map { URL(fileURLWithPath: $0).lastPathComponent }
    }

    var hotFolderName: String? {
        hotFolderPath.map { URL(fileURLWithPath: $0).lastPathComponent }
    }

    var canStartPrint: Bool {
        phase == .ready
            && !jobs.isEmpty
            && printerName != nil
            && isPageRangeValid
            && !libreOfficeInstallPhase.isInProgress
    }

    var canAutoPrintHotFolder: Bool {
        (phase == .ready || phase == .finished || phase == .idle)
            && printerName != nil
            && isPageRangeValid
            && !libreOfficeInstallPhase.isInProgress
    }

    var failedFiles: [PrintableFile] {
        lastResult?.failed.map(\.file) ?? []
    }

    var libreOfficeInstallProgressValue: Double? {
        switch libreOfficeInstallPhase {
        case .downloading(let fraction):
            max(0, min(1, fraction))
        case .mounting:
            1.0
        case .copying:
            1.0
        case .cleaningUp:
            1.0
        default:
            nil
        }
    }
}
