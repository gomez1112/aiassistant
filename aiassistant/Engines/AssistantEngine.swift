// Engines/AssistantEngine.swift
// ai.assistant
//
// Orchestrates user intent routing, Foundation Models calls,
// streaming responses, and artifact generation.
//
// Uses Apple Foundation Models (iOS 26+) for on-device inference.
// Falls back gracefully when the model is unavailable (Simulator, etc.).

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Engine State

enum EngineState: Sendable {
    case idle
    case routing
    case generating
    case streaming(partial: String)
    case complete
    case error(String)
}

// MARK: - Generation Result

struct GenerationResult: Sendable {
    let text: String
    let mode: AssistantMode
    let suggestedArtifact: ArtifactSuggestion?
    let ariGuidance: String?
    let ariMood: AriMood?
}

struct ArtifactSuggestion: Sendable {
    let kind: ArtifactKind
    let title: String
    let content: String
    let tags: [String]
}

// MARK: - AssistantEngine

@MainActor
@Observable
final class AssistantEngine {

    var state: EngineState = .idle
    var streamingText: String = ""

    private var currentTask: Task<Void, Never>?

    #if canImport(FoundationModels)
    private var session: LanguageModelSession?
    #endif

    // MARK: - Intent Classification

    /// Classify user input into an AssistantMode.
    func classifyIntent(_ input: String) -> AssistantMode {
        let lowered = input.lowercased()

        // Keyword-based routing
        let writeKeywords = ["write", "draft", "compose", "create", "letter", "email", "essay", "blog"]
        let summarizeKeywords = ["summarize", "summary", "tldr", "tl;dr", "shorten", "condense", "gist"]
        let explainKeywords = ["explain", "what is", "what are", "how does", "why", "define", "meaning"]
        let planKeywords = ["plan", "schedule", "outline", "steps", "roadmap", "strategy", "organize"]
        let brainstormKeywords = ["brainstorm", "ideas", "suggest", "alternatives", "options", "creative"]

        if writeKeywords.contains(where: { lowered.contains($0) }) { return .write }
        if summarizeKeywords.contains(where: { lowered.contains($0) }) { return .summarize }
        if explainKeywords.contains(where: { lowered.contains($0) }) { return .explain }
        if planKeywords.contains(where: { lowered.contains($0) }) { return .plan }
        if brainstormKeywords.contains(where: { lowered.contains($0) }) { return .brainstorm }

        return .general
    }

    // MARK: - Generate Response

    /// Generate a response for the given user input and context.
    func generate(
        input: String,
        mode: AssistantMode,
        conversationHistory: [Message],
        preferences: UserPreferences,
        attachmentContext: String? = nil
    ) async -> GenerationResult {
        state = .routing
        streamingText = ""

        let systemPrompt = buildSystemPrompt(mode: mode, preferences: preferences)
        let conversationContext = buildConversationContext(history: conversationHistory)

        state = .generating

        #if canImport(FoundationModels)
        do {
            let result = try await generateWithFoundationModels(
                systemPrompt: systemPrompt,
                context: conversationContext,
                input: input,
                mode: mode,
                preferences: preferences,
                attachmentContext: attachmentContext
            )
            state = .idle
            streamingText = ""
            return result
        } catch {
            let errorMessage = error.localizedDescription
            state = .idle
            streamingText = ""
            return GenerationResult(
                text: "Generation failed: \(errorMessage)",
                mode: mode,
                suggestedArtifact: nil,
                ariGuidance: nil,
                ariMood: nil
            )
        }
        #else
        fatalError("Foundation Models is required on iOS 26+.")
        #endif
    }

    // MARK: - Transform Content

    /// Transform existing content (rewrite, summarize, bullets, table, quiz, flashcards).
    /// Uses a separate state flag so it doesn't trigger chat UI indicators.
    private(set) var isTransforming = false

    func transform(
        content: String,
        type: TransformType,
        preferences: UserPreferences
    ) async -> String {
        isTransforming = true
        defer { isTransforming = false }

        #if canImport(FoundationModels)
        do {
            return try await transformWithFoundationModels(
                content: content,
                type: type,
                preferences: preferences
            )
        } catch {
            return "Transform failed: \(error.localizedDescription)"
        }
        #else
        fatalError("Foundation Models is required on iOS 26+.")
        #endif
    }

    // MARK: - Summarize Library Item

    func summarizeLibraryItem(text: String) async -> String {
        isTransforming = true
        defer { isTransforming = false }

        #if canImport(FoundationModels)
        do {
            let session = LanguageModelSession()
            let prompt = "Summarize the following text in 2-3 concise sentences:\n\n\(text)"
            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            return "Summary failed: \(error.localizedDescription)"
        }
        #else
        fatalError("Foundation Models is required on iOS 26+.")
        #endif
    }

