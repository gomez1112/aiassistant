import SwiftUI

// MARK: - Content Router

/// Routes to the appropriate rich view based on artifact kind.
struct ArtifactContentView: View {
    let artifact: Artifact

    var body: some View {
        Group {
            switch artifact.kind {
            case .flashcards:
                FlashcardDeckView(content: artifact.content)
            case .quiz:
                QuizView(content: artifact.content)
            case .checklist:
                BulletListView(content: artifact.content)
            default:
                StyledTextView(content: artifact.content, kind: artifact.kind)
            }
        }
        // Synced content can replace a quiz or deck while it is open. Reset only
        // when the source changes so answer indices cannot address an older deck.
        .id(artifact.content)
    }
}
