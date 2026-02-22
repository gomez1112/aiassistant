// Views/Chat/MessageListView.swift
// ai.assistant
//
// Scrollable list of messages with reliable auto-scroll,
// polished bubbles, output actions, and Ari guidance.

import SwiftUI
import Foundation

private func normalizedDisplayText(_ rawText: String) -> String {
    var text = rawText.replacingOccurrences(of: "\r\n", with: "\n")

    // Ensure punctuation is followed by a space when missing (e.g. "Title:Body").
    text = text.replacingOccurrences(
        of: #"([,:;.!?])(\S)"#,
        with: "$1 $2",
        options: .regularExpression
    )

    // Break numbered lists into separate lines when the model returns a single block.
    text = text.replacingOccurrences(
        of: #"(?<!^)(?<!\n)\s*(\d+\.)\s+"#,
        with: "\n\n$1 ",
        options: .regularExpression
    )

    return text
}

struct MessageListView: View {
    let thread: Thread
    let preferences: UserPreferences
    let isGenerating: Bool
    let onSaveArtifact: (Message, ArtifactSuggestion) -> Void
    let onOpenOutputStudio: () -> Void

    @Environment(DataModel.self) private var dataModel
    private let bottomID = "bottom_anchor"

    /// Whether the engine is actively streaming a chat response.
    private var isChatStreaming: Bool {
        guard isGenerating else { return false }
        if case .streaming = dataModel.assistant.state { return true }
        return false
    }

    /// Whether the engine is in the pre-stream "thinking" phase for a chat.
    private var isChatThinking: Bool {
        guard isGenerating else { return false }
        switch dataModel.assistant.state {
        case .routing, .generating: return true
        default: return false
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    // Date header
                    if let first = thread.sortedMessages.first {
                        Text(first.createdAt, format: .dateTime.month(.wide).day().year())
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 12)
                            .padding(.bottom, 4)
                    }

                    ForEach(thread.sortedMessages, id: \.id) { message in
                        MessageBubble(
                            message: message,
                            preferences: preferences,
                            onSaveArtifact: { suggestion in
                                onSaveArtifact(message, suggestion)
                            },
                            onOpenOutputStudio: onOpenOutputStudio
                        )
                        .id(message.id)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }

                    // Streaming bubble — only during active chat generation
                    if isChatStreaming {
                        StreamingBubble(
                            text: dataModel.assistant.streamingText,
                            assistantName: preferences.ariEnabled ? "Ari" : "Assistant"
                        )
                            .id("streaming")
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Typing indicator — only during active chat generation
                    if isChatThinking {
                        TypingIndicator(assistantName: preferences.ariEnabled ? "Ari" : "Assistant")
                            .id("typing")
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Bottom anchor
                    Color.clear
                        .frame(height: 4)
                        .id(bottomID)
                }
                .padding(.horizontal, AppTheme.spacingLG)
                .padding(.bottom, AppTheme.spacingSM)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            .onAppear {
                scrollToBottom(proxy, animated: false)
            }
            .onChange(of: thread.sortedMessages.count) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: dataModel.assistant.streamingText) { _, _ in
                if isChatStreaming {
                    scrollToBottom(proxy, animated: false)
                }
            }
            .onChange(of: isGenerating) { _, newValue in
                if newValue {
                    scrollToBottom(proxy, animated: false)
                }
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(bottomID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(bottomID, anchor: .bottom)
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message
    let preferences: UserPreferences
    let onSaveArtifact: (ArtifactSuggestion) -> Void
    let onOpenOutputStudio: () -> Void

    private var isUser: Bool { message.role == .user }

    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
            // Ari guidance above assistant message
            if let guidance = message.ariGuidance,
               preferences.ariEnabled,
               !isUser {
                AriGuidanceLine(
                    text: guidance,
                    mood: message.ariMood ?? .calm
                )
                .padding(.bottom, 2)
            }

            // Role label
            if !isUser {
                Text(preferences.ariEnabled ? "Ari" : "Assistant")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.accent.opacity(0.8))
                    .padding(.leading, 4)
            }

            // Bubble
            HStack(alignment: .bottom, spacing: 0) {
                if isUser { Spacer(minLength: 48) }

                messageText(message.text)
                    .font(.body)
                    .lineSpacing(3)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleShape)
                    .foregroundStyle(isUser ? .white : .primary)
                    #if os(iOS)
                    .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: AppTheme.radiusBubble, style: .continuous))
                    #endif
                    .contextMenu {
                        Button {
                            Clipboard.copy(message.text)
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        if !isUser {
                            Button {
                                onOpenOutputStudio()
                            } label: {
                                Label("Transform", systemImage: "wand.and.stars")
                            }
                            Button {
                                onSaveArtifact(ArtifactSuggestion(
                                    kind: artifactKind(for: message.mode),
                                    title: "Saved from chat",
                                    content: message.text,
                                    tags: message.mode.map { [$0.rawValue.lowercased()] } ?? []
                                ))
                            } label: {
                                Label("Save as Artifact", systemImage: "square.and.arrow.down")
                            }
                        }
                    }

                if !isUser { Spacer(minLength: 48) }
            }

