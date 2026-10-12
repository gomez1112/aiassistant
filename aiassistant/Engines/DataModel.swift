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

    let assistant: AssistantEngine
    let ari = AriEngine()
    let review = ReviewController()

    init(settings: AssistantModelSettings = AssistantModelSettings()) {
        assistant = AssistantEngine(settings: settings)
    }

    // MARK: - Active State

    var activeThread: Thread?
    var selectedMode: AssistantMode = .general
    var lastAssistantMessage: Message?
    var persistenceErrorMessage: String?

    // MARK: - Thread Management

    func createThread(in context: ModelContext) -> Thread {
        let thread = Thread()
        context.insert(thread)
        activeThread = thread
        saveContext(context, source: "createThread")
        return thread
    }

    /// Starts a fresh conversation, reusing the active thread when it has no messages yet
    /// so the thread list does not fill up with empty chats.
    @discardableResult
    func startNewThread(in context: ModelContext) -> Thread {
        if let activeThread, activeThread.sortedMessages.isEmpty {
            return activeThread
        }
        return createThread(in: context)
    }

    func deleteThread(_ thread: Thread, in context: ModelContext) {
        if activeThread?.id == thread.id {
            activeThread = nil
        }
        // Clear dangling reference if the last assistant message belongs to this thread
        if let lastMsg = lastAssistantMessage,
           lastMsg.thread?.id == thread.id {
            lastAssistantMessage = nil
        }
        clearArtifactSources(for: thread, in: context)
        context.delete(thread)
        saveContext(context, source: "deleteThread")
    }

    // MARK: - Message Handling

    func sendMessage(
        text: String,
        attachmentContext: String? = nil,
        in thread: Thread,
        context: ModelContext,
        preferences: UserPreferences
    ) async -> AssistantOperationOutcome {
        guard !Task.isCancelled, !thread.isDeleted, thread.modelContext != nil else {
            return .cancelled
        }
        // 1. Classify intent and snapshot history before inserting the new message
        let mode = selectedMode == .general
            ? assistant.classifyIntent(text)
            : selectedMode

        if let availabilityMessage = assistant.foundationModelUnavailableMessage() {
            return .failed(availabilityMessage)
        }

        let historyBeforeSend = thread.sortedMessages

        // 2. Create user message
        let userMessage = Message(
            thread: thread,
            role: .user,
            text: text,
            mode: mode,
            status: .pending
        )
        context.insert(userMessage)
        thread.updatedAt = .now
        guard saveContext(context, source: "sendMessage.pending") else {
            context.delete(userMessage)
            return .failed(persistenceErrorMessage ?? "Could not save your message.")
        }

        // 3. Update Ari before generation
        let messagesAfterUserInsert = thread.sortedMessages
        ari.update(
            messages: messagesAfterUserInsert,
            lastMode: mode,
            preferences: preferences
        )

        // 4. Generate response (use pre-insert history to avoid duplicating
        //    the user message in the prompt — the engine appends it separately)
        let result = await assistant.generate(
            input: text,
            mode: mode,
            conversationHistory: historyBeforeSend,
            preferences: preferences,
            attachmentContext: attachmentContext
        )

        // A deleted source must never be resurrected by a delayed model response.
        guard !thread.isDeleted, thread.modelContext != nil, !userMessage.isDeleted else {
            return .cancelled
        }
        if Task.isCancelled {
            userMessage.status = .cancelled
            saveContext(context, source: "sendMessage.cancelled")
            return .cancelled
        }

        if let errorMessage = result.errorMessage {
            userMessage.status = .failed
            saveContext(context, source: "sendMessage.failed")
            return .failed(errorMessage)
        }

        // 5. Create assistant message
        let replyText = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !replyText.isEmpty else {
            userMessage.status = .cancelled
            saveContext(context, source: "sendMessage.emptyResult")
            return .cancelled
        }
        let assistantMessage = Message(
            thread: thread,
            role: .assistant,
            text: replyText,
            mode: result.mode,
            ariGuidance: preferences.ariEnabled ? ari.guidanceLine : nil,
            ariMood: ari.currentMood
        )
        context.insert(assistantMessage)
        userMessage.status = .completed
        lastAssistantMessage = assistantMessage

        // 6. Update thread title if first exchange
        if (thread.messages?.count ?? 0) <= 2 {
            thread.title = generateThreadTitle(from: text)
        }
        thread.updatedAt = .now

        // 7. Update Ari after generation
        let messagesAfterAssistantInsert = thread.sortedMessages
        ari.update(
            messages: messagesAfterAssistantInsert,
            lastMode: mode,
            preferences: preferences
        )

        return saveContext(context, source: "sendMessage")
            ? .completed
            : .failed(persistenceErrorMessage ?? "Could not save the reply.")
    }

    // MARK: - Artifact Management

    func saveArtifact(
        from suggestion: ArtifactSuggestion,
        message: Message?,
        in context: ModelContext
    ) -> Artifact {
        if let existing = existingArtifact(for: suggestion, message: message, in: context) {
            link(existing, to: message)
            saveContext(context, source: "saveArtifact.suggestion.existing")
            return existing
        }

        let artifact = Artifact(
            kind: suggestion.kind,
            title: suggestion.title,
            content: suggestion.content,
            tags: suggestion.tags,
            sourceThreadID: message?.thread?.id ?? activeThread?.id,
            sourceMessageID: message?.id
        )
        context.insert(artifact)

        link(artifact, to: message)

        saveContext(context, source: "saveArtifact.suggestion")
        registerReviewMilestone(for: artifact.kind)
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
        saveContext(context, source: "saveArtifact.manual")
        registerReviewMilestone(for: kind)
        return artifact
    }

    func transformArtifact(
        _ artifact: Artifact,
        type: TransformType,
        preferences: UserPreferences,
        in context: ModelContext
    ) async -> ArtifactTransformOutcome {
        let transformed = await assistant.transform(
            content: artifact.content,
            type: type,
            preferences: preferences
        )

        guard !Task.isCancelled, !artifact.isDeleted, artifact.modelContext != nil else {
            return .cancelled
        }

        let transformedText: String
        switch transformed {
        case .success(let text):
            transformedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .cancelled:
            return .cancelled
        case .failed(let message):
            return .failed(message)
        }

        guard !transformedText.isEmpty else {
            return .failed("The transform did not return any content.")
        }

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
            content: transformedText,
            tags: artifact.tags + [type.rawValue.lowercased()],
            sourceThreadID: artifact.sourceThreadID,
            sourceMessageID: artifact.sourceMessageID
        )
        context.insert(newArtifact)
        guard saveContext(context, source: "transformArtifact") else {
            return .failed(persistenceErrorMessage ?? "Could not save the transformed output.")
        }
        registerReviewMilestone(for: newKind)
        return .completed(newArtifact)
    }

    // MARK: - Library

    func summarizeItem(
        _ item: LibraryItem,
        in context: ModelContext
    ) async -> AssistantOperationOutcome {
        let summary = await assistant.summarizeLibraryItem(text: item.rawText)

        guard !Task.isCancelled, !item.isDeleted, item.modelContext != nil else {
            return .cancelled
        }

        let summaryText: String
        switch summary {
        case .success(let text):
            summaryText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .cancelled:
            return .cancelled
        case .failed(let message):
            return .failed(message)
        }

        guard !summaryText.isEmpty else {
            return .failed("The summary did not return any content.")
        }

        item.aiSummary = summaryText
        item.updatedAt = .now
        return saveContext(context, source: "summarizeItem")
            ? .completed
            : .failed(persistenceErrorMessage ?? "Could not save the summary.")
    }

    // MARK: - Preferences

    func loadOrCreatePreferences(in context: ModelContext) -> UserPreferences {
        let descriptor = FetchDescriptor<UserPreferences>()
        do {
            // CloudKit can deliver multiple singleton records. Choose consistently
            // without deleting another device's settings or relying on fetch order.
            if let existing = try context.fetch(descriptor).min(by: { $0.id.uuidString < $1.id.uuidString }) {
                return existing
            }
        } catch {
            persistenceErrorMessage = "Could not load preferences: \(error.localizedDescription)"
            return UserPreferences()
        }
        let prefs = UserPreferences()
        context.insert(prefs)
        saveContext(context, source: "loadOrCreatePreferences")
        return prefs
    }

    // MARK: - Helpers

    @discardableResult
    func saveChanges(in context: ModelContext, source: String) -> Bool {
        saveContext(context, source: source)
    }

    /// Surfaces a review prompt after the user creates a study aid — a quiz or
    /// flashcard deck — which is a natural moment of realized value.
    private func registerReviewMilestone(for kind: ArtifactKind) {
        guard kind == .quiz || kind == .flashcards else { return }
        review.registerStudyArtifactCreated()
    }

    private func generateThreadTitle(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 40 { return trimmed }
        let words = trimmed.prefix(60).split(separator: " ")
        if words.count > 1 {
            return words.dropLast().joined(separator: " ") + "…"
        }
        return String(trimmed.prefix(40)) + "…"
    }

    private func clearArtifactSources(for thread: Thread, in context: ModelContext) {
        let threadID = thread.id
        let descriptor = FetchDescriptor<Artifact>(
            predicate: #Predicate<Artifact> { artifact in
                artifact.sourceThreadID == threadID
            }
        )

        do {
            let artifacts = try context.fetch(descriptor)
            for artifact in artifacts {
                artifact.sourceThreadID = nil
                artifact.sourceMessageID = nil
                artifact.updatedAt = .now
            }
        } catch {
            persistenceErrorMessage = "Could not clear output source links: \(error.localizedDescription)"
        }
    }

    private func existingArtifact(
        for suggestion: ArtifactSuggestion,
        message: Message?,
        in context: ModelContext
    ) -> Artifact? {
        guard let messageID = message?.id else { return nil }
        let kindRaw = suggestion.kind.rawValue
        let content = suggestion.content
        let descriptor = FetchDescriptor<Artifact>(
            predicate: #Predicate<Artifact> { artifact in
                artifact.sourceMessageID == messageID &&
                artifact.kindRaw == kindRaw &&
                artifact.content == content
            },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        return try? context.fetch(descriptor).first
    }

    private func link(_ artifact: Artifact, to message: Message?) {
        guard let message else { return }
        var ids = message.artifactIDs
        if !ids.contains(artifact.id) {
            ids.append(artifact.id)
            message.artifactIDs = ids
        }
    }

    @discardableResult
    private func saveContext(_ context: ModelContext, source: String) -> Bool {
        do {
            try context.save()
            persistenceErrorMessage = nil
            return true
        } catch {
            persistenceErrorMessage = "Save failed (\(source)): \(error.localizedDescription)"
            return false
        }
    }
}

enum AssistantOperationOutcome: Equatable, Sendable {
    case completed
    case cancelled
    case failed(String)
}

enum ArtifactTransformOutcome {
    case completed(Artifact)
    case cancelled
    case failed(String)
}
