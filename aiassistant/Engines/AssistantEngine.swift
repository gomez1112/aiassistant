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
    let ariGuidance: String?
    let ariMood: AriMood?
    let errorMessage: String?
}

enum AssistantTextResult: Sendable, Equatable {
    case success(String)
    case cancelled
    case failed(String)
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
    private var activeGenerationID: UUID?

    private static let intentKeywords: [(mode: AssistantMode, keywords: [String])] = [
        (.write, ["write", "draft", "compose", "create", "letter", "email", "essay", "blog"]),
        (.summarize, ["summarize", "summary", "tldr", "tl;dr", "shorten", "condense", "gist"]),
        (.explain, ["explain", "what is", "what are", "how does", "why", "define", "meaning"]),
        (.plan, ["plan", "schedule", "outline", "steps", "roadmap", "strategy", "organize"]),
        (.brainstorm, ["brainstorm", "ideas", "suggest", "alternatives", "options", "creative"])
    ]

    #if canImport(FoundationModels)
    private var session: LanguageModelSession?
    #endif

    // MARK: - Intent Classification

    /// Classify user input into an AssistantMode.
    func classifyIntent(_ input: String) -> AssistantMode {
        let lowered = input.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        guard !lowered.isEmpty else { return .general }

        return Self.intentKeywords.first { rule in
            rule.keywords.contains { lowered.contains($0) }
        }?.mode ?? .general
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
        let generationID = UUID()
        activeGenerationID = generationID

        func failure(_ message: String) -> GenerationResult {
            GenerationResult(
                text: "",
                mode: mode,
                ariGuidance: nil,
                ariMood: nil,
                errorMessage: message
            )
        }

        defer {
            if activeGenerationID == generationID {
                activeGenerationID = nil
            }
        }

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-fast-ai") {
            state = .routing
            streamingText = ""
            state = .generating
            let reply = """
            UI test reply for \(mode.chipLabel): this deterministic answer keeps the chat and keyboard flow stable.

            • First concise point
            • Second concise point
            • Final concise point
            """
            state = .complete
            return GenerationResult(
                text: reply,
                mode: mode,
                ariGuidance: nil,
                ariMood: nil,
                errorMessage: nil
            )
        }
        #endif

