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
                RoundedRectangle(cornerRadius: size * 0.26)
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.26)
                    .stroke(tint.opacity(0.18), lineWidth: 0.7)
            )
            .accessibilityHidden(true)
    }
}
