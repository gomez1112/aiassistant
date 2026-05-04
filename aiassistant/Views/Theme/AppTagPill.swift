import SwiftUI

struct AppTagPill: View {
    let title: String
    var tint: Color = AppTheme.accent

    var body: some View {
        Text(title)
            .font(.footnote)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(tint.opacity(0.10))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.18), lineWidth: 0.6)
            )
            .foregroundStyle(.secondary)
    }
}
