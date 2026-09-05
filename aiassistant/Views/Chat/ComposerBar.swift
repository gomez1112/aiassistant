// Views/Chat/ComposerBar.swift
// ai.assistant
//
// Floating composer with attach, multi-line input, and send/stop controls.

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

    private var canSend: Bool {
        (hasText || hasAttachment) && !isGenerating && !isImportingAttachment
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: AppTheme.spacingSM) {
            Button("Attach file", systemImage: "paperclip", action: onAttach)
                .labelStyle(.iconOnly)
                .font(.body.weight(.semibold))
                .foregroundStyle(isImportingAttachment ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                .frame(width: 36, height: 36)
                .contentShape(.circle)
                .buttonStyle(.plain)
                .disabled(isImportingAttachment)
                .overlay {
                    if isImportingAttachment {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .accessibilityLabel(isImportingAttachment ? "Importing attachment" : "Attach file")
                .accessibilityIdentifier("chat.composer.attach")

            TextField("Ask \(assistantName)…", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .padding(.vertical, 10)
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit {
                    guard canSend else { return }
                    onSend()
                }
                .accessibilityLabel("Message input")
                .accessibilityIdentifier("chat.composer.input")

            Group {
                if isGenerating {
                    Button("Stop generating", systemImage: "stop.fill") {
                        onCancel()
                    }
                    .labelStyle(.iconOnly)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.deep, in: .circle)
                    .contentShape(.circle)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Stop generating")
                    .accessibilityIdentifier("chat.composer.stop")
                } else {
                    Button("Send message", systemImage: "arrow.up") {
                        isFocused = false
                        onSend()
                    }
                    .labelStyle(.iconOnly)
                    .font(.body.weight(.bold))
                    .foregroundStyle(canSend ? AnyShapeStyle(.white) : AnyShapeStyle(.tertiary))
                    .frame(width: 36, height: 36)
                    .background(
                        canSend ? AnyShapeStyle(AppTheme.deep) : AnyShapeStyle(AppTheme.surfaceElevated),
                        in: .circle
                    )
                    .contentShape(.circle)
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                    .accessibilityLabel("Send message")
                    .accessibilityIdentifier("chat.composer.send")
                }
            }
            .transition(.scale.combined(with: .opacity))
            .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: isGenerating)
            .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: canSend)
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
