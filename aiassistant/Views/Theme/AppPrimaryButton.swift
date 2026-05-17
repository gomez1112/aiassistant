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
        button
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(AppTheme.accent)
    }

    private var button: some View {
        Button(action: action) {
            label
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: fillsWidth ? .infinity : nil)
                .frame(minHeight: 44)
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
