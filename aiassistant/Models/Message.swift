// Models/Message.swift
// ai.assistant
//
// SwiftData model for individual chat messages.

import Foundation
import SwiftData

/// The role of a message in the conversation.
enum MessageRole: String, Codable, CaseIterable {
    case user
    case assistant
    case system
    case tool
}

/// The detected intent/mode of a user message.
enum AssistantMode: String, Codable, CaseIterable, Identifiable {
    case write = "Write"
    case summarize = "Summarize"
    case explain = "Explain"
    case plan = "Plan"
    case brainstorm = "Brainstorm"
    case general = "General"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .write: "pencil.line"
        case .summarize: "doc.plaintext"
        case .explain: "lightbulb"
        case .plan: "list.bullet.clipboard"
        case .brainstorm: "brain.head.profile"
        case .general: "bubble.left"
        }
    }

    var chipLabel: String { rawValue }
}

@Model
final class Message {
    var id = UUID()
    var thread: Thread?
    var roleRaw = ""
    var text = ""
    var createdAt = Date()
    var modeRaw: String?
    var ariGuidance: String?
    var ariMoodRaw: String?

    // References to artifacts produced by this message
    var artifactIDsRaw = ""

    var role: MessageRole {
        get { MessageRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }

    var mode: AssistantMode? {
        get { modeRaw.flatMap { AssistantMode(rawValue: $0) } }
        set { modeRaw = newValue?.rawValue }
    }

    var ariMood: AriMood? {
        get { ariMoodRaw.flatMap { AriMood(rawValue: $0) } }
        set { ariMoodRaw = newValue?.rawValue }
    }

    var artifactIDs: [UUID] {
        get {
            guard !artifactIDsRaw.isEmpty else { return [] }
            return artifactIDsRaw
                .split(separator: "\n")
                .compactMap { UUID(uuidString: String($0)) }
        }
        set {
            artifactIDsRaw = newValue
                .map(\.uuidString)
                .joined(separator: "\n")
        }
    }

    init(
        id: UUID = UUID(),
        thread: Thread? = nil,
        role: MessageRole = .user,
        text: String = "",
        createdAt: Date = .now,
        mode: AssistantMode? = nil,
        ariGuidance: String? = nil,
        ariMood: AriMood? = nil,
        artifactIDs: [UUID] = []
    ) {
        self.id = id
        self.thread = thread
        self.roleRaw = role.rawValue
        self.text = text
        self.createdAt = createdAt
        self.modeRaw = mode?.rawValue
        self.ariGuidance = ariGuidance
        self.ariMoodRaw = ariMood?.rawValue
        self.artifactIDsRaw = artifactIDs.map(\.uuidString).joined(separator: "\n")
    }
}