            // Inline action bar for assistant messages
            if !isUser {
                OutputCardView(
                    message: message,
                    onSave: {
                        onSaveArtifact(ArtifactSuggestion(
                            kind: artifactKind(for: message.mode),
                            title: "Saved from chat",
                            content: message.text,
                            tags: message.mode.map { [$0.rawValue.lowercased()] } ?? []
                        ))
                    },
                    onCopy: {
                        Clipboard.copy(message.text)
                    },
                    onTransform: onOpenOutputStudio
                )
                .padding(.top, 2)
            }

            // Timestamp
            Text(message.createdAt, format: .dateTime.hour().minute())
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
                .padding(.horizontal, 6)
                .padding(.top, 1)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isUser ? "You" : (preferences.ariEnabled ? "Ari" : "Assistant")): \(message.text)")
    }

    @ViewBuilder
    private var bubbleShape: some View {
        let shape = RoundedRectangle(cornerRadius: AppTheme.radiusBubble, style: .continuous)
        if isUser {
            shape.fill(AppTheme.userBubbleGradient)
                .shadow(color: AppTheme.accent.opacity(0.20), radius: 12, x: 0, y: 4)
        } else {
            shape.fill(.ultraThinMaterial)
                .overlay(shape.stroke(AppTheme.surfaceStroke, lineWidth: 0.5))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
        }
    }

    private func artifactKind(for mode: AssistantMode?) -> ArtifactKind {
        switch mode {
        case .write: .draft
        case .summarize: .summary
        case .plan: .plan
        default: .other
        }
    }

    @ViewBuilder
    private func messageText(_ rawText: String) -> some View {
        let displayText = normalizedDisplayText(rawText)
        if let attributed = try? AttributedString(
            markdown: displayText,
            options: .init(
                interpretedSyntax: .full,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        ) {
            Text(attributed)
        } else {
            Text(.init(displayText))
        }
    }
}

// MARK: - Output Card

struct OutputCardView: View {
    let message: Message
    let onSave: () -> Void
    let onCopy: () -> Void
    let onTransform: () -> Void

    @State private var copiedFeedback = false

    var body: some View {
        HStack(spacing: 6) {
            ActionPill(icon: "doc.on.doc", label: copiedFeedback ? "Copied" : "Copy") {
                onCopy()
                copiedFeedback = true
                Task {
                    try? await Task.sleep(for: .seconds(1.2))
                    copiedFeedback = false
                }
            }

            ActionPill(icon: "square.and.arrow.down", label: "Save to Outputs", action: onSave)

            ActionPill(icon: "wand.and.stars", label: "Transform", action: onTransform)
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: copiedFeedback)
    }
}

/// Compact tappable pill for inline actions.
struct ActionPill: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(AppTheme.surface)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(AppTheme.surfaceStroke, lineWidth: 0.5)
                )
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ari Guidance Line

struct AriGuidanceLine: View {
    let text: String
    let mood: AriMood

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: mood.icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(mood.color)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .italic()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Capsule(style: .continuous).stroke(AppTheme.surfaceStroke, lineWidth: 0.5))
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Streaming Bubble

struct StreamingBubble: View {
    let text: String
    let assistantName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(assistantName)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.accent.opacity(0.8))
                .padding(.leading, 4)

            HStack(alignment: .bottom) {
                Text(text.isEmpty ? " " : text)
                    .hidden()
                    .overlay(alignment: .leading) {
                        messageText(text.isEmpty ? " " : text)
                            .font(.body)
                            .lineSpacing(3)
                    }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.radiusBubble, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.radiusBubble, style: .continuous)
                                .stroke(AppTheme.surfaceStroke, lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
                )

                Spacer(minLength: 48)
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("\(assistantName) is responding: \(text)")
    }

    @ViewBuilder
    private func messageText(_ rawText: String) -> some View {
        let displayText = normalizedDisplayText(rawText)
        if let attributed = try? AttributedString(
            markdown: displayText,
            options: .init(
                interpretedSyntax: .full,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        ) {
            Text(attributed)
        } else {
            Text(.init(displayText))
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    let assistantName: String

    var body: some View {
        HStack {
            LLMTypingDots()
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusBubble, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusBubble, style: .continuous)
                            .stroke(AppTheme.surfaceStroke, lineWidth: 0.5)
                    )
            )
            Spacer()
        }
        .padding(.vertical, 6)
        .accessibilityLabel("\(assistantName) is thinking")
    }
}

private struct LLMTypingDots: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.24, paused: false)) { context in
            let step = Int(context.date.timeIntervalSinceReferenceDate / 0.24) % 3

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(AppTheme.accent.opacity(0.75))
                        .frame(width: 7, height: 7)
                        .opacity(opacity(for: index, activeStep: step))
                }
            }
        }
    }

    private func opacity(for index: Int, activeStep: Int) -> Double {
        if index == activeStep { return 0.95 }
        if index == (activeStep + 2) % 3 { return 0.55 }
        return 0.22
    }
}
