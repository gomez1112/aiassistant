import SwiftUI

struct AppIconBadge: View {
    let systemImage: String
    let tint: Color
    var size: CGFloat = 34

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: min(size * 0.2, AppTheme.radiusCard), style: .continuous)
                    .fill(tint.opacity(0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: min(size * 0.2, AppTheme.radiusCard), style: .continuous)
                    .stroke(tint.opacity(0.14), lineWidth: 0.7)
            )
            .accessibilityHidden(true)
    }
}
