// Views/Outputs/OutputsView.swift
// ai.assistant
//
// Tab 2: Browse, view, transform, and manage saved Artifacts.

import SwiftUI
import SwiftData
import FlexStore

struct OutputsView: View {
    let preferences: UserPreferences

    @Environment(DataModel.self) private var dataModel
    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var filterKind: ArtifactKind?
    @State private var artifacts: [Artifact] = []
    @State private var totalArtifactCount = 0
    @State private var showPersistenceError = false
    #if !os(macOS)
    @State private var showSettings = false
    #endif

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasAnyArtifacts: Bool {
        totalArtifactCount > 0
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
                    if !hasAnyArtifacts {
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
                                if artifacts.isEmpty {
                                    unavailableFilteredState
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                } else {
                                    // Artifacts list
                                    List {
                                        ForEach(artifacts, id: \.id) { artifact in
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
                            } else {
                                ContentUnavailableView(
                                    "Output unavailable",
                                    systemImage: "exclamationmark.triangle",
                                    description: Text("The output may have been deleted or filtered out.")
                                )
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(AppBackground())
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
                    .accessibilityLabel("Settings")
                    .accessibilityIdentifier("outputs.toolbar.settings")
                }
            }
            #endif
            #if os(iOS)
            .toolbarBackground(AppTheme.appBackground, for: .navigationBar)
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
            .onAppear(perform: refreshArtifacts)
            .onChange(of: searchText) { _, _ in refreshArtifacts() }
            .onChange(of: filterKind) { _, _ in refreshArtifacts() }
        }
    }

    private var outputsSubtitle: String {
        if !hasAnyArtifacts {
            return "No saved outputs yet"
        }

        return "\(artifacts.count) of \(totalArtifactCount) saved"
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
            modelContext.delete(artifacts[index])
        }
        dataModel.saveChanges(in: modelContext, source: "deleteOutput")
        refreshArtifacts()
    }

    private func refreshArtifacts() {
        do {
            totalArtifactCount = try modelContext.fetchCount(FetchDescriptor<Artifact>())
            artifacts = try modelContext.fetch(artifactFetchDescriptor())
        } catch {
            dataModel.persistenceErrorMessage = "Could not load outputs. \(error.localizedDescription)"
        }
    }

    private func artifactFetchDescriptor() -> FetchDescriptor<Artifact> {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let sort = [SortDescriptor(\Artifact.updatedAt, order: .reverse)]

        switch (filterKind?.rawValue, query.isEmpty) {
        case (.some(let kindRaw), false):
            return FetchDescriptor<Artifact>(
                predicate: #Predicate<Artifact> { artifact in
                    artifact.kindRaw == kindRaw &&
                    (
                        artifact.title.localizedStandardContains(query) ||
                        artifact.content.localizedStandardContains(query) ||
                        artifact.tagsRaw.localizedStandardContains(query)
                    )
                },
                sortBy: sort
            )
        case (.some(let kindRaw), true):
            return FetchDescriptor<Artifact>(
                predicate: #Predicate<Artifact> { artifact in
                    artifact.kindRaw == kindRaw
                },
                sortBy: sort
            )
        case (.none, false):
            return FetchDescriptor<Artifact>(
                predicate: #Predicate<Artifact> { artifact in
                    artifact.title.localizedStandardContains(query) ||
                    artifact.content.localizedStandardContains(query) ||
                    artifact.tagsRaw.localizedStandardContains(query)
                },
                sortBy: sort
            )
        case (.none, true):
            return FetchDescriptor<Artifact>(sortBy: sort)
        }
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
        .accessibilityLabel("\(artifact.kind.rawValue): \(artifact.title)")
        .accessibilityValue(accessibilityPreview)
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
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                .fill(AppTheme.surfaceFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                .stroke(AppTheme.surfaceStroke, lineWidth: 0.7)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(artifact.kind.rawValue): \(artifact.title)")
        .accessibilityValue(accessibilityPreview)
        #endif
    }

    private var accessibilityPreview: String {
        var parts = [
            normalizedDisplayText(artifact.content).prefix(180).description,
            "Updated \(artifact.updatedAt.formatted(date: .abbreviated, time: .shortened))"
        ]
        if !artifact.tags.isEmpty {
            parts.append("Tags: \(artifact.tags.prefix(3).joined(separator: ", "))")
        }
        return parts.joined(separator: ". ")
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
                .font(.caption.weight(isSelected ? .semibold : .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .frame(minHeight: AppTheme.minimumTapTarget)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected
                            ? AnyShapeStyle(AppTheme.accent)
                            : AnyShapeStyle(AppTheme.surface)
                        )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(isSelected ? .white.opacity(0.18) : AppTheme.surfaceStroke, lineWidth: 0.7)
                )
                .foregroundStyle(isSelected ? .white : .secondary)
                .shadow(color: isSelected ? AppTheme.accentDeep.opacity(0.16) : .clear, radius: 8, y: 3)
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
        .environment(StoreKitService<AppSubscriptionTier>())
        .modelContainer(for: [
            Thread.self, Message.self, Artifact.self,
            LibraryItem.self, UserPreferences.self
        ], inMemory: true)
}
