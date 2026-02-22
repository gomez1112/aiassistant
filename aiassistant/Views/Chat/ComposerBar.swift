// Views/Chat/ComposerBar.swift
// ai.assistant
//
// Bottom composer bar with text field, send button, and cancel for active generation.

import SwiftUI

struct ComposerBar: View {
    @Binding var text: String
    let isGenerating: Bool
    let isImportingAttachment: Bool
    let hasAttachment: Bool
    let assistantName: String
    let onSend: () -> Void
    let onCancel: () -> Void
    let onAttach: () -> Void

    @FocusState private var isFocused: Bool

    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Button(action: onAttach) {
                Image(systemName: "paperclip")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        isImportingAttachment
                            ? AnyShapeStyle(.tertiary)
                            : AnyShapeStyle(AppTheme.accent)
                    )
                    .frame(width: 42, height: 42)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .stroke(AppTheme.surfaceStrokeStrong, lineWidth: 0.7)
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(isImportingAttachment || isGenerating)
            .accessibilityLabel("Attach file")

            // Text input
            TextField("Message \(assistantName)…", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(
                                    isFocused
                                        ? AppTheme.highlight.opacity(0.65)
                                        : AppTheme.surfaceStroke,
                                    lineWidth: isFocused ? 1 : 0.5
                                )
                        )
                )
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit {
                    guard !isGenerating, !isImportingAttachment else { return }
                    onSend()
                }
                .disabled(isGenerating || isImportingAttachment)
                .accessibilityLabel("Message input")

            // Send / Stop button
            Group {
                if isGenerating {
                    Button(action: onCancel) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(.red.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Stop generating")
                } else {
                    Button(action: onSend) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(
                                hasText || hasAttachment
                                    ? AnyShapeStyle(.white)
                                    : AnyShapeStyle(.secondary)
                            )
                            .frame(width: 42, height: 42)
                            .background(
                                Circle()
                                    .fill(
                                        hasText || hasAttachment
                                            ? AnyShapeStyle(AppTheme.accentGradient)
                                            : AnyShapeStyle(.ultraThinMaterial)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(AppTheme.surfaceStrokeStrong, lineWidth: 0.7)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasText && !hasAttachment)
                    .accessibilityLabel("Send message")
                }
            }
            .transition(.scale.combined(with: .opacity))
            .animation(.snappy(duration: 0.2), value: isGenerating)
        }
        .padding(.horizontal, AppTheme.spacingLG)
        .padding(.vertical, 10)
        .background(
            Rectangle()
                .fill(Color.clear)
                .overlay(Divider(), alignment: .top)
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: -2)
        )
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

#Preview {
    VStack {
        Spacer()
        ComposerBar(
            text: .constant("Hello"),
            isGenerating: false,
            isImportingAttachment: false,
            hasAttachment: false,
            assistantName: "Assistant",
            onSend: {},
            onCancel: {},
            onAttach: {}
        )
    }
}
