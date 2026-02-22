// Views/Chat/ModeChipBar.swift
// ai.assistant
//
// Horizontal scrolling bar of mode chips (Write, Summarize, Explain, Plan, Brainstorm).

import SwiftUI

struct ModeChipBar: View {
    @Binding var selectedMode: AssistantMode

    private let modes: [AssistantMode] = [.general, .write, .summarize, .explain, .plan, .brainstorm]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(modes) { mode in
                    ModeChip(
                        mode: mode,
                        isSelected: selectedMode == mode,
                        action: { selectedMode = mode }
                    )
                }
            }
            .padding(.horizontal, AppTheme.spacingLG)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .background(.ultraThinMaterial)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mode selector")
    }
}

struct ModeChip: View {
    let mode: AssistantMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(mode.chipLabel, systemImage: mode.icon)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected
                            ? AnyShapeStyle(AppTheme.accentGradient)
                            : AnyShapeStyle(AppTheme.surface)
                        )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(
                            isSelected ? Color.clear : AppTheme.surfaceStroke,
                            lineWidth: 0.5
                        )
                )
                .foregroundStyle(isSelected ? .white : .secondary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

#Preview {
    ModeChipBar(selectedMode: .constant(.general))
}
