import SwiftUI

struct AppPrimaryButton: View {
    let title: String
    let systemImage: String?
    let isDisabled: Bool
    let fillsWidth: Bool
    let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        isDisabled: Bool = false,
        fillsWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isDisabled = isDisabled
        self.fillsWidth = fillsWidth
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            label
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, AppTheme.spacingXL)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
                .frame(minHeight: 50)
                .background(
                    Capsule(style: .continuous)
                        .fill(AppTheme.brandGradient)
                        .opacity(isDisabled ? 0.5 : 1)
                )
                .shadow(color: AppTheme.accent.opacity(isDisabled ? 0 : 0.28), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .contentShape(Capsule(style: .continuous))
        .disabled(isDisabled)
    }

    @ViewBuilder
    private var label: some View {
        if let systemImage {
            Label(title, systemImage: systemImage)
        } else {
            Text(title)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        AppPrimaryButton("Start Chat", systemImage: "square.and.pencil") {}
        AppPrimaryButton("Disabled", isDisabled: true) {}
        AppPrimaryButton("Full Width", systemImage: "wand.and.stars", fillsWidth: true) {}
    }
    .padding()
}
