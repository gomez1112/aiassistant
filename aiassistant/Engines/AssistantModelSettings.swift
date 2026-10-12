import Foundation
import FoundationModels
import Observation

/// The processing choice is device-local: enabling cloud inference on one device
/// must not silently enable it on another through synced user preferences.
@available(iOS 27.0, macOS 27.0, *)
@MainActor
@Observable
final class AssistantModelSettings {
    private static let processingModeKey = "assistant.processingMode"
    private let defaults: UserDefaults
    private let cloudModel = PrivateCloudComputeLanguageModel()

    var processingMode: AssistantProcessingMode {
        didSet {
            defaults.set(processingMode.rawValue, forKey: Self.processingModeKey)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        processingMode = defaults.string(forKey: Self.processingModeKey)
            .flatMap(AssistantProcessingMode.init(rawValue:)) ?? .onDevice
    }

    var usesPrivateCloudCompute: Bool {
        get { processingMode == .privateCloudCompute }
        set { processingMode = newValue ? .privateCloudCompute : .onDevice }
    }

    var statusDescription: String {
        unavailableMessage() ?? (usesPrivateCloudCompute
            ? "Private Cloud Compute is ready. Requires an internet connection."
            : "On-device AI is ready.")
    }

    func unavailableMessage() -> String? {
        switch processingMode {
        case .onDevice:
            switch SystemLanguageModel.default.availability {
            case .available:
                return nil
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible:
                    return "This device does not support Apple Intelligence."
                case .appleIntelligenceNotEnabled:
                    return "Enable Apple Intelligence in system Settings to use on-device AI."
                case .modelNotReady:
                    return "The on-device model is still downloading or preparing. Try again later."
                @unknown default:
                    return "On-device AI is unavailable right now. Try again later."
                }
            @unknown default:
                return "On-device AI is unavailable right now. Try again later."
            }
        case .privateCloudCompute:
            switch cloudModel.availability {
            case .available:
                // Availability and the per-user quota are independent in OS 27.
                if cloudModel.quotaUsage.isLimitReached {
                    return Self.quotaMessage(resetDate: cloudModel.quotaUsage.resetDate)
                }
                return nil
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible:
                    return "Private Cloud Compute is unavailable on this device. Choose on-device AI in Ari Settings."
                case .systemNotReady:
                    return "Private Cloud Compute is still preparing. Try again later or choose on-device AI in Ari Settings."
                @unknown default:
                    return "Private Cloud Compute is unavailable right now. Try again later."
                }
            @unknown default:
                return "Private Cloud Compute is unavailable right now. Try again later."
            }
        }
    }

    /// All AI entry points use the same explicit processing choice, including
    /// transforms and summaries. Never send content to PCC as a silent fallback.
    func makeSession(instructions: String? = nil) throws -> LanguageModelSession {
        if let message = unavailableMessage() {
            throw ModelUnavailableError(message: message)
        }
        switch processingMode {
        case .onDevice:
            return LanguageModelSession(model: SystemLanguageModel.default, instructions: instructions)
        case .privateCloudCompute:
            return LanguageModelSession(model: cloudModel, instructions: instructions)
        }
    }

    static func requestErrorMessage(_ error: any Error) -> String {
        if let cloudError = error as? PrivateCloudComputeLanguageModel.Error {
            switch cloudError {
            case .networkFailure:
                return "Private Cloud Compute could not connect. Check your internet connection and try again."
            case .quotaLimitReached(let details):
                return quotaMessage(resetDate: details.resetDate)
            case .serviceUnavailable:
                return "Private Cloud Compute is temporarily unavailable. Try again later or choose on-device AI in Ari Settings."
            @unknown default:
                return "Private Cloud Compute could not complete this request. Try again later."
            }
        }
        if let modelError = error as? LanguageModelError {
            switch modelError {
            case .contextSizeExceeded:
                return "This request is too long for the selected model. Use a shorter source or start a new chat."
            case .rateLimited:
                return "The model is receiving too many requests. Wait a moment and try again."
            case .guardrailViolation, .refusal:
                return "The model could not answer this request. Try rephrasing it."
            case .unsupportedLanguageOrLocale:
                return "The selected model does not support this language. Try another language."
            case .timeout:
                return "The model took too long to respond. Try again."
            default:
                return error.localizedDescription
            }
        }
        return error.localizedDescription
    }

    private static func quotaMessage(resetDate: Date?) -> String {
        if let resetDate {
            return "Your Private Cloud Compute limit has been reached. It resets \(resetDate.formatted(date: .abbreviated, time: .shortened)). You can choose on-device AI in Ari Settings."
        }
        return "Your Private Cloud Compute limit has been reached. Try again later or choose on-device AI in Ari Settings."
    }
}

private struct ModelUnavailableError: LocalizedError {
    var message: String
    var errorDescription: String? { message }
}
