// Views/Chat/AriGuidanceBar.swift
// ai.assistant
//
// Persistent bottom bar showing Ari's current guidance line
// and micro-coaching action buttons.

import SwiftUI

struct AriGuidanceBar: View {
    let ari: AriEngine
    let onAction: (AriActionType) -> Void

    var body: some View {
        VStack(spacing: 6) {
            // Guidance line
            HStack(spacing: 8) {
                Image(systemName: ari.currentMood.icon)
                    .foregroundStyle(ari.currentMood.color)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 20)

                Text(ari.guidanceLine)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer()
            }
            .padding(.horizontal, AppTheme.spacingLG)

            // Coaching actions
            if !ari.coachingActions.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(ari.coachingActions) { action in
                            Button {
                                onAction(action.action)
                            } label: {
                                Label(action.label, systemImage: action.icon)
                                    .font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
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
                        }
                    }
                    .padding(.horizontal, AppTheme.spacingLG)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(.regularMaterial)
                .overlay(Divider(), alignment: .top)
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: -2)
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: ari.guidanceLine)
    }
}
