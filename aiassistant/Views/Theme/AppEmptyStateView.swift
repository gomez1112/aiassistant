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
        VStack(spacing: AppTheme.spacingLG) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(AppTheme.brandGradient)
                .frame(width: 84, height: 84)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AppTheme.brandWash)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppTheme.accent.opacity(0.18), lineWidth: 1)
                )
                .accessibilityHidden(true)

            VStack(spacing: AppTheme.spacingSM) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .frame(maxWidth: 320)
            }

            if let actionTitle, let action {
                actionButton(title: actionTitle, action: action)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppTheme.spacingXL)
    }

    @ViewBuilder
    private func actionButton(title: String, action: @escaping () -> Void) -> some View {
        let button = AppPrimaryButton(
            title,
            systemImage: actionSystemImage,
            action: action
        )

        if let actionAccessibilityIdentifier {
            button.accessibilityIdentifier(actionAccessibilityIdentifier)
        } else {
            button
        }
    }
}
