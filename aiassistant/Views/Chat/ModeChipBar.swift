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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
            adaptivePicker
        case .expandedChips:
            #if os(macOS)
            adaptivePicker
            #else
            expandedChips
            #endif
        }
    }

    private var expandedChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: AppTheme.spacingSM) {
                ForEach(modes) { mode in
                    ModeChip(
                        mode: mode,
                        isSelected: selectedMode == mode,
                        action: { selectedMode = mode }
                    )
                }
            }
            .padding(.horizontal, AppTheme.spacingLG)
            .padding(.vertical, AppTheme.spacingSM)
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mode selector")
        .accessibilityIdentifier("chat.mode.selector")
    }

    private var compactMenu: some View {
        HStack {
            Picker("Mode", selection: $selectedMode) {
                ForEach(modes) { mode in
                    Text(mode.chipLabel)
                        .tag(mode)
                        .accessibilityIdentifier("chat.mode.option.\(mode.rawValue)")
                }
            }
            .pickerStyle(.menu)
            .font(.footnote)
            .padding(.horizontal, AppTheme.spacingSM)
            .frame(minHeight: AppTheme.minimumTapTarget)
            .background(AppTheme.surfaceFill, in: .capsule)
            .buttonStyle(.plain)
            .accessibilityLabel("Mode")
            .accessibilityValue(selectedMode.chipLabel)
            .accessibilityIdentifier("chat.mode.compactMenu")

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.spacingLG)
        .padding(.vertical, AppTheme.spacingXS)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mode selector")
        .accessibilityIdentifier("chat.mode.selector")
    }

    @ContentBuilder
    private var adaptivePicker: some View {
        if dynamicTypeSize.isAccessibilitySize {
            compactMenu
        } else {
            ViewThatFits(in: .horizontal) {
                segmentedPicker
                compactMenu
            }
        }
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
            .fixedSize(horizontal: true, vertical: false)
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
