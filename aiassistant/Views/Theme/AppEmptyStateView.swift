import SwiftUI

struct AppEmptyStateView: View {
    let title: String
    let systemImage: String
    let description: String
    let actionTitle: String?
    let actionSystemImage: String?
    let actionAccessibilityIdentifier: String?
    let action: (() -> Void)?

    init(
        title: String,
        systemImage: String,
        description: String,
        actionTitle: String? = nil,
        actionSystemImage: String? = nil,
        actionAccessibilityIdentifier: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
        self.actionTitle = actionTitle
        self.actionSystemImage = actionSystemImage
        self.actionAccessibilityIdentifier = actionAccessibilityIdentifier
        self.action = action
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                ContentUnavailableView {
                    Label(title, systemImage: systemImage)
                } description: {
                    Text(description)
                } actions: {
                    if let actionTitle, let action {
                        Button(actionTitle, systemImage: actionSystemImage ?? "plus", action: action)
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier(actionAccessibilityIdentifier ?? "emptyState.action")
                    }
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}
