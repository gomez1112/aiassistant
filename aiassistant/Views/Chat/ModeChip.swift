import SwiftUI

struct ModeChip: View {
    let mode: AssistantMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(mode.chipLabel, systemImage: mode.icon)
                .font(.footnote.weight(isSelected ? .semibold : .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(minHeight: AppTheme.minimumTapTarget)
                .background(
                    Capsule()
                        .fill(isSelected
                            ? AnyShapeStyle(AppTheme.accent.opacity(0.14))
                            : AnyShapeStyle(AppTheme.surfaceFill)
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? AppTheme.accent.opacity(0.28) : AppTheme.surfaceStroke,
                            lineWidth: 0.7
                        )
                )
                .foregroundStyle(isSelected ? AppTheme.accent : .secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.chipLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityIdentifier("chat.mode.option.\(mode.rawValue)")
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
