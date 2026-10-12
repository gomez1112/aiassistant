import SwiftUI

// MARK: - Single Flashcard

struct FlashcardView: View {
    let front: String
    let back: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFlipped = false

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.15)) {
                isFlipped.toggle()
            }
        }
        label: {
            ZStack {
                // Back
                cardFace(text: back, isBack: true)
                    .rotation3DEffect(.degrees(reduceMotion || isFlipped ? 0 : 180), axis: (x: 0, y: 1, z: 0))
                    .opacity(isFlipped ? 1 : 0)

                // Front
                cardFace(text: front, isBack: false)
                    .rotation3DEffect(.degrees(!reduceMotion && isFlipped ? -180 : 0), axis: (x: 0, y: 1, z: 0))
                    .opacity(isFlipped ? 0 : 1)
            }
            .frame(minHeight: 220)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isFlipped)
        .accessibilityLabel(isFlipped ? "Back: \(back)" : "Front: \(front)")
        .accessibilityHint("Double tap to flip")
    }

    private func cardFace(text: String, isBack: Bool) -> some View {
        VStack(spacing: 12) {
            // Label
            HStack {
                Text(isBack ? "ANSWER" : "QUESTION")
                    .font(.caption.bold())
                    .tracking(1.2)
                    .foregroundStyle(isBack ? AppTheme.highlight : AppTheme.accent)
                Spacer()
                Image(systemName: isBack ? "lightbulb.fill" : "questionmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isBack ? AppTheme.highlight.opacity(0.6) : AppTheme.accent.opacity(0.6))
            }

            Spacer()

            // Content
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)

            Spacer()
        }
        .padding(AppTheme.spacingXL)
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                .fill(AppTheme.surfaceFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                .stroke((isBack ? AppTheme.highlight : AppTheme.accent).opacity(0.28), lineWidth: 1)
        )
    }
}
