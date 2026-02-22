// Engines/ArtifactSchemas.swift
// ai.assistant
//
// Guided-generation schemas for each Artifact kind.
// These Codable structs are used with Foundation Models'
// guided generation to produce structured outputs.

import Foundation

// MARK: - Guided Generation Schemas

/// Schema for a checklist artifact.
/// ```json
/// { "title": "...", "items": [{ "text": "...", "done": false }] }
/// ```
struct ChecklistSchema: Codable, Sendable {
    let title: String
    let items: [ChecklistItem]

    struct ChecklistItem: Codable, Sendable {
        let text: String
        let done: Bool
    }

    func toMarkdown() -> String {
        var md = "# \(title)\n\n"
        for item in items {
            let check = item.done ? "[x]" : "[ ]"
            md += "- \(check) \(item.text)\n"
        }
        return md
    }
}

/// Schema for a plan artifact.
/// ```json
/// { "title": "...", "blocks": [{ "heading": "...", "tasks": ["..."] }] }
/// ```
struct PlanSchema: Codable, Sendable {
    let title: String
    let blocks: [PlanBlock]

    struct PlanBlock: Codable, Sendable {
        let heading: String
        let tasks: [String]
    }

    func toMarkdown() -> String {
        var md = "# \(title)\n\n"
        for block in blocks {
            md += "## \(block.heading)\n\n"
            for task in block.tasks {
                md += "- [ ] \(task)\n"
            }
            md += "\n"
        }
        return md
    }
}

/// Schema for a table artifact.
/// ```json
/// { "title": "...", "columns": ["..."], "rows": [["...", "..."]] }
/// ```
struct TableSchema: Codable, Sendable {
    let title: String
    let columns: [String]
    let rows: [[String]]

    func toMarkdown() -> String {
        var md = "# \(title)\n\n"
        // Header
        md += "| " + columns.joined(separator: " | ") + " |\n"
        md += "| " + columns.map { _ in "---" }.joined(separator: " | ") + " |\n"
        // Rows
        for row in rows {
            let padded = row + Array(repeating: "", count: max(0, columns.count - row.count))
            md += "| " + padded.prefix(columns.count).joined(separator: " | ") + " |\n"
        }
        return md
    }
}

/// Schema for a summary artifact.
/// ```json
/// { "title": "...", "keyPoints": ["..."], "summary": "..." }
/// ```
struct SummarySchema: Codable, Sendable {
    let title: String
    let keyPoints: [String]
    let summary: String

    func toMarkdown() -> String {
        var md = "# \(title)\n\n"
        md += summary + "\n\n"
        if !keyPoints.isEmpty {
            md += "## Key Points\n\n"
            for point in keyPoints {
                md += "- \(point)\n"
            }
        }
        return md
    }
}

/// Schema for a draft/writing artifact.
/// ```json
/// { "title": "...", "body": "...", "tone": "..." }
/// ```
struct DraftSchema: Codable, Sendable {
    let title: String
    let body: String
    let tone: String?

    func toMarkdown() -> String {
        var md = "# \(title)\n\n"
        md += body
        return md
    }
}

/// Schema for a quiz (transformation output).
/// ```json
/// { "title": "...", "questions": [{ "question": "...", "options": ["..."], "answer": 0 }] }
/// ```
struct QuizSchema: Codable, Sendable {
    let title: String
    let questions: [QuizQuestion]

    struct QuizQuestion: Codable, Sendable {
        let question: String
        let options: [String]
        let answer: Int
    }

    func toMarkdown() -> String {
        var md = "# \(title)\n\n"
        for (i, q) in questions.enumerated() {
            md += "### Question \(i + 1)\n\n"
            md += "\(q.question)\n\n"
            for (j, opt) in q.options.enumerated() {
                let letter = ["A", "B", "C", "D", "E"][safe: j] ?? "\(j)"
                md += "- **\(letter).** \(opt)\n"
            }
            md += "\n*Answer: \(["A", "B", "C", "D", "E"][safe: q.answer] ?? "?")*\n\n"
        }
        return md
    }
}

/// Schema for flashcards (transformation output).
/// ```json
/// { "title": "...", "cards": [{ "front": "...", "back": "..." }] }
/// ```
struct FlashcardSchema: Codable, Sendable {
    let title: String
    let cards: [Flashcard]

    struct Flashcard: Codable, Sendable {
        let front: String
        let back: String
    }

    func toMarkdown() -> String {
        var md = "# \(title)\n\n"
        for (i, card) in cards.enumerated() {
            md += "### Card \(i + 1)\n\n"
            md += "**Q:** \(card.front)\n\n"
            md += "**A:** \(card.back)\n\n---\n\n"
        }
        return md
    }
}

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
