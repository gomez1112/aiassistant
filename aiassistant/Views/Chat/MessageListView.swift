// Views/Chat/MessageListView.swift
// ai.assistant
//
// Scrollable list of messages with reliable auto-scroll,
// polished bubbles, output actions, and Ari guidance.

import SwiftUI
import Foundation

func normalizedDisplayText(_ rawText: String) -> String {
    var text = rawText
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")

    text = text.replacingOccurrences(
        of: #"(?m)^\s*[\*\-]\s+"#,
        with: "• ",
        options: .regularExpression
    )

    text = text.replacingOccurrences(
        of: #"\*\*([^*]+)\*\*"#,
        with: "$1",
        options: .regularExpression
    )

    text = text.replacingOccurrences(
        of: #"__([^_]+)__"#,
        with: "$1",
        options: .regularExpression
    )

    return text
}

struct MessageListView: View {
    let thread: Thread
    let preferences: UserPreferences
    let isGenerating: Bool
    let isComposerFocused: Bool
    let usesCompactChrome: Bool
    let onSaveArtifact: (Message, ArtifactSuggestion) -> Void
    let onOpenOutputStudio: (Message) -> Void

    @Environment(DataModel.self) private var dataModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lastStreamingScrollDate = Date.distantPast
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
        let messages = thread.sortedMessages

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    // Date header
                    if let first = messages.first {
                        Text(first.createdAt, format: .dateTime.month(.wide).day().year())
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 12)
                            .padding(.bottom, 4)
                    }

                    ForEach(messages, id: \.id) { message in
                        MessageBubble(
                            message: message,
                            preferences: preferences,
                            usesCompactActions: usesCompactChrome,
                            onSaveArtifact: { suggestion in
                                onSaveArtifact(message, suggestion)
                            },
                            onOpenOutputStudio: onOpenOutputStudio
                        )
                        .id(message.id)
                        .transition(messageTransition)
                    }

                    // Streaming bubble — only during active chat generation
                    if isChatStreaming {
                        StreamingBubble(
                            text: dataModel.assistant.streamingText,
                            assistantName: preferences.ariEnabled ? "Ari" : "Assistant"
                        )
                            .id("streaming")
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Typing indicator — only during active chat generation
                    if isChatThinking {
                        TypingIndicator(assistantName: preferences.ariEnabled ? "Ari" : "Assistant")
                            .id("typing")
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
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
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: dataModel.assistant.streamingText) { _, _ in
                if isChatStreaming {
                    scrollToBottomForStreaming(proxy)
                }
            }
            .onChange(of: isGenerating) { _, newValue in
                if newValue {
                    scrollToBottom(proxy, animated: false)
                }
            }
            .onChange(of: isComposerFocused) { _, newValue in
                if newValue {
                    scrollToBottom(proxy, animated: !reduceMotion)
                }
            }
            .onChange(of: usesCompactChrome) { _, _ in
                scrollToBottom(proxy, animated: !reduceMotion)
            }
            .accessibilityIdentifier("chat.messageList")
        }
    }

    private var messageTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .scale(scale: 0.95).combined(with: .opacity),
                removal: .opacity
            )
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        if animated && !reduceMotion {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(bottomID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(bottomID, anchor: .bottom)
        }
    }

    private func scrollToBottomForStreaming(_ proxy: ScrollViewProxy) {
        let now = Date()
        guard now.timeIntervalSince(lastStreamingScrollDate) > 0.45 else { return }
        lastStreamingScrollDate = now
        scrollToBottom(proxy, animated: false)
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message
    let preferences: UserPreferences
    let usesCompactActions: Bool
    let onSaveArtifact: (ArtifactSuggestion) -> Void
    let onOpenOutputStudio: (Message) -> Void

    private var isUser: Bool { message.role == .user }
    private var roleName: String { isUser ? "You" : (preferences.ariEnabled ? "Ari" : "Assistant") }

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
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.accent.opacity(0.8))
                    .padding(.leading, 4)
            }

            // Bubble
            HStack(alignment: .bottom, spacing: 0) {
                if isUser { Spacer(minLength: 48) }

                messageText(message.text)
                    .font(.body)
                    .lineSpacing(4)
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
                                onOpenOutputStudio(message)
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
                    .accessibilityLabel("\(roleName) message")
                    .accessibilityValue(accessibilitySummary(for: message.text))
                    .accessibilityIdentifier(isUser ? "chat.message.user" : "chat.message.assistant")

                if !isUser { Spacer(minLength: 48) }
            }

            // Inline action bar for assistant messages
            if !isUser {
                OutputCardView(
                    message: message,
                    usesCompactActions: usesCompactActions,
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
                    onTransform: { onOpenOutputStudio(message) }
                )
                .padding(.top, 2)
            }

            // Timestamp
            Text(message.createdAt, format: .dateTime.hour().minute())
                .font(.caption)
                .foregroundStyle(.quaternary)
                .padding(.horizontal, 6)
                .padding(.top, 1)

            if isUser, message.status != .completed {
                Label(statusText, systemImage: statusIcon)
                    .font(.caption)
                    .foregroundStyle(statusTint)
                    .padding(.horizontal, 6)
                    .accessibilityIdentifier("chat.message.status")
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var bubbleShape: some View {
        let shape = RoundedRectangle(cornerRadius: AppTheme.radiusBubble, style: .continuous)
        if isUser {
            shape.fill(AppTheme.brandGradient)
                .shadow(color: AppTheme.accent.opacity(0.22), radius: 8, y: 3)
        } else {
            shape.fill(AppTheme.surfaceFill)
                .overlay(shape.stroke(AppTheme.surfaceStroke, lineWidth: 0.6))
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

    private func accessibilitySummary(for text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = trimmed.count > 180 ? String(trimmed.prefix(180)) + "..." : trimmed
        switch message.status {
        case .completed:
            return summary
        case .cancelled:
            return "\(summary). Reply stopped."
        case .failed:
            return "\(summary). Reply failed."
        }
    }

    private var statusText: String {
        switch message.status {
        case .completed: ""
        case .cancelled: "Reply stopped"
        case .failed: "Reply failed"
        }
    }

    private var statusIcon: String {
        switch message.status {
        case .completed: "checkmark.circle"
        case .cancelled: "stop.circle"
        case .failed: "exclamationmark.triangle"
        }
    }

    private var statusTint: Color {
        switch message.status {
        case .completed: .secondary
        case .cancelled: .secondary
        case .failed: AppTheme.warning
        }
    }

    @ViewBuilder
    private func messageText(_ rawText: String) -> some View {
        let displayText = normalizedDisplayText(rawText)
        Text(verbatim: displayText)
    }
}

// MARK: - Output Card

struct OutputCardView: View {
    let message: Message
    let usesCompactActions: Bool
    let onSave: () -> Void
    let onCopy: () -> Void
    let onTransform: () -> Void

    @State private var copiedFeedback = false

    var body: some View {
        Group {
            if usesCompactActions {
                Menu {
                    Button(action: copy) {
                        Label(copiedFeedback ? "Copied" : "Copy", systemImage: "doc.on.doc")
                    }
                    .accessibilityIdentifier("chat.messageActions.copy")

                    Button(action: onSave) {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .accessibilityIdentifier("chat.messageActions.save")

                    Button(action: onTransform) {
                        Label("Transform", systemImage: "wand.and.stars")
                    }
                    .accessibilityIdentifier("chat.messageActions.transform")
                } label: {
                    Label("Message actions", systemImage: "ellipsis.circle")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .frame(minHeight: AppTheme.minimumTapTarget)
                        .background(AppTheme.surfaceFill, in: Capsule(style: .continuous))
                        .overlay(Capsule(style: .continuous).stroke(AppTheme.surfaceStroke, lineWidth: 0.5))
                        .foregroundStyle(AppTheme.accent)
                }
                .accessibilityIdentifier("chat.messageActions.menu")
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ActionPill(icon: "doc.on.doc", label: copiedFeedback ? "Copied" : "Copy", identifier: "chat.messageActions.copy", action: copy)

                        ActionPill(icon: "square.and.arrow.down", label: "Save", identifier: "chat.messageActions.save", action: onSave)

                        ActionPill(icon: "wand.and.stars", label: "Transform", identifier: "chat.messageActions.transform", action: onTransform)
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: copiedFeedback)
    }

    private func copy() {
        onCopy()
        copiedFeedback = true
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            copiedFeedback = false
        }
    }
}

/// Compact tappable pill for inline actions.
struct ActionPill: View {
    let icon: String
    let label: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(minHeight: AppTheme.minimumTapTarget)
                .background(
                    Capsule(style: .continuous)
                        .fill(AppTheme.surfaceFill)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(AppTheme.surfaceStroke, lineWidth: 0.5)
                )
                .foregroundStyle(AppTheme.accent)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
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
                .fill(AppTheme.surfaceFill)
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
                .font(.caption.bold())
                .foregroundStyle(AppTheme.accent.opacity(0.8))
                .padding(.leading, 4)

            HStack(alignment: .bottom) {
                Text(text.isEmpty ? " " : text)
                    .hidden()
                    .overlay(alignment: .leading) {
                        messageText(text.isEmpty ? " " : text)
                            .font(.body)
                            .lineSpacing(4)
                    }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.radiusBubble, style: .continuous)
                        .fill(AppTheme.surfaceFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.radiusBubble, style: .continuous)
                                .stroke(AppTheme.surfaceStroke, lineWidth: 0.6)
                        )
                )

                Spacer(minLength: 48)
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("\(assistantName) is responding")
        .accessibilityValue(text.isEmpty ? "Response in progress" : "Response in progress")
    }

    @ViewBuilder
    private func messageText(_ rawText: String) -> some View {
        let displayText = normalizedDisplayText(rawText)
        Text(verbatim: displayText)
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
                    .fill(AppTheme.surfaceFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusBubble, style: .continuous)
                            .stroke(AppTheme.surfaceStroke, lineWidth: 0.6)
                    )
            )
            Spacer()
        }
        .padding(.vertical, 6)
        .accessibilityLabel("\(assistantName) is thinking")
    }
}

private struct LLMTypingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.24, paused: reduceMotion)) { context in
            let step = Int(context.date.timeIntervalSinceReferenceDate / 0.24) % 3

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(AppTheme.accent.opacity(0.75))
                        .frame(width: 7, height: 7)
                        .opacity(reduceMotion ? 0.65 : opacity(for: index, activeStep: step))
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
