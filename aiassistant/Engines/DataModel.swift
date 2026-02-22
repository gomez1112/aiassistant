// Engines/DataModel.swift
// ai.assistant
//
// Central @Observable state model injected into the SwiftUI environment.
// Coordinates between SwiftData persistence, AssistantEngine, and AriEngine.

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class DataModel {

    // MARK: - Engines

    let assistant = AssistantEngine()
    let ari = AriEngine()

    // MARK: - Active State

    var activeThread: Thread?
    var selectedMode: AssistantMode = .general
    var isOutputStudioPresented = false
    var lastAssistantMessage: Message?

    // MARK: - Thread Management

    func createThread(in context: ModelContext) -> Thread {
        let thread = Thread()
        context.insert(thread)
        activeThread = thread
        return thread
    }

    func deleteThread(_ thread: Thread, in context: ModelContext) {
        if activeThread?.id == thread.id {
            activeThread = nil
        }
        context.delete(thread)
    }

    // MARK: - Message Handling

    func sendMessage(
        text: String,
        attachmentContext: String? = nil,
        in thread: Thread,
        context: ModelContext,
        preferences: UserPreferences
    ) async {
        // 1. Create user message
        let mode = selectedMode == .general
            ? assistant.classifyIntent(text)
            : selectedMode

        let userMessage = Message(
            thread: thread,
            role: .user,
            text: text,
            mode: mode
        )
        context.insert(userMessage)
        thread.updatedAt = .now

        // 2. Update Ari before generation
        ari.update(
            messages: thread.sortedMessages,
            lastMode: mode,
            preferences: preferences
        )

        // 3. Generate response
        let result = await assistant.generate(
            input: text,
            mode: mode,
            conversationHistory: thread.sortedMessages,
            preferences: preferences,
            attachmentContext: attachmentContext
        )

        // 4. Create assistant message
        let assistantMessage = Message(
            thread: thread,
            role: .assistant,
            text: result.text,
            mode: result.mode,
            ariGuidance: preferences.ariEnabled ? ari.guidanceLine : nil,
            ariMood: ari.currentMood
        )
        context.insert(assistantMessage)
        lastAssistantMessage = assistantMessage

        // 5. Update thread title if first exchange
        if (thread.messages?.count ?? 0) <= 2 {
            thread.title = generateThreadTitle(from: text)
        }
        thread.updatedAt = .now

        // 6. Update Ari after generation
        ari.update(
            messages: thread.sortedMessages,
            lastMode: mode,
            preferences: preferences
        )

        try? context.save()
    }

    // MARK: - Artifact Management

    func saveArtifact(
        from suggestion: ArtifactSuggestion,
        message: Message?,
        in context: ModelContext
    ) -> Artifact {
        let artifact = Artifact(
            kind: suggestion.kind,
            title: suggestion.title,
            content: suggestion.content,
            tags: suggestion.tags,
            sourceThreadID: activeThread?.id,
            sourceMessageID: message?.id
        )
        context.insert(artifact)

        if let message {
            var ids = message.artifactIDs
            ids.append(artifact.id)
            message.artifactIDs = ids
        }

        try? context.save()
        return artifact
    }

    func saveArtifact(
        kind: ArtifactKind,
        title: String,
        content: String,
        tags: [String],
        in context: ModelContext
    ) -> Artifact {
        let artifact = Artifact(
            kind: kind,
            title: title,
            content: content,
            tags: tags,
            sourceThreadID: activeThread?.id
        )
        context.insert(artifact)
        try? context.save()
        return artifact
    }

    func transformArtifact(
        _ artifact: Artifact,
        type: TransformType,
        preferences: UserPreferences,
        in context: ModelContext
    ) async -> Artifact {
        let transformed = await assistant.transform(
            content: artifact.content,
            type: type,
            preferences: preferences
        )

        let newKind: ArtifactKind
        switch type {
        case .shorter, .moreFormal: newKind = artifact.kind
        case .bullets: newKind = .checklist
        case .quiz: newKind = .quiz
        case .flashcards: newKind = .flashcards
        }

        let newArtifact = Artifact(
            kind: newKind,
            title: "\(artifact.title) (\(type.rawValue))",
            content: transformed,
            tags: artifact.tags + [type.rawValue.lowercased()],
            sourceThreadID: artifact.sourceThreadID,
            sourceMessageID: artifact.sourceMessageID
        )
        context.insert(newArtifact)
        try? context.save()
        return newArtifact
    }

    // MARK: - Library

    func summarizeItem(
        _ item: LibraryItem,
        in context: ModelContext
    ) async {
        let summary = await assistant.summarizeLibraryItem(text: item.rawText)
        item.aiSummary = summary
        item.updatedAt = .now
        try? context.save()
    }

    // MARK: - Preferences

    func loadOrCreatePreferences(in context: ModelContext) -> UserPreferences {
        let descriptor = FetchDescriptor<UserPreferences>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let prefs = UserPreferences()
        context.insert(prefs)
        try? context.save()
        return prefs
    }

    // MARK: - Helpers

    private func generateThreadTitle(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 40 { return trimmed }
        let words = trimmed.prefix(60).split(separator: " ")
        return words.dropLast().joined(separator: " ") + "…"
    }
}
