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

    private var canSend: Bool {
        (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasAttachment) &&
        !isGenerating && !isImportingAttachment
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: AppTheme.spacingSM) {
            Button(action: onAttach) {
                Label("Attach file", systemImage: "paperclip")
                    .labelStyle(.iconOnly)
                    .font(.body)
                    // Bound only the symbol; the message field keeps full Dynamic Type.
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .foregroundStyle(isImportingAttachment ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                    .frame(width: AppTheme.minimumTapTarget, height: AppTheme.minimumTapTarget)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .disabled(isImportingAttachment)
            .overlay {
                if isImportingAttachment { ProgressView().controlSize(.small) }
            }
            .accessibilityLabel(isImportingAttachment ? "Importing attachment" : "Attach file")
            .accessibilityIdentifier("chat.composer.attach")

            TextField("Ask \(assistantName)…", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .padding(.vertical, AppTheme.spacingSM)
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit(send)
                .accessibilityLabel("Message input")
                .accessibilityIdentifier("chat.composer.input")

            Button(action: isGenerating ? onCancel : send) {
                Label(isGenerating ? "Stop generating" : "Send message", systemImage: isGenerating ? "stop.fill" : "arrow.up")
                    .labelStyle(.iconOnly)
                    .font(.body.bold())
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .foregroundStyle(isGenerating || canSend ? AnyShapeStyle(.white) : AnyShapeStyle(.tertiary))
                    .frame(width: AppTheme.minimumTapTarget, height: AppTheme.minimumTapTarget)
                    .background(isGenerating || canSend ? AnyShapeStyle(AppTheme.deep) : AnyShapeStyle(AppTheme.surfaceElevated), in: .circle)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .disabled(!isGenerating && !canSend)
            .accessibilityIdentifier(isGenerating ? "chat.composer.stop" : "chat.composer.send")
        }
        .padding(.horizontal, AppTheme.spacingMD)
        .padding(.vertical, AppTheme.spacingXS)
        .background(AppTheme.appBackground, in: .rect(cornerRadius: AppTheme.radiusCard))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.radiusCard)
                .stroke(isFocused ? AppTheme.surfaceStrokeStrong : AppTheme.surfaceStroke, lineWidth: isFocused ? 1 : 0.7)
        }
        .padding(.horizontal, AppTheme.spacingLG)
        .padding(.vertical, AppTheme.spacingSM)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: canSend)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.composer")
    }

    private func send() {
        guard canSend else { return }
        isFocused = false
        onSend()
    }
}
