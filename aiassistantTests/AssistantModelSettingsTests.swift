import Foundation
import FoundationModels
import Testing
@testable import aiassistant

@MainActor
struct AssistantModelSettingsTests {
    @Test func processingChoicePersistsAndCanBeRevoked() throws {
        let suite = "AssistantModelSettingsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = AssistantModelSettings(defaults: defaults)
        #expect(settings.processingMode == .onDevice)
        settings.usesPrivateCloudCompute = true
        #expect(AssistantModelSettings(defaults: defaults).processingMode == .privateCloudCompute)

        settings.usesPrivateCloudCompute = false
        #expect(AssistantModelSettings(defaults: defaults).processingMode == .onDevice)
    }

    @Test func unknownProcessingChoiceKeepsRequestsOnDevice() throws {
        let suite = "AssistantModelSettingsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("unrecognized-provider", forKey: "assistant.processingMode")

        #expect(AssistantModelSettings(defaults: defaults).processingMode == .onDevice)
    }

    @Test func cloudFailuresExplainRecoveryWithoutExposingDiagnostics() {
        let networkError = PrivateCloudComputeLanguageModel.Error.networkFailure(
            .init(debugDescription: "internal network diagnostic")
        )
        let networkMessage = AssistantModelSettings.requestErrorMessage(networkError)
        #expect(networkMessage.contains("internet connection"))
        #expect(!networkMessage.contains("internal network diagnostic"))

        let quotaError = PrivateCloudComputeLanguageModel.Error.quotaLimitReached(
            .init(resetDate: .now.addingTimeInterval(3_600), debugDescription: "internal quota diagnostic")
        )
        let quotaMessage = AssistantModelSettings.requestErrorMessage(quotaError)
        #expect(quotaMessage.contains("resets"))
        #expect(quotaMessage.contains("on-device AI"))
        #expect(!quotaMessage.contains("internal quota diagnostic"))
    }

    @Test func oversizedRequestsOfferAnActionableRecovery() {
        let error = LanguageModelError.contextSizeExceeded(
            .init(contextSize: 4_096, tokenCount: 5_000, debugDescription: "context overflow")
        )
        #expect(AssistantModelSettings.requestErrorMessage(error).contains("shorter source"))
    }
}
