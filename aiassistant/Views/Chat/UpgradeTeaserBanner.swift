import SwiftUI

struct UpgradeTeaserBanner: View {
    let remainingFreeMessages: Int
    let action: () -> Void

    private var isLimitClose: Bool {
        remainingFreeMessages <= 2
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.spacingSM) {
                Image(systemName: isLimitClose ? "message.badge" : "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 20)

                Text(isLimitClose ? "\(remainingFreeMessages) free messages left today" : "Start trial for unlimited chat")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer(minLength: AppTheme.spacingSM)

                Label(isLimitClose ? "Start Trial" : "Ari+", systemImage: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(minHeight: AppTheme.minimumTapTarget)
            .background(AppTheme.surfaceFill, in: Capsule())
            .overlay(Capsule().stroke(AppTheme.surfaceStroke, lineWidth: 0.6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Upgrade to Ari+. \(remainingFreeMessages) free messages left. Start a free trial for unlimited chats, files, and Output Studio.")
        .accessibilityIdentifier("chat.upgradeTeaser")
    }
}
