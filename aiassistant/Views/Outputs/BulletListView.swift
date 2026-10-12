import SwiftUI

// MARK: - Bullet List View

struct BulletListView: View {
    let content: String

    private var sections: [BulletSection] {
        parseBullets(from: content)
    }

    var body: some View {
        if sections.isEmpty || (sections.count == 1 && sections[0].items.isEmpty) {
            StyledTextView(content: content, kind: .checklist)
        } else {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(Array(sections.enumerated()), id: \.offset) { sIdx, section in
                    VStack(alignment: .leading, spacing: 12) {
                        // Section header
                        if let header = section.header {
                            Text(header)
                                .font(.subheadline.bold())
                                .foregroundStyle(AppTheme.accent)
                        }

                        // Bullet items
                        ForEach(Array(section.items.enumerated()), id: \.offset) { iIdx, item in
                            BulletRow(text: item, index: iIdx)
                        }
                    }
                }
            }
            .padding(AppTheme.spacingXL)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appSurface(cornerRadius: AppTheme.radiusCard)
        }
    }

    private func parseBullets(from text: String) -> [BulletSection] {
        var sections: [BulletSection] = []
        var currentHeader: String?
        var currentItems: [String] = []

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Section header (## Header)
            if trimmed.hasPrefix("## ") || trimmed.hasPrefix("### ") {
                if !currentItems.isEmpty || currentHeader != nil {
                    sections.append(BulletSection(header: currentHeader, items: currentItems))
                    currentItems = []
                }
                currentHeader = trimmed.replacingOccurrences(of: "^#{1,3}\\s*", with: "", options: .regularExpression)
            }
            // Bullet item
            else if trimmed.hasPrefix("• ") || trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let text = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "**", with: "")
                if !text.isEmpty {
                    currentItems.append(text)
                }
            }
            // Numbered item
            else if trimmed.range(of: #"^\d+[\.\)]\s"#, options: .regularExpression) != nil {
                let text = trimmed.replacingOccurrences(of: #"^\d+[\.\)]\s*"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: "**", with: "")
                if !text.isEmpty {
                    currentItems.append(text)
                }
            }
            // Plain text that isn't empty — treat as a bullet
            else {
                let text = trimmed.replacingOccurrences(of: "**", with: "")
                currentItems.append(text)
            }
        }

        if !currentItems.isEmpty || currentHeader != nil {
            sections.append(BulletSection(header: currentHeader, items: currentItems))
        }
        return sections
    }
}

struct BulletSection {
    let header: String?
    let items: [String]
}

struct BulletRow: View {
    let text: String
    let index: Int

    @State private var isChecked = false

    private var accentColor: Color {
        let colors: [Color] = [AppTheme.accent, AppTheme.highlight, AppTheme.success, AppTheme.accentLight]
        return colors[index % colors.count]
    }

    var body: some View {
        Toggle(isOn: $isChecked) {
            HStack(alignment: .top, spacing: AppTheme.spacingMD) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isChecked ? AppTheme.success : accentColor)
                    .accessibilityHidden(true)

                Text(text)
                    .font(.body)
                    .lineSpacing(3)
                    .strikethrough(isChecked)
                    .foregroundStyle(isChecked ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: AppTheme.minimumTapTarget, alignment: .leading)
            .contentShape(.rect)
        }
        .toggleStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel(text)
        .accessibilityValue(isChecked ? "Checked" : "Unchecked")
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isChecked)
    }
}
