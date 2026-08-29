import AppKit
import CoreText
import Foundation

/// Converts Markdown files to multi-page PDF using Foundation markdown parsing.
nonisolated struct MarkdownPDFConverter: FileConverting {
    var supportedKinds: Set<FileKind> { [.markdown] }

    private let pageSize = CGSize(width: 612, height: 792) // US Letter
    private let margin: CGFloat = 54

    func convertToPDF(_ file: PrintableFile) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            let data: Data
            do {
                data = try Data(contentsOf: file.url)
            } catch {
                throw PrintBatchError.conversionFailed(
                    String(localized: "error.markdownReadFailed")
                )
            }

            guard let text = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .isoLatin1)
            else {
                throw PrintBatchError.conversionFailed(
                    String(localized: "error.markdownReadFailed")
                )
            }

            let attributed: NSAttributedString
            do {
                let parsed = try AttributedString(
                    markdown: text,
                    options: AttributedString.MarkdownParsingOptions(
                        interpretedSyntax: .full
                    )
                )
                attributed = Self.printReadyAttributedString(from: parsed)
            } catch {
                // Fall back to plain text so unparsable markdown still prints.
                attributed = Self.plainAttributedString(text)
            }

            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("pdf")

            try Self.writePDF(
                attributed,
                to: outputURL,
                pageSize: pageSize,
                margin: margin
            )
            return outputURL
        }.value
    }

    /// Builds print-safe attributes: always black ink on white paper (ignore dark-mode colors).
    private static func printReadyAttributedString(from parsed: AttributedString) -> NSAttributedString {
        let converted = NSMutableAttributedString(attributedString: NSAttributedString(parsed))
        let fullRange = NSRange(location: 0, length: converted.length)
        guard fullRange.length > 0 else { return converted }

        converted.enumerateAttributes(in: fullRange, options: []) { attributes, range, _ in
            var next = attributes
            if next[.font] == nil {
                next[.font] = NSFont.systemFont(ofSize: 12)
            }
            // Dynamic colors (e.g. `.textColor` / `.labelColor`) resolve to white in Dark Mode
            // and disappear on a white PDF page when printed.
            next[.foregroundColor] = NSColor.black
            converted.setAttributes(next, range: range)
        }

        return converted
    }

    private static func plainAttributedString(_ text: String) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.black,
            ]
        )
    }

    private static func writePDF(
        _ attributed: NSAttributedString,
        to outputURL: URL,
        pageSize: CGSize,
        margin: CGFloat
    ) throws {
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let context = CGContext(outputURL as CFURL, mediaBox: &mediaBox, nil) else {
            throw PrintBatchError.conversionFailed(
                String(localized: "error.pdfCreateFailed")
            )
        }

        // Core Text fills a path from its max-Y downward (PDF coords: origin bottom-left).
        let textRect = CGRect(
            x: margin,
            y: margin,
            width: pageSize.width - margin * 2,
            height: pageSize.height - margin * 2
        )

        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        var location = 0
        let totalLength = attributed.length

        if totalLength == 0 {
            context.beginPDFPage(nil)
            context.endPDFPage()
            context.closePDF()
            return
        }

        while location < totalLength {
            context.beginPDFPage(nil)
            context.saveGState()
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(mediaBox)
            context.setFillColor(gray: 0, alpha: 1)

            let path = CGPath(rect: textRect, transform: nil)
            let frame = CTFramesetterCreateFrame(
                framesetter,
                CFRange(location: location, length: 0),
                path,
                nil
            )
            CTFrameDraw(frame, context)

            let visible = CTFrameGetVisibleStringRange(frame)
            context.restoreGState()
            context.endPDFPage()

            if visible.length <= 0 {
                break
            }
            location += visible.length
        }

        context.closePDF()
    }
}
