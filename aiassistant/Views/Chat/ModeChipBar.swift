// Views/Chat/ModeChipBar.swift
// ai.assistant
//
// Horizontal scrolling bar of mode chips (Write, Summarize, Explain, Plan, Brainstorm).

import SwiftUI

struct ModeChipBar: View {
    enum DisplayStyle {
        case expandedChips
        case compactMenu
        case segmented
    }

    @Binding var selectedMode: AssistantMode
    let displayStyle: DisplayStyle

    private let modes: [AssistantMode] = [.general, .write, .summarize, .explain, .plan, .brainstorm]

    init(
        selectedMode: Binding<AssistantMode>,
        displayStyle: DisplayStyle = .expandedChips
    ) {
        self._selectedMode = selectedMode
        self.displayStyle = displayStyle
    }

    var body: some View {
        switch displayStyle {
        case .compactMenu:
            compactMenu
        case .segmented:
            segmentedPicker
        case .expandedChips:
            #if os(macOS)
            segmentedPicker
            #else
            expandedChips
            #endif
        }
    }

    private var expandedChips: some View {
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
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mode selector")
        .accessibilityIdentifier("chat.mode.selector")
    }

    private var compactMenu: some View {
        HStack {
            Menu {
                ForEach(modes) { mode in
                    Button {
                        selectedMode = mode
                    } label: {
                        Label(mode.chipLabel, systemImage: selectedMode == mode ? "checkmark" : mode.icon)
                    }
                    .accessibilityIdentifier("chat.mode.option.\(mode.rawValue)")
                }
            } label: {
                Label(selectedMode.chipLabel, systemImage: selectedMode.icon)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 12)
                    .frame(height: AppTheme.minimumTapTarget)
                    .background(AppTheme.surfaceFill, in: Capsule())
                    .overlay(Capsule().stroke(AppTheme.surfaceStroke, lineWidth: 0.6))
            }
            .accessibilityLabel("Mode")
            .accessibilityValue(selectedMode.chipLabel)
            .accessibilityIdentifier("chat.mode.compactMenu")

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.spacingLG)
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mode selector")
        .accessibilityIdentifier("chat.mode.selector")
    }

    private var segmentedPicker: some View {
        HStack {
            Picker("Mode", selection: $selectedMode) {
                ForEach(modes) { mode in
                    Text(mode.chipLabel)
                        .tag(mode)
                        .accessibilityIdentifier("chat.mode.option.\(mode.rawValue)")
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .tint(AppTheme.accent)
            .frame(maxWidth: 760)
            .accessibilityIdentifier("chat.mode.segmentedPicker")

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.spacingLG)
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mode selector")
        .accessibilityIdentifier("chat.mode.selector")
    }
}

struct ModeChip: View {
    let mode: AssistantMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(mode.chipLabel, systemImage: mode.icon)
                .font(.footnote.weight(isSelected ? .semibold : .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .frame(minHeight: AppTheme.minimumTapTarget)
                .background(
                    Capsule()
                        .fill(isSelected
                            ? AnyShapeStyle(AppTheme.brandGradient)
                            : AnyShapeStyle(AppTheme.surfaceFill)
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? Color.clear : AppTheme.surfaceStroke,
                            lineWidth: 0.5
                        )
                )
                .foregroundStyle(isSelected ? .white : .secondary)
                .shadow(color: isSelected ? AppTheme.accent.opacity(0.25) : .clear, radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.chipLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityIdentifier("chat.mode.option.\(mode.rawValue)")
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

#Preview {
    ModeChipBar(selectedMode: .constant(.general))
}
