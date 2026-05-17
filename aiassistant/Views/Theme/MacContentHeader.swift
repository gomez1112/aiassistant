import SwiftUI

#if os(macOS)
struct MacPlainHeader<Actions: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.spacingLG) {
            titleBlock

            Spacer(minLength: AppTheme.spacingLG)

            actions()
        }
        .padding(.horizontal, AppTheme.spacingXL)
        .padding(.vertical, AppTheme.spacingLG)
        .background(AppTheme.appBackground)
        .overlay(Divider().opacity(0.65), alignment: .bottom)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct MacSearchHeader<Actions: View>: View {
    let title: String
    let subtitle: String?
    @Binding var searchText: String
    let prompt: String
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.spacingLG) {
            titleBlock

            Spacer(minLength: AppTheme.spacingLG)

            HStack(spacing: AppTheme.spacingMD) {
                MacSearchField(text: $searchText, prompt: prompt)
                actions()
            }
        }
        .padding(.horizontal, AppTheme.spacingXL)
        .padding(.vertical, AppTheme.spacingLG)
        .background(AppTheme.appBackground)
        .overlay(Divider().opacity(0.65), alignment: .bottom)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct MacSearchField: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: AppTheme.spacingSM) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .frame(width: 220)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, AppTheme.spacingMD)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                .fill(AppTheme.surfaceFill)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                        .stroke(AppTheme.surfaceStroke, lineWidth: 0.6)
                )
        )
    }
}
#endif
