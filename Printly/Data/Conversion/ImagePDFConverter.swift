import Foundation
import ImageIO

/// Converts raster images (including multi-page TIFF and HEIC) into PDF.
nonisolated struct ImagePDFConverter: FileConverting {
    var supportedKinds: Set<FileKind> { [.image] }

    func convertToPDF(_ file: PrintableFile) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithURL(file.url as CFURL, nil) else {
                throw PrintBatchError.conversionFailed(
                    String(localized: "error.imageDecodeFailed")
                )
            }

            let frameCount = CGImageSourceGetCount(source)
            guard frameCount > 0 else {
                throw PrintBatchError.conversionFailed(
                    String(localized: "error.imageDecodeFailed")
                )
            }

            guard let firstImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw PrintBatchError.conversionFailed(
                    String(localized: "error.imageDecodeFailed")
                )
            }

            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("pdf")

            var mediaBox = CGRect(
                x: 0,
                y: 0,
                width: CGFloat(firstImage.width),
                height: CGFloat(firstImage.height)
            )
            guard let context = CGContext(
                outputURL as CFURL,
                mediaBox: &mediaBox,
                nil
            ) else {
                throw PrintBatchError.conversionFailed(
                    String(localized: "error.pdfCreateFailed")
                )
            }

            var addedPages = 0
            for index in 0..<frameCount {
                guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else {
                    continue
                }
                var pageRect = CGRect(
                    x: 0,
                    y: 0,
                    width: CGFloat(cgImage.width),
                    height: CGFloat(cgImage.height)
                )
                context.beginPage(mediaBox: &pageRect)
                context.draw(cgImage, in: pageRect)
                context.endPage()
                addedPages += 1
            }

            context.closePDF()

            guard addedPages > 0 else {
                throw PrintBatchError.conversionFailed(
                    String(localized: "error.imageDecodeFailed")
                )
            }

            return outputURL
        }.value
    }
}
