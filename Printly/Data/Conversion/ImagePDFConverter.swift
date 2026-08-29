import Foundation
import ImageIO

/// Converts raster images (including HEIC) into a single-page PDF.
nonisolated struct ImagePDFConverter: FileConverting {
    var supportedKinds: Set<FileKind> { [.image] }

    func convertToPDF(_ file: PrintableFile) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithURL(file.url as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else {
                throw PrintBatchError.conversionFailed(
                    String(localized: "error.imageDecodeFailed")
                )
            }

            let pageRect = CGRect(
                x: 0,
                y: 0,
                width: CGFloat(cgImage.width),
                height: CGFloat(cgImage.height)
            )

            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("pdf")

            var mediaBox = pageRect
            guard let context = CGContext(
                outputURL as CFURL,
                mediaBox: &mediaBox,
                nil
            ) else {
                throw PrintBatchError.conversionFailed(
                    String(localized: "error.pdfCreateFailed")
                )
            }

            context.beginPDFPage(nil)
            context.draw(cgImage, in: pageRect)
            context.endPDFPage()
            context.closePDF()

            return outputURL
        }.value
    }
}
