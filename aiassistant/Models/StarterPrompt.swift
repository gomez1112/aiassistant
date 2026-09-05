// Models/StarterPrompt.swift
// ai.assistant
//
// Suggested first messages shown on an empty chat so people can start with one tap.

import Foundation

/// A tappable example request shown on the empty chat screen.
struct StarterPrompt: Identifiable, Hashable, Sendable {
    let title: String
    let systemImage: String
    let mode: AssistantMode
    let message: String

    var id: String { message }

    /// The default set of starter prompts, one per assistant mode that benefits from an example.
    static let defaults: [StarterPrompt] = [
        StarterPrompt(
            title: "Draft an email",
            systemImage: "envelope",
            mode: .write,
            message: "Draft a short, friendly email asking a colleague to review my proposal by Friday."
        ),
        StarterPrompt(
            title: "Explain simply",
            systemImage: "lightbulb",
            mode: .explain,
            message: "Explain how compound interest works using a simple everyday example."
        ),
        StarterPrompt(
            title: "Plan my week",
            systemImage: "calendar",
            mode: .plan,
            message: "Help me plan a focused work week with three priorities and daily checkpoints."
        ),
        StarterPrompt(
            title: "Brainstorm ideas",
            systemImage: "sparkles",
            mode: .brainstorm,
            message: "Brainstorm ten creative names for a weekend hiking club."
        )
    ]
}
