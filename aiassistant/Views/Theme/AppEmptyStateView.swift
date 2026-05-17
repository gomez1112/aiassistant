import SwiftUI

struct AppEmptyStateView: View {
    let title: String
    let systemImage: String
    let description: String
    let actionTitle: String?
    let actionSystemImage: String?
    let action: (() -> Void)?

    init(
        title: String,
        systemImage: String,
        description: String,
        actionTitle: String? = nil,
        actionSystemImage: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
        self.actionTitle = actionTitle
        self.actionSystemImage = actionSystemImage
        self.action = action
    }

    var body: some View {
        VStack(spacing: AppTheme.spacingLG) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(AppTheme.accent.opacity(0.72))
                .frame(width: 56, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                        .fill(AppTheme.surfaceFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                        .stroke(AppTheme.surfaceStroke, lineWidth: 0.6)
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
                AppPrimaryButton(
                    actionTitle,
                    systemImage: actionSystemImage,
                    action: action
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppTheme.spacingXL)
    }
}
