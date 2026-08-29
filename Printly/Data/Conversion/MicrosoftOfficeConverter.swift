import AppKit
import Foundation

/// Converts DOCX/XLSX to PDF via installed Microsoft Word / Excel (AppleScript).
nonisolated struct MicrosoftOfficeConverter: FileConverting {
    var supportedKinds: Set<FileKind> { [.word, .excel] }

    func convertToPDF(_ file: PrintableFile) async throws -> URL {
        switch file.kind {
        case .word:
            guard Self.isWordInstalled else {
                throw PrintBatchError.conversionFailed(
                    String(localized: "error.microsoftWordMissing")
                )
            }
            return try await exportWithWord(file.url)
        case .excel:
            guard Self.isExcelInstalled else {
                throw PrintBatchError.conversionFailed(
                    String(localized: "error.microsoftExcelMissing")
                )
            }
            return try await exportWithExcel(file.url)
        default:
            throw PrintBatchError.conversionFailed(
                String(localized: "error.unsupportedKind")
            )
        }
    }

    /// Returns whether Microsoft Word is available for automation.
    static var isWordInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.Word") != nil
    }

    /// Returns whether Microsoft Excel is available for automation.
    static var isExcelInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.Excel") != nil
    }

    /// Returns whether any Microsoft Office app usable for conversion is installed.
    static var isInstalled: Bool {
        isWordInstalled || isExcelInstalled
    }

    private func exportWithWord(_ sourceURL: URL) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")

        let script = """
        set inPath to POSIX file "\(escapedPOSIX(sourceURL.path))"
        set outPath to "\(escapedPOSIX(outputURL.path))"
        tell application "Microsoft Word"
          set theDoc to open file name (inPath as string)
          save as theDoc file name outPath file format format PDF
          close theDoc saving no
        end tell
        """
        try await runAppleScript(script)
        try ensurePDFExists(outputURL)
        return outputURL
    }

    private func exportWithExcel(_ sourceURL: URL) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")

        let script = """
        set inPath to "\(escapedPOSIX(sourceURL.path))"
        set outPath to "\(escapedPOSIX(outputURL.path))"
        tell application "Microsoft Excel"
          set wb to open workbook workbook file name inPath
          tell wb
            save workbook as filename outPath file format PDF file format
          end tell
          close wb saving no
        end tell
        """
        try await runAppleScript(script)
        try ensurePDFExists(outputURL)
        return outputURL
    }

    private func runAppleScript(_ source: String) async throws {
        try await Task.detached(priority: .userInitiated) {
            var error: NSDictionary?
            guard let script = NSAppleScript(source: source) else {
                throw PrintBatchError.conversionFailed(
                    String(localized: "error.officeConversionFailed")
                )
            }
            _ = script.executeAndReturnError(&error)
            if let error {
                let message = (error[NSAppleScript.errorMessage] as? String)
                    ?? String(localized: "error.officeConversionFailed")
                throw PrintBatchError.conversionFailed(message)
            }
        }.value
    }

    private func ensurePDFExists(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PrintBatchError.conversionFailed(
                String(localized: "error.officeConversionFailed")
            )
        }
    }

    private func escapedPOSIX(_ path: String) -> String {
        path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
