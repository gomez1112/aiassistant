// Views/Chat/MessageListView.swift
// ai.assistant
//
// Scrollable list of messages with reliable auto-scroll,
// a jump-to-latest control, lightweight assistant replies, and Ari guidance.

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
        of: #"(?m)^#{1,6}\s+"#,
        with: "",
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
    let onRetry: (Message) -> Void

    @Environment(DataModel.self) private var dataModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrollPosition = ScrollPosition(edge: .bottom)
    @State private var isNearBottom = true
    @State private var lastStreamingScrollDate = Date.distantPast

    /// Distance from the bottom edge (in points) under which the list counts as "caught up".
    private let nearBottomThreshold: CGFloat = 96

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

    private var assistantName: String {
        preferences.ariEnabled ? "Ari" : "Assistant"
    }

    var body: some View {
        let messages = thread.sortedMessages

        ScrollView {
            LazyVStack(spacing: AppTheme.spacingSM) {
                if let first = messages.first {
                    Text(first.createdAt, format: .dateTime.month(.wide).day().year())
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, AppTheme.spacingMD)
                        .padding(.bottom, AppTheme.spacingXS)
                        .accessibilityAddTraits(.isHeader)
                }

                ForEach(messages, id: \.id) { message in
                    MessageBubble(
                        message: message,
                        preferences: preferences,
                        usesCompactActions: usesCompactChrome,
                        onSaveArtifact: { suggestion in
                            onSaveArtifact(message, suggestion)
                        },
                        onOpenOutputStudio: onOpenOutputStudio,
                        onRetry: { onRetry(message) }
                    )
                    .id(message.id)
                    .transition(messageTransition)
                }

                if isChatStreaming {
                    StreamingBubble(
                        text: dataModel.assistant.streamingText,
                        assistantName: assistantName
                    )
                    .id("streaming")
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                }

                if isChatThinking {
                    TypingIndicator(assistantName: assistantName)
                        .id("typing")
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, AppTheme.spacingLG)
            .padding(.bottom, AppTheme.spacingMD)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .defaultScrollAnchor(.bottom)
        .scrollPosition($scrollPosition)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            let visibleBottom = geometry.contentOffset.y + geometry.containerSize.height
            // Container size may or may not include the bottom safe-area inset,
            // so accept either interpretation when deciding whether we're caught up.
            let distanceIncludingInset = geometry.contentSize.height + geometry.contentInsets.bottom - visibleBottom
            let distanceExcludingInset = geometry.contentSize.height - visibleBottom
            return min(distanceIncludingInset, distanceExcludingInset) < nearBottomThreshold
        } action: { _, nearBottom in
            isNearBottom = nearBottom
        }
        .overlay(alignment: .bottom) {
            if !isNearBottom {
                JumpToLatestButton {
                    scrollToBottom(animated: !reduceMotion)
                }
                .padding(.bottom, AppTheme.spacingSM)
                .transition(reduceMotion ? .opacity : .scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: isNearBottom)
        .onAppear {
            scrollToBottom(animated: false)
        }
        .onChange(of: messages.count) { _, _ in
            scrollToBottom(animated: !reduceMotion)
        }
        .onChange(of: dataModel.assistant.streamingText) { _, _ in
            if isChatStreaming, isNearBottom {
                scrollToBottomForStreaming()
            }
        }
        .onChange(of: isGenerating) { _, newValue in
            if newValue {
                scrollToBottom(animated: false)
            }
        }
        .onChange(of: isComposerFocused) { _, newValue in
            if newValue {
                scrollToBottom(animated: !reduceMotion)
            }
        }
        .onChange(of: usesCompactChrome) { _, _ in
            scrollToBottom(animated: !reduceMotion)
        }
        .accessibilityIdentifier("chat.messageList")
    }

    private var messageTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .opacity
            )
    }

    private func scrollToBottom(animated: Bool) {
        if animated {
            withAnimation(.smooth(duration: 0.3)) {
                scrollPosition.scrollTo(edge: .bottom)
            }
        } else {
            scrollPosition.scrollTo(edge: .bottom)
        }
    }

    private func scrollToBottomForStreaming() {
        let now = Date()
        guard now.timeIntervalSince(lastStreamingScrollDate) > 0.35 else { return }
        lastStreamingScrollDate = now
        scrollToBottom(animated: false)
    }
}

