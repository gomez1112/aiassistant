import Foundation
import Testing
@testable import aiassistant

@MainActor
struct AttachmentTextExtractorTests {
    @Test func cancelledExtractionDoesNotAttemptToOpenTheFile() async {
        let operation = Task {
            try await AttachmentTextExtractor.extract(from: URL(filePath: "/nonexistent/cancelled.pdf"))
        }
        operation.cancel()
        do {
            _ = try await operation.value
            Issue.record("Expected the extraction to be cancelled")
        } catch is CancellationError {
            // Cancellation takes precedence over file access and parsing errors.
        } catch {
            Issue.record("Cancellation was reported as an import failure: \(error)")
        }
    }

    @Test func unsupportedFilesReturnAnActionableError() async throws {
        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).txt")
        try Data("A source note".utf8).write(to: url)
        defer {
            do { try FileManager.default.removeItem(at: url) }
            catch { Issue.record("Could not clean up the fixture: \(error)") }
        }

        do {
            _ = try await AttachmentTextExtractor.extract(from: url)
            Issue.record("Expected an unsupported file error")
        } catch {
            #expect(error.localizedDescription == "Only PDF and image files are supported.")
        }
    }
}
