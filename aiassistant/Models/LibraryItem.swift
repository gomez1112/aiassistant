// Models/LibraryItem.swift
// ai.assistant
//
// SwiftData model for user-added source materials.

import Foundation
import SwiftData

/// The kind of library material.
enum LibraryItemKind: String, Codable, CaseIterable, Identifiable {
    case note = "Note"
    case snippet = "Snippet"
    case pasted = "Pasted"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .note: "note.text"
        case .snippet: "text.quote"
        case .pasted: "doc.on.clipboard"
        }
    }
}

@Model
final class LibraryItem {
    var id = UUID()
    var title = ""
    var kindRaw = ""
    var rawText = ""
    var createdAt = Date()
    var updatedAt = Date()
    var aiSummary: String?

    var kind: LibraryItemKind {
        get { LibraryItemKind(rawValue: kindRaw) ?? .note }
        set { kindRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String = "",
        kind: LibraryItemKind = .note,
        rawText: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        aiSummary: String? = nil
    ) {
        self.id = id
        self.title = title
        self.kindRaw = kind.rawValue
        self.rawText = rawText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.aiSummary = aiSummary
    }
}
