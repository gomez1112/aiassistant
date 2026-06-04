// Views/Chat/ComposerBar.swift
// ai.assistant
//
// Bottom composer bar with text field, send button, and cancel for active generation.

import SwiftUI

struct ComposerBar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let isGenerating: Bool
    let isImportingAttachment: Bool
    let hasAttachment: Bool
    let assistantName: String
    let onSend: () -> Void
    let onCancel: () -> Void
    let onAttach: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: AppTheme.spacingSM) {
            Button(action: onAttach) {
                Label("Attach file", systemImage: "paperclip")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        isImportingAttachment
                            ? AnyShapeStyle(.tertiary)
                            : AnyShapeStyle(.primary)
                    )
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .disabled(isImportingAttachment || isGenerating)
            .frame(minWidth: AppTheme.minimumTapTarget, minHeight: AppTheme.minimumTapTarget)
            .accessibilityLabel("Attach file")
            .accessibilityIdentifier("chat.composer.attach")

            // Text input
            TextField("Ask \(assistantName)…", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .padding(.vertical, 10)
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit {
                    guard !isGenerating, !isImportingAttachment else { return }
                    onSend()
                }
                .disabled(isGenerating || isImportingAttachment)
                .accessibilityLabel("Message input")
                .accessibilityIdentifier("chat.composer.input")

            // Send / Stop button
            Group {
                if isGenerating {
                    Button {
                        isFocused = false
                        onCancel()
                    } label: {
                        Label("Stop generating", systemImage: "stop.circle.fill")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(AppTheme.destructive))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Stop generating")
                    .accessibilityIdentifier("chat.composer.stop")
                } else {
                    Button {
                        isFocused = false
                        onSend()
                    } label: {
                        Label("Send message", systemImage: "arrow.up")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(
                                hasText || hasAttachment
                                    ? AnyShapeStyle(.white)
                                    : AnyShapeStyle(.tertiary)
                            )
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(
                                        hasText || hasAttachment
                                            ? AnyShapeStyle(AppTheme.deep)
                                            : AnyShapeStyle(AppTheme.surfaceElevated)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasText && !hasAttachment)
                    .accessibilityLabel("Send message")
                    .accessibilityIdentifier("chat.composer.send")
                }
            }
            .transition(.scale.combined(with: .opacity))
            .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: isGenerating)
        }
        .padding(.horizontal, AppTheme.spacingMD)
        .padding(.vertical, AppTheme.spacingXS)
        .background(
            Capsule(style: .continuous)
                .fill(AppTheme.appBackground)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(isFocused ? AppTheme.surfaceStrokeStrong : AppTheme.surfaceStroke, lineWidth: isFocused ? 1 : 0.7)
                )
                .shadow(color: Color.primary.opacity(isFocused ? 0.14 : 0.09), radius: isFocused ? 22 : 16, y: isFocused ? 10 : 7)
        )
        .padding(.horizontal, AppTheme.spacingLG)
        .padding(.vertical, AppTheme.spacingSM)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isFocused)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.composer")
    }
}

#Preview {
    ComposerBarPreviewHost()
}

private struct ComposerBarPreviewHost: View {
    @State private var text = "Hello"
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack {
            Spacer()
            ComposerBar(
                text: $text,
                isFocused: $isFocused,
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
}
