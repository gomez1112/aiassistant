// Models/Artifact.swift
// ai.assistant
//
// SwiftData model for saved outputs (Artifacts).

import Foundation
import SwiftData

/// The kind of artifact produced by the assistant.
enum ArtifactKind: String, Codable, CaseIterable, Identifiable {
    case draft = "Draft"
    case summary = "Summary"
    case checklist = "Checklist"
    case plan = "Plan"
    case quiz = "Quiz"
    case flashcards = "Flashcards"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .draft: "doc.text"
        case .summary: "doc.plaintext"
        case .checklist: "checklist"
        case .plan: "list.bullet.clipboard"
        case .quiz: "questionmark.circle"
        case .flashcards: "rectangle.on.rectangle.angled"
        case .other: "square.stack"
        }
    }
}

/// Transformation types for existing artifacts.
enum TransformType: String, Codable, CaseIterable, Identifiable {
    case shorter = "Shorter"
    case moreFormal = "More Formal"
    case bullets = "Bullets"
    case quiz = "Quiz"
    case flashcards = "Flashcards"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .shorter: "arrow.down.right.and.arrow.up.left"
        case .moreFormal: "textformat"
        case .bullets: "list.bullet"
        case .quiz: "questionmark.circle"
        case .flashcards: "rectangle.on.rectangle.angled"
        }
    }
}

@Model
final class Artifact {
    var id = UUID()
    var kindRaw = ""
    var title = ""
    var content = ""
    var createdAt = Date()
    var updatedAt = Date()
    var tagsRaw = ""
    var sourceThreadID: UUID?
    var sourceMessageID: UUID?

    var kind: ArtifactKind {
        get { ArtifactKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    var tags: [String] {
        get {
            guard !tagsRaw.isEmpty else { return [] }
            return tagsRaw
                .split(separator: "\n")
                .map { String($0) }
        }
        set {
            tagsRaw = newValue.joined(separator: "\n")
        }
    }

    init(
        id: UUID = UUID(),
        kind: ArtifactKind = .other,
        title: String = "",
        content: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        tags: [String] = [],
        sourceThreadID: UUID? = nil,
        sourceMessageID: UUID? = nil
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tagsRaw = tags.joined(separator: "\n")
        self.sourceThreadID = sourceThreadID
        self.sourceMessageID = sourceMessageID
    }
}
