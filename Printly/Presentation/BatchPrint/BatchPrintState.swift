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
    var printerName: String?
    var availablePrinters: [PrinterInfo] = []
    var progress: BatchPrintProgress?
    var lastResult: BatchPrintResult?
    var errorMessage: String?
    var isDropEnabled: Bool = true
    var isLibreOfficeInstalled: Bool = LibreOfficeConverter.isInstalled
    var isMicrosoftOfficeInstalled: Bool = MicrosoftOfficeConverter.isInstalled
    var libreOfficeInstallPhase: LibreOfficeInstallUIPhase = .idle

    var totalCount: Int { files.count }

    var pdfCount: Int { files.filter { $0.kind == .pdf }.count }
    var wordCount: Int { files.filter { $0.kind == .word }.count }
    var excelCount: Int { files.filter { $0.kind == .excel }.count }
    var imageCount: Int { files.filter { $0.kind == .image }.count }
    var markdownCount: Int { files.filter { $0.kind == .markdown }.count }

    var hasOfficeFiles: Bool {
        wordCount > 0 || excelCount > 0
    }

    /// Show one-click LibreOffice install when Office docs are present and LO is missing.
    var showsLibreOfficeInstall: Bool {
        hasOfficeFiles && !isLibreOfficeInstalled
    }

    var canStartPrint: Bool {
        phase == .ready
            && !files.isEmpty
            && printerName != nil
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
