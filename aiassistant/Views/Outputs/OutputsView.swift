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
    @State private var showPersistenceError = false
    #if !os(macOS)
    @State private var showSettings = false
    #endif

    private var filtered: [Artifact] {
        var result = artifacts
        if let kind = filterKind {
            result = result.filter { $0.kind == kind }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            result = result.filter {
                $0.title.localizedStandardContains(query) ||
                $0.content.localizedStandardContains(query) ||
                $0.tags.contains(where: { $0.localizedStandardContains(query) })
            }
        }
        return result
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                #if os(macOS)
                MacSearchHeader(
                    title: "Outputs",
                    subtitle: outputsSubtitle,
                    searchText: $searchText,
                    prompt: "Search outputs"
                ) {
                    EmptyView()
                }
                #endif

                Group {
                    if artifacts.isEmpty {
                        OutputsEmptyStateView(assistantName: preferences.ariEnabled ? "Ari" : "the assistant")
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

                            Group {
                                if filtered.isEmpty {
                                    unavailableFilteredState
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                } else {
                                    // Artifacts list
                                    List {
                                        ForEach(filtered, id: \.id) { artifact in
                                            NavigationLink(value: artifact.id) {
                                                ArtifactRow(artifact: artifact)
                                            }
                                            #if os(macOS)
                                            .listRowBackground(Color.clear)
                                            .listRowInsets(EdgeInsets(top: 2, leading: 18, bottom: 2, trailing: 18))
                                            #else
                                            .listRowBackground(Color.clear)
                                            .listRowSeparator(.hidden)
                                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                            #endif
                                        }
                                        .onDelete(perform: deleteArtifacts)
                                    }
                                    .scrollContentBackground(.hidden)
                                    .listStyle(.plain)
                                }
                            }
                            #if !os(macOS)
                            .searchable(text: $searchText, prompt: "Search outputs")
                            #endif
                        }
                        .navigationDestination(for: UUID.self) { id in
                            if let artifact = artifacts.first(where: { $0.id == id }) {
                                ArtifactDetailView(artifact: artifact, preferences: preferences)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Outputs")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #if !os(macOS)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Settings", systemImage: "gearshape") {
                        showSettings = true
                    }
                    .labelStyle(.iconOnly)
                }
            }
            #endif
            #if os(iOS)
            .toolbarBackground(AppTheme.groupedBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
            #if !os(macOS)
            .sheet(isPresented: $showSettings) {
                SettingsView(preferences: preferences)
            }
            #endif
            .alert("Couldn’t save changes", isPresented: $showPersistenceError) {
                Button("OK", role: .cancel) {
                    dataModel.persistenceErrorMessage = nil
                }
            } message: {
                Text(dataModel.persistenceErrorMessage ?? "Please try again.")
            }
            .onChange(of: dataModel.persistenceErrorMessage) { _, newValue in
                showPersistenceError = newValue != nil
            }
        }
    }

    private var outputsSubtitle: String {
        if artifacts.isEmpty {
            return "No saved outputs yet"
        }

        return "\(filtered.count) of \(artifacts.count) saved"
    }

    @ViewBuilder
    private var unavailableFilteredState: some View {
        if isSearching {
            ContentUnavailableView.search
        } else {
            ContentUnavailableView(
                "No \(filterKind?.rawValue.lowercased() ?? "matching") outputs",
                systemImage: filterKind?.icon ?? "tray",
                description: Text("Try a different output type.")
            )
        }
    }

    private func deleteArtifacts(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filtered[index])
        }
        dataModel.saveChanges(in: modelContext, source: "deleteOutput")
    }
}

// MARK: - Artifact Row

struct ArtifactRow: View {
    let artifact: Artifact

    var body: some View {
        #if os(macOS)
        HStack(alignment: .top, spacing: AppTheme.spacingMD) {
            AppIconBadge(systemImage: artifact.kind.icon, tint: AppTheme.accent, size: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: AppTheme.spacingSM) {
                    Text(artifact.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Text(artifact.updatedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Text(normalizedDisplayText(artifact.content).prefix(150).description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !artifact.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(artifact.tags.prefix(3), id: \.self) { tag in
                            AppTagPill(title: tag)
                        }
                    }
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, AppTheme.spacingSM)
        .accessibilityElement(children: .combine)
        #else
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AppIconBadge(systemImage: artifact.kind.icon, tint: AppTheme.accent, size: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(artifact.title)
                        .font(.subheadline)
                        .bold()
                        .lineLimit(1)
                    Text(artifact.updatedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }

            Text(normalizedDisplayText(artifact.content).prefix(120).description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .lineSpacing(2)

            if !artifact.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(artifact.tags.prefix(3), id: \.self) { tag in
                        AppTagPill(title: tag)
                    }
                }
            }
        }
        .padding(AppTheme.spacingMD)
        .appSurface()
        .accessibilityElement(children: .combine)
        #endif
    }
}

private struct OutputsEmptyStateView: View {
    let assistantName: String

    var body: some View {
        AppEmptyStateView(
            title: "No outputs yet",
            systemImage: "doc.richtext",
            description: "Chat with \(assistantName) and save responses as artifacts. They’ll appear here."
        )
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
                            ? AnyShapeStyle(AppTheme.accent)
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
        .environment(SubscriptionStore())
        .modelContainer(for: [
            Thread.self, Message.self, Artifact.self,
            LibraryItem.self, UserPreferences.self
        ], inMemory: true)
}
