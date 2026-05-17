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
                Label("Attach file", systemImage: "paperclip")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        isImportingAttachment
                            ? AnyShapeStyle(.tertiary)
                            : AnyShapeStyle(AppTheme.accent)
                    )
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(AppTheme.surfaceFill)
                            .overlay(
                                Circle()
                                    .stroke(AppTheme.surfaceStrokeStrong, lineWidth: 0.7)
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(isImportingAttachment || isGenerating)

            // Text input
            TextField("Ask \(assistantName)…", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(AppTheme.surfaceFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
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
                        Label("Stop generating", systemImage: "stop.circle.fill")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(AppTheme.destructive))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: onSend) {
                        Label("Send message", systemImage: "arrow.up")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(
                                hasText || hasAttachment
                                    ? AnyShapeStyle(.white)
                                    : AnyShapeStyle(.secondary)
                            )
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(
                                        hasText || hasAttachment
                                            ? AnyShapeStyle(AppTheme.accent)
                                            : AnyShapeStyle(AppTheme.surfaceFill)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(AppTheme.surfaceStrokeStrong, lineWidth: 0.7)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasText && !hasAttachment)
                }
            }
            .transition(.scale.combined(with: .opacity))
            .animation(.snappy(duration: 0.2), value: isGenerating)
        }
        .padding(.horizontal, AppTheme.spacingLG)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            Rectangle()
                .fill(AppTheme.groupedBackground.opacity(0.92))
                .overlay(Divider().opacity(0.7), alignment: .top)
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