    // MARK: - Cancel

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        state = .idle
        streamingText = ""
    }

    // MARK: - Foundation Models Integration

    #if canImport(FoundationModels)
    private func generateWithFoundationModels(
        systemPrompt: String,
        context: String,
        input: String,
        mode: AssistantMode,
        preferences: UserPreferences,
        attachmentContext: String?
    ) async throws -> GenerationResult {
        let session = LanguageModelSession(
            instructions: systemPrompt
        )
        self.session = session

        var promptParts: [String] = []
        if !context.isEmpty {
            promptParts.append(context)
        }
        if let attachmentContext, !attachmentContext.isEmpty {
            promptParts.append("Attached file content:\n\(attachmentContext)")
        }
        promptParts.append("User: \(input)")
        let fullPrompt = promptParts.joined(separator: "\n\n")

        // Stream the response
        var accumulated = ""
        let stream = session.streamResponse(to: fullPrompt)

        for try await partial in stream {
            accumulated = partial.content
            streamingText = accumulated
            state = .streaming(partial: accumulated)
        }

        let artifact = suggestArtifact(from: accumulated, mode: mode)

        return GenerationResult(
            text: accumulated,
            mode: mode,
            suggestedArtifact: artifact,
            ariGuidance: nil, // AriEngine handles this separately
            ariMood: nil
        )
    }

    private func transformWithFoundationModels(
        content: String,
        type: TransformType,
        preferences: UserPreferences
    ) async throws -> String {
        let session = LanguageModelSession(
            instructions: "You are a content transformation assistant. Transform the given content as requested. Output only the transformed content."
        )

        let prompt: String
        switch type {
        case .shorter:
            prompt = "Make this shorter and more concise:\n\n\(content)"
        case .moreFormal:
            prompt = "Rewrite this in a more formal, professional tone:\n\n\(content)"
        case .bullets:
            prompt = """
            Convert this into a clear bulleted list. Use "• " (bullet + space) \
            to start each point. Keep each point on one line. \
            Group related points under section headers prefixed with "## ". \
            Content:

            \(content)
            """
        case .quiz:
            prompt = """
            Create a 5-question multiple choice quiz from this content. \
            Format EXACTLY like this, with each question separated by a blank line:

            Q: [question text]
            A) [option text]
            B) [option text]
            C) [option text]
            D) [option text]
            Correct: [letter]

            Q: [question text]
            A) [option text]
            B) [option text]
            C) [option text]
            D) [option text]
            Correct: [letter]

            Content:

            \(content)
            """
        case .flashcards:
            prompt = """
            Create 5-10 flashcards from this content. \
            Format EXACTLY like this, with each card separated by a blank line:

            Q: [question or front of card]
            A: [answer or back of card]

            Q: [question or front of card]
            A: [answer or back of card]

            Content:

            \(content)
            """
        }

        let response = try await session.respond(to: prompt)
        return response.content
    }
    #endif

    // MARK: - Artifact Suggestion

    private func suggestArtifact(from response: String, mode: AssistantMode) -> ArtifactSuggestion? {
        switch mode {
        case .write:
            return ArtifactSuggestion(
                kind: .draft,
                title: "Draft",
                content: response,
                tags: ["draft", "writing"]
            )
        case .summarize:
            return ArtifactSuggestion(
                kind: .summary,
                title: "Summary",
                content: response,
                tags: ["summary"]
            )
        case .plan:
            return ArtifactSuggestion(
                kind: .plan,
                title: "Plan",
                content: response,
                tags: ["plan", "tasks"]
            )
        case .explain, .brainstorm, .general:
            return nil
        }
    }

    // MARK: - System Prompt Builder

    private func buildSystemPrompt(mode: AssistantMode, preferences: UserPreferences) -> String {
        let assistantIdentity = preferences.ariEnabled
            ? "You are Ari, a warm and supportive assistant. "
            : "You are a warm and supportive assistant. "
        var prompt = assistantIdentity

        switch preferences.verbosity {
        case .concise: prompt += "Keep responses concise and to the point. "
        case .balanced: prompt += "Provide balanced responses with enough detail to be helpful. "
        case .detailed: prompt += "Provide thorough, detailed responses. "
        }

        switch mode {
        case .write:
            prompt += "Help the user write, draft, and compose text. Produce polished output."
        case .summarize:
            prompt += "Summarize the provided content clearly and concisely."
        case .explain:
            prompt += "Explain the topic clearly, using analogies when helpful."
        case .plan:
            prompt += "Create structured plans with clear phases and actionable tasks."
        case .brainstorm:
            prompt += "Generate creative ideas and alternatives. Be exploratory."
        case .general:
            prompt += "Help with whatever the user needs. Be clear and supportive."
        }

        return prompt
    }

    private func buildConversationContext(history: [Message]) -> String {
        let recent = history.suffix(10)
        return recent.map { msg in
            let role = msg.role == .user ? "User" : "Assistant"
            return "\(role): \(msg.text)"
        }.joined(separator: "\n\n")
    }
}
