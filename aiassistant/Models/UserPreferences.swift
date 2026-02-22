// Models/UserPreferences.swift
// ai.assistant
//
// SwiftData model for Ari settings and assistant defaults.
// Singleton record — fetch or create on first access.

import Foundation
import SwiftData

/// Ari's expressiveness level.
enum AriExpressiveness: String, Codable, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: String { rawValue }

    var numericValue: Double {
        switch self {
        case .low: 0.3
        case .medium: 0.6
        case .high: 1.0
        }
    }
}

/// Ari's preferred vibe.
enum AriVibe: String, Codable, CaseIterable, Identifiable {
    case calm = "Calm"
    case energetic = "Energetic"
    case neutral = "Neutral"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .calm: "🌊"
        case .energetic: "⚡"
        case .neutral: "☁️"
        }
    }
}

/// Output verbosity preference.
enum Verbosity: String, Codable, CaseIterable, Identifiable {
    case concise = "Concise"
    case balanced = "Balanced"
    case detailed = "Detailed"

    var id: String { rawValue }
}

/// Output style preference.
enum OutputStyle: String, Codable, CaseIterable, Identifiable {
    case prose = "Prose"
    case structured = "Structured"
    case minimal = "Minimal"

    var id: String { rawValue }
}

@Model
final class UserPreferences {
    var id = UUID()

    // Ari settings
    var ariEnabled = true
    var ariExpressivenessRaw = ""
    var ariVibeRaw = ""

    // Assistant defaults
    var verbosityRaw = ""
    var outputStyleRaw = ""

    // Computed properties
    var ariExpressiveness: AriExpressiveness {
        get { AriExpressiveness(rawValue: ariExpressivenessRaw) ?? .medium }
        set { ariExpressivenessRaw = newValue.rawValue }
    }

    var ariVibe: AriVibe {
        get { AriVibe(rawValue: ariVibeRaw) ?? .neutral }
        set { ariVibeRaw = newValue.rawValue }
    }

    var verbosity: Verbosity {
        get { Verbosity(rawValue: verbosityRaw) ?? .balanced }
        set { verbosityRaw = newValue.rawValue }
    }

    var outputStyle: OutputStyle {
        get { OutputStyle(rawValue: outputStyleRaw) ?? .structured }
        set { outputStyleRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        ariEnabled: Bool = true,
        ariExpressiveness: AriExpressiveness = .medium,
        ariVibe: AriVibe = .neutral,
        verbosity: Verbosity = .balanced,
        outputStyle: OutputStyle = .structured
    ) {
        self.id = id
        self.ariEnabled = ariEnabled
        self.ariExpressivenessRaw = ariExpressiveness.rawValue
        self.ariVibeRaw = ariVibe.rawValue
        self.verbosityRaw = verbosity.rawValue
        self.outputStyleRaw = outputStyle.rawValue
    }

    /// Default preferences instance.
    static var defaults: UserPreferences { UserPreferences() }
}