        if Task.isCancelled {
            state = .idle
            streamingText = ""
            return GenerationResult(
                text: "",
                mode: mode,
                ariGuidance: nil,
                ariMood: nil,
                errorMessage: nil
            )
        }

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
                attachmentContext: attachmentContext,
                generationID: generationID
            )
            if isGenerationCurrent(generationID) {
                state = .complete
                streamingText = ""
            }
            return result
        } catch is CancellationError {
            if activeGenerationID == generationID {
                state = .idle
                streamingText = ""
            }
            return GenerationResult(
                text: "",
                mode: mode,
                ariGuidance: nil,
                ariMood: nil,
                errorMessage: nil
            )
        } catch {
            let errorMessage = error.localizedDescription
            if activeGenerationID == generationID {
                state = .idle
                streamingText = ""
            }
            return failure("Generation failed. \(errorMessage)")
        }
        #else
        state = .complete
        streamingText = ""
        return failure("On-device AI is unavailable on this device right now.")
        #endif
    }

    // MARK: - Transform Content

    /// Transform existing content (rewrite, summarize, bullets, table, quiz, flashcards).
    /// Uses a separate state flag so it doesn't trigger chat UI indicators.
    private(set) var isTransforming = false
    private(set) var isSummarizing = false
    private var activeTransformOperationCount = 0
    private var activeSummaryOperationCount = 0

    func transform(
        content: String,
        type: TransformType,
        preferences: UserPreferences
    ) async -> AssistantTextResult {
        beginTransformOperation()
        defer { endTransformOperation() }

        #if canImport(FoundationModels)
        do {
            let text = try await transformWithFoundationModels(
                content: content,
                type: type,
                preferences: preferences
            )
            return .success(text)
        } catch is CancellationError {
            return .cancelled
        } catch {
            return .failed("Transform failed. \(error.localizedDescription)")
        }
        #else
        return .failed("On-device AI is unavailable on this device right now.")
        #endif
    }

    // MARK: - Summarize Library Item

    func summarizeLibraryItem(text: String) async -> AssistantTextResult {
        beginSummaryOperation()
        defer { endSummaryOperation() }

        #if canImport(FoundationModels)
        do {
            let session = LanguageModelSession()
            let prompt = "Summarize the following text in 2-3 concise sentences:\n\n\(text)"
            let response = try await session.respond(to: prompt)
            return .success(response.content)
        } catch is CancellationError {
            return .cancelled
        } catch {
            return .failed("Summary failed. \(error.localizedDescription)")
        }
        #else
        return .failed("On-device AI is unavailable on this device right now.")
        #endif
    }

    // MARK: - Cancel

    func cancel() {
        activeGenerationID = nil
        state = .idle
        streamingText = ""
        #if canImport(FoundationModels)
        session = nil
        #endif
    }

    private func beginTransformOperation() {
        activeTransformOperationCount += 1
        isTransforming = true
    }

    private func endTransformOperation() {
        activeTransformOperationCount = max(0, activeTransformOperationCount - 1)
        isTransforming = activeTransformOperationCount > 0
    }

    private func beginSummaryOperation() {
        activeSummaryOperationCount += 1
        isSummarizing = true
    }

    private func endSummaryOperation() {
        activeSummaryOperationCount = max(0, activeSummaryOperationCount - 1)
        isSummarizing = activeSummaryOperationCount > 0
    }

    // MARK: - Foundation Models Integration

    #if canImport(FoundationModels)
    private func generateWithFoundationModels(
        systemPrompt: String,
        context: String,
        input: String,
        mode: AssistantMode,
        preferences: UserPreferences,
        attachmentContext: String?,
        generationID: UUID
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
            guard isGenerationCurrent(generationID) else {
                throw CancellationError()
            }
            accumulated = partial.content
            streamingText = accumulated
            state = .streaming(partial: accumulated)
        }

        return GenerationResult(
            text: accumulated,
            mode: mode,
            ariGuidance: nil, // AriEngine handles this separately
            ariMood: nil,
            errorMessage: nil
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

    private func isGenerationCurrent(_ id: UUID) -> Bool {
        activeGenerationID == id && !Task.isCancelled
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

        switch preferences.outputStyle {
        case .prose:
            prompt += "Prefer natural prose paragraphs unless the user asks for another format. "
        case .structured:
            prompt += "Prefer headings and lists when they improve clarity. "
        case .minimal:
            prompt += "Use the shortest useful format with minimal framing. "
        }

        switch mode {
        case .write:
            prompt += "Help the user write, draft, and compose text. Produce polished output. Use short paragraphs and clear section breaks."
        case .summarize:
            prompt += "Summarize the provided content clearly and concisely. Use headings and bullet points when useful."
        case .explain:
            prompt += "Explain the topic clearly, using analogies when helpful. Use short paragraphs and readable structure."
        case .plan:
            prompt += "Create structured plans with clear phases and actionable tasks. Always use numbered lists with one item per line."
        case .brainstorm:
            prompt += "Generate creative ideas and alternatives. Be exploratory. Present ideas as bullet points with concise phrasing."
        case .general:
            prompt += "Help with whatever the user needs. Be clear and supportive."
        }

        prompt += " Format output for readability: include line breaks between sections, and never collapse lists into one paragraph."

        return prompt
    }

    private func buildConversationContext(history: [Message]) -> String {
        let recent = history.suffix(10)
        return recent.compactMap { msg in
            let role: String
            switch msg.role {
            case .user:
                role = "User"
            case .assistant:
                role = "Assistant"
            case .system, .tool, .unknown:
                return nil
            }
            return "\(role): \(Self.promptSnippet(from: msg.text))"
        }
        .joined(separator: "\n\n")
    }

    private static func promptSnippet(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 4_000 else { return trimmed }
        return String(trimmed.prefix(4_000)) + "\n[Earlier message truncated.]"
    }

}
