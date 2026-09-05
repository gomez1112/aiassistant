// Views/Chat/ChatStarterView.swift
// ai.assistant
//
// Empty chat state with a greeting and one-tap starter prompts.

import SwiftUI

struct ChatStarterView: View {
    let assistantName: String
    let prompts: [StarterPrompt]
    let onSelect: (StarterPrompt) -> Void

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 260), spacing: AppTheme.spacingSM)]

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingXL) {
                VStack(spacing: AppTheme.spacingSM) {
                    Image(systemName: "sparkles")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(AppTheme.brandGradient)
                        .accessibilityHidden(true)

                    Text("What can we finish today?")
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)

                    Text("Ask \(assistantName) to draft, explain, plan, or turn a file into clear next steps.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 340)
                }

                LazyVGrid(columns: columns, spacing: AppTheme.spacingSM) {
                    ForEach(prompts) { prompt in
                        StarterPromptButton(prompt: prompt) {
                            onSelect(prompt)
                        }
                    }
                }
                .frame(maxWidth: 560)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppTheme.spacingLG)
            .padding(.vertical, AppTheme.spacingXL)
            .containerRelativeFrame(.vertical, alignment: .center) { height, _ in
                height
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
        .accessibilityIdentifier("chat.emptyState")
    }
}

private struct StarterPromptButton: View {
    let prompt: StarterPrompt
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
                Image(systemName: prompt.systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)

                Text(prompt.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(prompt.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .padding(AppTheme.spacingMD)
            .background(AppTheme.surfaceFill, in: .rect(cornerRadius: AppTheme.radiusCard))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                    .stroke(AppTheme.surfaceStroke, lineWidth: 0.7)
            )
            .contentShape(.rect(cornerRadius: AppTheme.radiusCard))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(prompt.title)
        .accessibilityHint("Sends: \(prompt.message)")
        .accessibilityIdentifier("chat.starter.\(prompt.mode.rawValue)")
    }
}
