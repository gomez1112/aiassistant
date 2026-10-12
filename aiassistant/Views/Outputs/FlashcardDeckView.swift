import SwiftUI

// MARK: - Flashcard Deck

struct FlashcardDeckView: View {
    let content: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentIndex = 0

    private var cards: [(front: String, back: String)] {
        parseFlashcards(from: content)
    }

    var body: some View {
        let cards = cards
        if cards.isEmpty {
            // Fallback: show raw text if parsing fails
            VStack(alignment: .leading) {
                Text(content)
                    .font(.body)
                    .lineSpacing(4)
                    .textSelection(.enabled)
            }
            .padding(AppTheme.spacingLG)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appSurface()
        } else {
            VStack(spacing: 16) {
                // Card counter
                Text("\(currentIndex + 1) of \(cards.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                // Flashcard
                FlashcardView(
                    front: cards[currentIndex].front,
                    back: cards[currentIndex].back
                )
                .id(currentIndex) // Reset flip state on card change

                // Navigation
                HStack(spacing: 20) {
                    Button {
                        withAnimation(reduceMotion ? nil : .spring(duration: 0.35)) {
                            currentIndex = max(0, currentIndex - 1)
                        }
                    } label: {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(currentIndex > 0 ? AppTheme.accent : Color.secondary.opacity(0.3))
                    }
                    .frame(minWidth: AppTheme.minimumTapTarget, minHeight: AppTheme.minimumTapTarget)
                    .accessibilityLabel("Previous card")
                    .disabled(currentIndex == 0)

                    ProgressView(value: Double(currentIndex + 1), total: Double(cards.count))
                        .frame(maxWidth: 180)
                        .accessibilityLabel("Deck progress")
                        .accessibilityValue("Card \(currentIndex + 1) of \(cards.count)")

                    Button {
                        withAnimation(reduceMotion ? nil : .spring(duration: 0.35)) {
                            currentIndex = min(cards.count - 1, currentIndex + 1)
                        }
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(currentIndex < cards.count - 1 ? AppTheme.accent : Color.secondary.opacity(0.3))
                    }
                    .frame(minWidth: AppTheme.minimumTapTarget, minHeight: AppTheme.minimumTapTarget)
                    .accessibilityLabel("Next card")
                    .disabled(currentIndex >= cards.count - 1)
                }
                .buttonStyle(.plain)

                Text("Tap card to flip")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// Parses flashcard content in various AI-generated formats.
    /// Supports: "Q: ... / A: ...", "Front: ... / Back: ...",
    /// numbered prefixes like "1. Q:", bold markers, and multiline answers.
    private func parseFlashcards(from text: String) -> [(front: String, back: String)] {
        var cards: [(front: String, back: String)] = []
        let lines = text.components(separatedBy: .newlines)

        var currentQ: String?
        var currentA: String?

        func flushCard() {
            if let q = currentQ, let a = currentA,
               !q.isEmpty, !a.isEmpty {
                cards.append((front: q, back: a))
            }
            currentQ = nil
            currentA = nil
        }

        for line in lines {
            // Strip leading whitespace, numbering, bullets, asterisks
            var cleaned = line.trimmingCharacters(in: .whitespaces)
            // Remove markdown bold markers
            cleaned = cleaned.replacingOccurrences(of: "**", with: "")
            // Remove leading "1." or "1)" style numbering
            if let range = cleaned.range(of: #"^\d+[\.\)]\s*"#, options: .regularExpression) {
                cleaned = String(cleaned[range.upperBound...])
            }
            // Remove leading bullet "- " or "• "
            if cleaned.hasPrefix("- ") { cleaned = String(cleaned.dropFirst(2)) }
            if cleaned.hasPrefix("• ") { cleaned = String(cleaned.dropFirst(2)) }

            let lowered = cleaned.lowercased()

            if lowered.hasPrefix("q:") || lowered.hasPrefix("front:") || lowered.hasPrefix("question:") {
                // New question — flush any previous card
                flushCard()
                let prefixes = ["question:", "front:", "q:"]
                for prefix in prefixes {
                    if lowered.hasPrefix(prefix) {
                        currentQ = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                        break
                    }
                }
            } else if lowered.hasPrefix("a:") || lowered.hasPrefix("back:") || lowered.hasPrefix("answer:") {
                let prefixes = ["answer:", "back:", "a:"]
                for prefix in prefixes {
                    if lowered.hasPrefix(prefix) {
                        currentA = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                        break
                    }
                }
            } else if !cleaned.isEmpty {
                // Continuation line — append to whichever field is active
                if currentA != nil {
                    currentA! += " " + cleaned
                } else if currentQ != nil {
                    currentQ! += " " + cleaned
                }
            }
        }
        // Flush the last card
        flushCard()

        return cards
    }
}
