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
                                    .stroke(AppTheme.surfaceStrokeStrong, lineWidth: 0.8)
                            )
                    )
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
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(AppTheme.surfaceFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(
                                    isFocused
                                        ? AppTheme.accent.opacity(0.8)
                                        : AppTheme.surfaceStroke,
                                    lineWidth: isFocused ? 1.2 : 0.5
                                )
                        )
                        .shadow(color: Color.primary.opacity(isFocused ? 0.06 : 0.025), radius: 10, y: 4)
                )
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
                            .frame(width: AppTheme.minimumTapTarget, height: AppTheme.minimumTapTarget)
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
                                    : AnyShapeStyle(.secondary)
                            )
                            .frame(width: AppTheme.minimumTapTarget, height: AppTheme.minimumTapTarget)
                            .background(
                                Circle()
                                    .fill(
                                        hasText || hasAttachment
                                            ? AnyShapeStyle(AppTheme.brandGradient)
                                            : AnyShapeStyle(AppTheme.surfaceFill)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                hasText || hasAttachment
                                                    ? Color.clear
                                                    : AppTheme.surfaceStrokeStrong,
                                                lineWidth: 0.7
                                            )
                                    )
                                    .shadow(
                                        color: (hasText || hasAttachment) ? AppTheme.accentDeep.opacity(0.24) : .clear,
                                        radius: 10, y: 4
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
        .padding(.horizontal, AppTheme.spacingLG)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            Rectangle()
                .fill(AppTheme.appBackground.opacity(0.94))
                .overlay(Divider().opacity(0.5), alignment: .top)
        )
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
