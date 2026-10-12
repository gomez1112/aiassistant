import SwiftUI

// MARK: - Styled Text View (Shorter / More Formal / Other)

/// A rich text view for shorter and more formal transforms (and any fallback).
/// Uses elegant typography with pull-quote styling.
struct StyledTextView: View {
    let content: String
    let kind: ArtifactKind

    private var accentColor: Color {
        switch kind {
        case .draft, .summary, .other: return AppTheme.accent
        case .checklist: return AppTheme.success
        case .plan: return AppTheme.accentLight
        case .quiz: return AppTheme.warning
        case .flashcards: return AppTheme.highlight
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Decorative accent bar
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: 3, height: 24)
                Spacer()
            }

            // Content paragraphs with refined typography
            let displayContent = normalizedDisplayText(content)
            let paragraphs = displayContent.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

            if paragraphs.count > 1 {
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { idx, paragraph in
                    Text(verbatim: paragraph.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(idx == 0 ? .body.weight(.medium) : .body)
                        .lineSpacing(6)
                        .foregroundStyle(Color.primary.opacity(idx == 0 ? 1.0 : 0.85))
                        .textSelection(.enabled)
                }
            } else {
                Text(verbatim: displayContent.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.body)
                    .lineSpacing(6)
                    .textSelection(.enabled)
            }
        }
        .padding(AppTheme.spacingXL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appSurface(cornerRadius: AppTheme.radiusCard)
    }
}
