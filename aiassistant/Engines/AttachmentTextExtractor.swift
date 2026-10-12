import Foundation
import Dispatch
import Synchronization
import PDFKit
import Vision
import ImageIO
import UniformTypeIdentifiers

/// PDFKit and Vision expose synchronous file and OCR APIs. A dedicated queue
/// keeps this blocking integration off both MainActor and Swift's cooperative
/// executor. Cancellation is shared safely with the worker and checked per page.
nonisolated enum AttachmentTextExtractor {
    private static let worker = DispatchQueue(label: "com.transfinite.aiassistant.attachment-extraction", qos: .userInitiated)

    static func extract(from url: URL) async throws -> String {
        let cancelled = Mutex(false)
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                worker.async {
                    let checkCancellation = {
                        if cancelled.withLock({ $0 }) {
                            throw CancellationError()
                        }
                    }
                    do {
                        try checkCancellation()
                        let extracted = try extractScopedText(from: url, checkCancellation: checkCancellation)
                        try checkCancellation()
                        let text = preparedAttachmentText(from: extracted)
                        guard !text.isEmpty else { throw ImportError.noTextFound }
                        continuation.resume(returning: text)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } onCancel: {
            cancelled.withLock { $0 = true }
        }
    }

    private static func extractScopedText(from fileURL: URL, checkCancellation: () throws -> Void) throws -> String {
        let hasAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        guard hasAccess || FileManager.default.isReadableFile(atPath: fileURL.path) else {
            throw ImportError.permissionDenied
        }

        try validateAttachmentSize(fileURL)

        guard let type = UTType(filenameExtension: fileURL.pathExtension.lowercased()) else {
            throw ImportError.unsupportedFile
        }

        if type.conforms(to: .pdf) {
            return try extractTextFromPDF(at: fileURL, checkCancellation: checkCancellation)
        }
        if type.conforms(to: .image) {
            return try extractTextFromImage(at: fileURL, checkCancellation: checkCancellation)
        }

        throw ImportError.unsupportedFile
    }

    private static func validateAttachmentSize(_ fileURL: URL) throws {
        let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = values.fileSize, fileSize > ImportLimits.maxFileBytes {
            throw ImportError.fileTooLarge
        }
    }

    private static func preparedAttachmentText(from extracted: String) -> String {
        let trimmed = extracted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > ImportLimits.maxTextCharacters else { return trimmed }

        let prefix = String(trimmed.prefix(ImportLimits.maxTextCharacters))
        return """
        \(prefix)

        [Attachment text was truncated to fit Ari's prompt limit.]
        """
    }

    private static func extractTextFromPDF(at fileURL: URL, checkCancellation: () throws -> Void) throws -> String {
        guard let pdf = PDFDocument(url: fileURL) else {
            throw ImportError.unreadableFile
        }
        if pdf.pageCount > 50 {
            throw ImportError.pdfTooLong(pageCount: pdf.pageCount)
        }

        var pages: [String] = []
        for index in 0..<pdf.pageCount {
            try checkCancellation()
            if let text = pdf.page(at: index)?.string?.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                pages.append(text)
            }
        }
        return pages.joined(separator: "\n\n")
    }

    private static func extractTextFromImage(at fileURL: URL, checkCancellation: () throws -> Void) throws -> String {
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 4_096,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary) else {
            throw ImportError.unreadableFile
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try checkCancellation()
        try handler.perform([request])
        try checkCancellation()

        let observations = request.results ?? []
        let sorted = observations.sorted { lhs, rhs in
            if abs(lhs.boundingBox.minY - rhs.boundingBox.minY) > 0.02 {
                return lhs.boundingBox.minY > rhs.boundingBox.minY
            }
            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }

        return sorted
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }

}

nonisolated private enum ImportLimits {
    nonisolated static let maxFileBytes = 20 * 1024 * 1024
    nonisolated static let maxTextCharacters = 60_000
}

nonisolated private enum ImportError: LocalizedError {
    case unsupportedFile
    case unreadableFile
    case noTextFound
    case pdfTooLong(pageCount: Int)
    case permissionDenied
    case fileTooLarge

    var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            "Only PDF and image files are supported."
        case .unreadableFile:
            "The selected file couldn’t be read."
        case .noTextFound:
            "No readable text was found in that file."
        case .pdfTooLong(let pageCount):
            "This PDF has \(pageCount) pages. The maximum allowed is 50 pages."
        case .permissionDenied:
            "Ari could not get permission to read that file."
        case .fileTooLarge:
            "That file is too large. Choose a PDF or image under 20 MB."
        }
    }
}

