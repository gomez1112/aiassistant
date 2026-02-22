// Engines/AriEngine.swift
// ai.assistant
//
// Computes Ari's mood, guidance lines, and micro-coaching actions
// from conversation context and user preferences.

import Foundation

/// AriEngine analyzes conversation context and produces emotional guidance.
///
/// ## How Ari Works
///
/// Ari's mood is derived from signals in the conversation:
/// - **Message count**: Early in a thread → encouraging; deep threads → focused
/// - **User intent mode**: Planning → focused; brainstorming → curious; write → supportive
/// - **Completion signals**: When an artifact is saved → celebratory
/// - **Content length**: Short exchanges → calm; long outputs → encouraging
///
/// The guidance lines are short (1–2 sentences) and non-medical.
/// They are influenced by the user's preferred vibe and expressiveness level.
///
/// Ari never diagnoses, never makes medical claims, and never manipulates.
@MainActor
@Observable
final class AriEngine {

    // MARK: - State

    var currentMood: AriMood = .calm
    var guidanceLine: String = ""
    var coachingActions: [AriCoachingAction] = []

    // MARK: - Mood Computation

    /// Analyze conversation context and update Ari's state.
    func update(
        messages: [Message],
        lastMode: AssistantMode?,
        preferences: UserPreferences,
        justSavedArtifact: Bool = false
    ) {
        guard preferences.ariEnabled else {
            currentMood = .calm
            guidanceLine = ""
            coachingActions = []
            return
        }

        // Determine mood from signals
        currentMood = computeMood(
            messageCount: messages.count,
            lastMode: lastMode,
            justSavedArtifact: justSavedArtifact,
            vibe: preferences.ariVibe
        )

        // Generate guidance line
        guidanceLine = generateGuidance(
            mood: currentMood,
            mode: lastMode,
            expressiveness: preferences.ariExpressiveness,
            vibe: preferences.ariVibe,
            messageCount: messages.count
        )

        // Generate coaching actions
        coachingActions = generateCoachingActions(
            mood: currentMood
        )
    }

    // MARK: - Private Helpers

    private func computeMood(
        messageCount: Int,
        lastMode: AssistantMode?,
        justSavedArtifact: Bool,
        vibe: AriVibe
    ) -> AriMood {
        if justSavedArtifact { return .celebratory }

        switch lastMode {
        case .plan:       return .focused
        case .brainstorm: return .curious
        case .write:      return .supportive
        case .summarize:  return .calm
        case .explain:    return .encouraging
        case .general, .none:
            break
        }

        // Default progression based on conversation depth
        switch messageCount {
        case 0...2:  return vibe == .energetic ? .encouraging : .calm
        case 3...8:  return .supportive
        case 9...15: return .focused
        default:     return .encouraging
        }
    }

    private func generateGuidance(
        mood: AriMood,
        mode: AssistantMode?,
        expressiveness: AriExpressiveness,
        vibe: AriVibe,
        messageCount: Int
    ) -> String {
        // Low expressiveness = minimal guidance
        if expressiveness == .low {
            return shortGuidance(mood: mood, mode: mode)
        }

        // Medium/High expressiveness gets richer lines
        let base = fullGuidance(mood: mood, mode: mode, messageCount: messageCount)

        // Energetic vibe adds an extra flourish
        if vibe == .energetic && expressiveness == .high {
            return base + " Let's go!"
        }
        return base
    }

    private func shortGuidance(mood: AriMood, mode: AssistantMode?) -> String {
        switch mood {
        case .calm:         return "Ready when you are."
        case .encouraging:  return "Looking good."
        case .focused:      return "Staying on track."
        case .celebratory:  return "Saved!"
        case .curious:      return "Interesting direction."
        case .supportive:   return "I'm here to help."
        }
    }

    private func fullGuidance(mood: AriMood, mode: AssistantMode?, messageCount: Int) -> String {
        switch mood {
        case .calm:
            return messageCount == 0
                ? "Let's keep things simple. What are you working on?"
                : "Take your time — no rush here."

        case .encouraging:
            switch mode {
            case .explain:
                return "Nice — this is coming together clearly. Want me to simplify further?"
            default:
                return "Good progress. I can turn this into something more polished if you'd like."
            }

        case .focused:
            return "Let's stay focused. Want the short version or the detailed one?"

        case .celebratory:
            return "Nice — that's saved to your Outputs. Ready for the next thing?"

        case .curious:
            return "Lots of directions here. Want me to narrow it down or keep exploring?"

        case .supportive:
            return "I can help shape this. Just say the word."
        }
    }

    private func generateCoachingActions(
        mood: AriMood
    ) -> [AriCoachingAction] {
        var actions: [AriCoachingAction] = []

        switch mood {
        case .focused, .supportive:
            actions.append(AriCoachingAction(
                label: "Take the next step",
                icon: "arrow.right.circle",
                action: .createChecklist
            ))
        case .encouraging:
            actions.append(AriCoachingAction(
                label: "Refine tone",
                icon: "slider.horizontal.3",
                action: .refineTone
            ))
        case .curious:
            actions.append(AriCoachingAction(
                label: "Ask a follow-up",
                icon: "bubble.left.and.bubble.right",
                action: .askFollowUp
            ))
        case .celebratory:
            actions.append(AriCoachingAction(
                label: "What's next?",
                icon: "sparkles",
                action: .askFollowUp
            ))
        case .calm:
            actions.append(AriCoachingAction(
                label: "Simplify",
                icon: "arrow.down.right.and.arrow.up.left",
                action: .simplify
            ))
        }

        return actions
    }
}
