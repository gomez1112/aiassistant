import SwiftUI

struct AppPrimaryButton: View {
    let title: String
    let systemImage: String?
    let isDisabled: Bool
    let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            button
                .buttonStyle(.glassProminent)
                .tint(AppTheme.accent)
        } else {
            button
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(AppTheme.accent)
        }
    }

    private var button: some View {
        Button(action: action) {
            label
                .font(.subheadline.bold())
                .frame(minHeight: AppTheme.minimumTapTarget)
        }
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