// MARK: - Jump To Latest

private struct JumpToLatestButton: View {
    let action: () -> Void

    var body: some View {
        Button("Jump to latest", systemImage: "arrow.down", action: action)
            .labelStyle(.iconOnly)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(width: AppTheme.minimumTapTarget, height: AppTheme.minimumTapTarget)
            .glassEffect(.regular.interactive(), in: .circle)
            .buttonStyle(.plain)
            .accessibilityLabel("Jump to latest message")
            .accessibilityIdentifier("chat.jumpToLatest")
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message
    let preferences: UserPreferences
    let usesCompactActions: Bool
    let onSaveArtifact: (ArtifactSuggestion) -> Void
    let onOpenOutputStudio: (Message) -> Void
    let onRetry: () -> Void

    private var isUser: Bool { message.role == .user }
    private var assistantName: String { preferences.ariEnabled ? "Ari" : "Assistant" }
    private var roleName: String { isUser ? "You" : assistantName }

    var body: some View {
        Group {
            if isUser {
                userMessage
            } else {
                assistantMessage
            }
        }
        .padding(.vertical, AppTheme.spacingXS)
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
        .accessibilityElement(children: .contain)
    }

    // MARK: User

    private var userMessage: some View {
        VStack(alignment: .trailing, spacing: AppTheme.spacingXS) {
            HStack(alignment: .bottom, spacing: 0) {
                Spacer(minLength: 48)

                Text(verbatim: message.text)
                    .font(.body)
                    .lineSpacing(3)
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppTheme.spacingLG)
                    .padding(.vertical, AppTheme.spacingMD)
                    .background(userBubbleShape)
                    .frame(maxWidth: 400, alignment: .trailing)
                    #if os(iOS)
                    .contentShape(.contextMenuPreview, .rect(cornerRadius: AppTheme.radiusBubble))
                    #endif
                    .contextMenu {
                        Button("Copy", systemImage: "doc.on.doc") {
                            Clipboard.copy(message.text)
                        }
                    }
                    .accessibilityLabel("\(roleName) message")
                    .accessibilityValue(accessibilitySummary(for: message.text))
                    .accessibilityIdentifier("chat.message.user")
            }

            if message.status != .completed {
                HStack(spacing: AppTheme.spacingSM) {
                    Label(statusText, systemImage: statusIcon)
                        .font(.caption)
                        .foregroundStyle(statusTint)
                        .accessibilityIdentifier("chat.message.status")

                    if message.status == .failed {
                        Button("Retry", systemImage: "arrow.clockwise", action: onRetry)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("chat.message.retry")
                    }
                }
                .padding(.horizontal, AppTheme.spacingXS)
            }
        }
    }

    private var userBubbleShape: some View {
        RoundedRectangle(cornerRadius: AppTheme.radiusBubble, style: .continuous)
            .fill(AppTheme.brandGradient)
    }

    // MARK: Assistant

    private var assistantMessage: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            AssistantNameLabel(name: assistantName)

            Text(verbatim: normalizedDisplayText(message.text))
                .font(.body)
                .lineSpacing(4)
                .foregroundStyle(.primary)
                .frame(maxWidth: 680, alignment: .leading)
                .textSelection(.enabled)
                .contextMenu {
                    Button("Copy", systemImage: "doc.on.doc") {
                        Clipboard.copy(message.text)
                    }
                    Button("Save as Output", systemImage: "square.and.arrow.down") {
                        onSaveArtifact(savedSuggestion)
                    }
                    Button("Transform", systemImage: "wand.and.stars") {
                        onOpenOutputStudio(message)
                    }
                }
                .accessibilityLabel("\(roleName) message")
                .accessibilityValue(accessibilitySummary(for: message.text))
                .accessibilityIdentifier("chat.message.assistant")

            if let guidance = message.ariGuidance, preferences.ariEnabled {
                AriGuidanceLine(text: guidance, mood: message.ariMood ?? .calm)
            }

