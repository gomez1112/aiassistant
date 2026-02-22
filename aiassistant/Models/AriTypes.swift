// Models/AriTypes.swift
// ai.assistant
//
// Types for the Ari emotional character layer.

import SwiftUI

/// Ari's mood states derived from conversation context.
enum AriMood: String, Codable, CaseIterable, Identifiable {
    case calm
    case encouraging
    case focused
    case celebratory
    case curious
    case supportive

    var id: String { rawValue }

    var label: String {
        switch self {
        case .calm: "Calm"
        case .encouraging: "Encouraging"
        case .focused: "Focused"
        case .celebratory: "Nice work!"
        case .curious: "Curious"
        case .supportive: "Supportive"
        }
    }

    var icon: String {
        switch self {
        case .calm: "leaf"
        case .encouraging: "hand.thumbsup"
        case .focused: "scope"
        case .celebratory: "star"
        case .curious: "questionmark.bubble"
        case .supportive: "heart"
        }
    }

    var color: Color {
        switch self {
        case .calm: .teal
        case .encouraging: .green
        case .focused: .indigo
        case .celebratory: .orange
        case .curious: .purple
        case .supportive: .pink
        }
    }
}

/// A micro-coaching action that Ari can suggest.
struct AriCoachingAction: Identifiable, Sendable {
    let id = UUID()
    let label: String
    let icon: String
    let action: AriActionType
}

/// Types of actions Ari can trigger.
enum AriActionType: Sendable {
    case createChecklist
    case refineTone
    case saveArtifact
    case askFollowUp
    case simplify
}
