import SwiftUI

struct AppBanner<Accessory: View>: View {
    let systemImage: String
    let message: String
    let tint: Color
    let accessory: Accessory

    init(
        systemImage: String,
        message: String,
        tint: Color = AppTheme.accent,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.systemImage = systemImage
        self.message = message
        self.tint = tint
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 22)
                .accessibilityHidden(true)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            accessory
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .appSurface(cornerRadius: AppTheme.radiusSmall)
        .accessibilityElement(children: .combine)
    }
}

extension AppBanner where Accessory == EmptyView {
    init(
        systemImage: String,
        message: String,
        tint: Color = AppTheme.accent
    ) {
        self.init(systemImage: systemImage, message: message, tint: tint) {
            EmptyView()
        }
    }
}
