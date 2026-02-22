// Views/Outputs/OutputsView.swift
// ai.assistant
//
// Tab 2: Browse, view, transform, and manage saved Artifacts.

import SwiftUI
import SwiftData

struct OutputsView: View {
    let preferences: UserPreferences

    @Environment(DataModel.self) private var dataModel
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Artifact.updatedAt, order: .reverse)
    private var artifacts: [Artifact]

    @State private var searchText = ""
    @State private var filterKind: ArtifactKind?
    #if !os(macOS)
    @State private var showSettings = false
    #endif

    private var filtered: [Artifact] {
        var result = artifacts
        if let kind = filterKind {
            result = result.filter { $0.kind == kind }
        }
        if !searchText.isEmpty {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            result = result.filter {
                $0.title.localizedStandardContains(query) ||
                $0.content.localizedStandardContains(query) ||
                $0.tags.contains(where: { $0.localizedStandardContains(query) })
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if artifacts.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "doc.richtext")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(AppTheme.accentGradient)
                        VStack(spacing: 8) {
                            Text("No outputs yet")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("Chat with \(preferences.ariEnabled ? "Ari" : "the assistant") and save responses as artifacts.\nThey'll appear here.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 0) {
                        // Filter chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                FilterChip(
                                    label: "All",
                                    icon: "tray.full",
                                    isSelected: filterKind == nil,
                                    action: { filterKind = nil }
                                )
                                ForEach(ArtifactKind.allCases) { kind in
                                    FilterChip(
                                        label: kind.rawValue,
                                        icon: kind.icon,
                                        isSelected: filterKind == kind,
                                        action: { filterKind = kind }
                                    )
                                }
                            }
                            .padding(.horizontal, AppTheme.spacingLG)
                            .padding(.vertical, 10)
                        }

                        // Artifacts list
                        List {
                            ForEach(filtered, id: \.id) { artifact in
                                NavigationLink(value: artifact.id) {
                                    ArtifactRow(artifact: artifact)
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            }
                            .onDelete { offsets in
                                for index in offsets {
                                    modelContext.delete(filtered[index])
                                }
                                try? modelContext.save()
                            }
                        }
                        .searchable(text: $searchText, prompt: "Search outputs")
                        .scrollContentBackground(.hidden)
                        .listStyle(.plain)
                    }
                    .navigationDestination(for: UUID.self) { id in
                        if let artifact = artifacts.first(where: { $0.id == id }) {
                            ArtifactDetailView(artifact: artifact, preferences: preferences)
                        }
                    }
                }
            }
            .navigationTitle("Outputs")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #if !os(macOS)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .fontWeight(.medium)
                    }
                    .accessibilityLabel("Settings")
                }
            }
            #endif
            #if os(iOS)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
            #if !os(macOS)
            .sheet(isPresented: $showSettings) {
                SettingsView(preferences: preferences)
            }
            #endif
        }
    }
}

// MARK: - Artifact Row

struct ArtifactRow: View {
    let artifact: Artifact

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: artifact.kind.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(artifact.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text(artifact.updatedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }

            Text(artifact.content.prefix(120).description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .lineSpacing(2)

            if !artifact.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(artifact.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(AppTheme.surface)
                            )
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(AppTheme.spacingMD)
        .appSurface()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected
                            ? AnyShapeStyle(AppTheme.accentGradient)
                            : AnyShapeStyle(AppTheme.surface)
                        )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(isSelected ? Color.clear : AppTheme.surfaceStroke, lineWidth: 0.5)
                )
                .foregroundStyle(isSelected ? .white : .secondary)
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - Preview

#Preview {
    OutputsView(preferences: .defaults)
        .environment(DataModel())
        .modelContainer(for: [
            Thread.self, Message.self, Artifact.self,
            LibraryItem.self, UserPreferences.self
        ], inMemory: true)
}
