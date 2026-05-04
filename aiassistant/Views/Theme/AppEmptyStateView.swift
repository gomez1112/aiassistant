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
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
                .foregroundStyle(AppTheme.accent)
        } description: {
            Text(description)
                .multilineTextAlignment(.center)
        } actions: {
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
