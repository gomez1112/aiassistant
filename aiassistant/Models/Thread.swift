// Models/Thread.swift
// ai.assistant
//
// SwiftData model for conversation threads.
// CloudKit-compatible: no unique constraints, optional inverse relationships.

import Foundation
import SwiftData

@Model
final class Thread {
    var id = UUID()
    var title = ""
    var createdAt = Date()
    var updatedAt = Date()
    var pinned = false

    @Relationship(deleteRule: .cascade, inverse: \Message.thread)
    var messages: [Message]?

    init(
        id: UUID = UUID(),
        title: String = "New Chat",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        pinned: Bool = false,
        messages: [Message]? = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.pinned = pinned
        self.messages = messages
    }

    var sortedMessages: [Message] {
        (messages ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    var lastMessagePreview: String {
        sortedMessages.last?.text.prefix(80).description ?? "No messages yet"
    }
}