            OutputCardView(
                message: message,
                usesCompactActions: usesCompactActions,
                onSave: { onSaveArtifact(savedSuggestion) },
                onCopy: { Clipboard.copy(message.text) },
                onTransform: { onOpenOutputStudio(message) }
            )
        }
        .padding(.trailing, AppTheme.spacingLG)
    }

    private var savedSuggestion: ArtifactSuggestion {
        ArtifactSuggestion(
            kind: artifactKind(for: message.mode),
            title: "Saved from chat",
            content: message.text,
            tags: message.mode.map { [$0.rawValue.lowercased()] } ?? []
        )
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
        let time = message.createdAt.formatted(date: .omitted, time: .shortened)
        switch message.status {
        case .completed:
            return "\(summary). Sent \(time)."
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
}

// MARK: - Assistant Name Label

private struct AssistantNameLabel: View {
    let name: String

    var body: some View {
        Label(name, systemImage: "sparkle")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.accent)
            .accessibilityHidden(true)
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
        HStack(spacing: AppTheme.spacingXS) {
            MessageActionButton(
                title: copiedFeedback ? "Copied" : "Copy",
                systemImage: copiedFeedback ? "checkmark" : "doc.on.doc",
                identifier: "chat.messageActions.copy",
                action: copy
            )

            MessageActionButton(
                title: "Save",
                systemImage: "square.and.arrow.down",
                identifier: "chat.messageActions.save",
                action: onSave
            )

            if usesCompactActions {
                Menu {
                    Button(copiedFeedback ? "Copied" : "Copy", systemImage: "doc.on.doc", action: copy)
                        .accessibilityIdentifier("chat.messageActions.copy")
                    Button("Save", systemImage: "square.and.arrow.down", action: onSave)
                        .accessibilityIdentifier("chat.messageActions.save")
                    Button("Transform", systemImage: "wand.and.stars", action: onTransform)
                        .accessibilityIdentifier("chat.messageActions.transform")
                } label: {
                    Label("Message actions", systemImage: "ellipsis")
                        .labelStyle(.iconOnly)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: AppTheme.minimumTapTarget, height: AppTheme.minimumTapTarget)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Message actions")
                .accessibilityIdentifier("chat.messageActions.menu")
            } else {
                MessageActionButton(
                    title: "Transform",
                    systemImage: "wand.and.stars",
                    identifier: "chat.messageActions.transform",
                    action: onTransform
                )
            }
        }
        .padding(.leading, -AppTheme.spacingMD)
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

/// Small icon-only action beneath an assistant reply.
private struct MessageActionButton: View {
    let title: String
    let systemImage: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(title, systemImage: systemImage, action: action)
            .labelStyle(.iconOnly)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: AppTheme.minimumTapTarget, height: AppTheme.minimumTapTarget)
            .contentShape(.circle)
            .buttonStyle(.plain)
            .contentTransition(.symbolEffect(.replace))
            .accessibilityLabel(title)
            .accessibilityIdentifier(identifier)
    }
}

/// Compact tappable pill for inline actions.
struct ActionPill: View {
    let icon: String
    let label: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(label, systemImage: icon, action: action)
            .font(.caption.weight(.medium))
            .padding(.horizontal, AppTheme.spacingMD)
            .padding(.vertical, AppTheme.spacingSM)
            .frame(minHeight: AppTheme.minimumTapTarget)
            .background(AppTheme.surfaceFill, in: .capsule)
            .overlay(Capsule(style: .continuous).stroke(AppTheme.surfaceStroke, lineWidth: 0.5))
            .foregroundStyle(AppTheme.accent)
            .buttonStyle(.plain)
            .accessibilityIdentifier(identifier)
    }
}

// MARK: - Ari Guidance Line

struct AriGuidanceLine: View {
    let text: String
    let mood: AriMood

    var body: some View {
        Label {
            Text(text)
                .font(.footnote)
                .italic()
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: mood.icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(mood.color)
        }
        .accessibilityLabel("Ari says: \(text)")
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Streaming Bubble

struct StreamingBubble: View {
    let text: String
    let assistantName: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            AssistantNameLabel(name: assistantName)

            Text(verbatim: normalizedDisplayText(text.isEmpty ? " " : text))
                .font(.body)
                .lineSpacing(4)
                .foregroundStyle(.primary)
                .frame(maxWidth: 680, alignment: .leading)
        }
        .padding(.trailing, AppTheme.spacingLG)
        .padding(.vertical, AppTheme.spacingXS)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(assistantName) is responding")
        .accessibilityValue("Response in progress")
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    let assistantName: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            AssistantNameLabel(name: assistantName)

            LLMTypingDots()
                .padding(.vertical, AppTheme.spacingXS)
        }
        .padding(.vertical, AppTheme.spacingXS)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
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
