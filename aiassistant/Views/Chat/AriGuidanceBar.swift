// Views/Chat/AriGuidanceBar.swift
// ai.assistant
//
// Persistent bottom bar showing Ari's current guidance line
// and micro-coaching action buttons.

import SwiftUI

struct AriGuidanceBar: View {
    let ari: AriEngine
    let usesCompactChrome: Bool
    let onAction: (AriActionType) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if usesCompactChrome {
                compactActions
            } else {
                expandedActions
            }
        }
        .padding(.vertical, 6)
        .background(
            Rectangle()
                .fill(AppTheme.groupedBackground.opacity(0.92))
                .overlay(Divider().opacity(0.7), alignment: .top)
        )
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: ari.coachingActions.count)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Ari actions")
        .accessibilityIdentifier("chat.ariActions")
    }

    private var expandedActions: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(ari.coachingActions) { action in
                    AriActionButton(action: action, onAction: onAction)
                }
            }
            .padding(.horizontal, AppTheme.spacingLG)
        }
        .scrollIndicators(.hidden)
    }

    private var compactActions: some View {
        HStack {
            Menu {
                ForEach(ari.coachingActions) { action in
                    Button {
                        onAction(action.action)
                    } label: {
                        Label(action.label, systemImage: action.icon)
                    }
                    .accessibilityIdentifier("chat.ariActions.\(action.action.accessibilityIdentifier)")
                }
            } label: {
                Label("Ari actions", systemImage: "sparkles")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 12)
                    .frame(minHeight: AppTheme.minimumTapTarget)
                    .background(AppTheme.surfaceFill, in: Capsule(style: .continuous))
                    .overlay(Capsule(style: .continuous).stroke(AppTheme.surfaceStroke, lineWidth: 0.6))
            }
            .accessibilityIdentifier("chat.ariActions.menu")

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.spacingLG)
    }
}

private struct AriActionButton: View {
    let action: AriCoachingAction
    let onAction: (AriActionType) -> Void

    var body: some View {
        Button {
            onAction(action.action)
        } label: {
                Label(action.label, systemImage: action.icon)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 12)
                    .frame(minHeight: AppTheme.minimumTapTarget)
                .background(
                    Capsule(style: .continuous)
                        .fill(AppTheme.surface)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(AppTheme.surfaceStroke, lineWidth: 0.5)
                )
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("chat.ariActions.\(action.action.accessibilityIdentifier)")
    }
}
