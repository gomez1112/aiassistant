import SwiftUI

enum PersistenceMode: Equatable, Sendable {
    case cloudKit
    case localFallback(String)
    case uiTesting
    case recovery(String)

    var isLocalOnly: Bool {
        switch self {
        case .cloudKit:
            false
        case .localFallback, .uiTesting, .recovery:
            true
        }
    }

    var statusLabel: String {
        switch self {
        case .cloudKit:
            "CloudKit sync active"
        case .localFallback:
            "Local storage fallback"
        case .uiTesting:
            "UI test storage"
        case .recovery:
            "Recovery storage"
        }
    }

    var userMessage: String? {
        switch self {
        case .cloudKit:
            nil
        case .uiTesting:
            "UI testing is using an isolated in-memory store."
        case .localFallback:
            "CloudKit sync is unavailable right now, so Ari is saving changes locally on this device."
        case .recovery:
            "Ari could not open its normal data store and is running in recovery mode."
        }
    }

    var diagnosticMessage: String? {
        switch self {
        case .cloudKit, .uiTesting:
            nil
        case .localFallback(let message), .recovery(let message):
            message
        }
    }
}

private struct PersistenceModeKey: EnvironmentKey {
    static let defaultValue: PersistenceMode = .cloudKit
}

extension EnvironmentValues {
    var persistenceMode: PersistenceMode {
        get { self[PersistenceModeKey.self] }
        set { self[PersistenceModeKey.self] = newValue }
    }
}
