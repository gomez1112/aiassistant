// Views/Library/LibraryView.swift
// ai.assistant
//
// Tab 3: Lightweight library for user-added source materials
// (notes, snippets, pasted text). Includes add/edit/summarize.

import SwiftUI
import SwiftData
import FlexStore

struct LibraryView: View {
    let preferences: UserPreferences

    @Environment(DataModel.self) private var dataModel
    @Environment(\.modelContext) private var modelContext

    @State private var showAddSheet = false
    @State private var searchText = ""
    @State private var showPersistenceError = false
    #if !os(macOS)
    @State private var showSettings = false
    #endif

    @Query(sort: \LibraryItem.updatedAt, order: .reverse)
    private var allItems: [LibraryItem]

    private var items: [LibraryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return allItems }

        return allItems.filter { item in
            item.title.localizedStandardContains(query) ||
            item.rawText.localizedStandardContains(query) ||
            (item.aiSummary?.localizedStandardContains(query) ?? false)
        }
    }

    private var totalItemCount: Int {
        allItems.count
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasAnyItems: Bool {
        totalItemCount > 0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                #if os(macOS)
                MacSearchHeader(
                    title: "Library",
                    subtitle: librarySubtitle,
                    searchText: $searchText,
                    prompt: "Search library"
                ) {
                    Button(action: presentAddSheet) {
                        Label("Add Item", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                }
                #endif

                Group {
                    if !hasAnyItems {
                        LibraryEmptyStateView(onAdd: presentAddSheet)
                    } else {
                        Group {
                            if items.isEmpty {
                                unavailableFilteredState
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                List {
                                    ForEach(items, id: \.id) { item in
                                        NavigationLink(value: item.id) {
                                            LibraryItemRow(item: item)
                                        }
                                        .contextMenu {
                                            Button("Copy", systemImage: "doc.on.doc") {
                                                Clipboard.copy(item.rawText)
                                            }
                                            Button("Delete", systemImage: "trash", role: .destructive) {
                                                deleteItem(item)
                                            }
                                        }
                                        .swipeActions(edge: .trailing) {
                                            Button("Delete", systemImage: "trash", role: .destructive) {
                                                deleteItem(item)
                                            }
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
                                    .onDelete(perform: deleteItems)
                                }
                                .scrollContentBackground(.hidden)
                                .listStyle(.plain)
                            }
                        }
                        #if !os(macOS)
                        .searchable(text: $searchText, prompt: "Search library")
                        #endif
                        .navigationDestination(for: UUID.self) { id in
                            if let item = allItems.first(where: { $0.id == id }) {
                                LibraryItemDetailView(item: item, preferences: preferences)
                            } else {
                                ContentUnavailableView(
                                    "Library item unavailable",
                                    systemImage: "exclamationmark.triangle",
                                    description: Text("The item may have been deleted or filtered out.")
                                )
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(AppBackground())
            .navigationTitle("Library")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Add library item", systemImage: "plus", action: presentAddSheet)
                        .labelStyle(.iconOnly)
                        .accessibilityLabel("Add library item")
                        .accessibilityIdentifier("library.toolbar.add")
                }
                ToolbarSpacer(.fixed)
                #if !os(macOS)
                ToolbarItem(placement: .automatic) {
                    Button("Settings", systemImage: "gearshape") {
                        showSettings = true
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityLabel("Settings")
                    .accessibilityIdentifier("library.toolbar.settings")
                }
                #endif
            }
            .sheet(isPresented: $showAddSheet) {
                AddLibraryItemSheet()
            }
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

    private var librarySubtitle: String {
        if !hasAnyItems {
            return "No source items yet"
        }

        return "\(items.count) of \(totalItemCount) source items"
    }

    @ViewBuilder
    private var unavailableFilteredState: some View {
        if isSearching {
            ContentUnavailableView.search
        } else {
            ContentUnavailableView(
                "No library items",
                systemImage: "books.vertical",
                description: Text("Try a different search.")
            )
        }
    }

    private func presentAddSheet() {
        showAddSheet = true
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
        dataModel.saveChanges(in: modelContext, source: "deleteLibraryItem")
    }

    private func deleteItem(_ item: LibraryItem) {
        modelContext.delete(item)
        dataModel.saveChanges(in: modelContext, source: "deleteLibraryItem")
    }
}

// MARK: - Library Item Row

struct LibraryItemRow: View {
    let item: LibraryItem

    var body: some View {
        #if os(macOS)
        HStack(alignment: .top, spacing: AppTheme.spacingMD) {
            AppIconBadge(systemImage: item.kind.icon, tint: AppTheme.accent, size: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: AppTheme.spacingSM) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    if item.aiSummary != nil {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                }

                Text(item.rawText.prefix(140).description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, AppTheme.spacingSM)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.kind.rawValue): \(item.title)")
        .accessibilityValue(accessibilityPreview)
        #else
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AppIconBadge(systemImage: item.kind.icon, tint: AppTheme.accent, size: 30)

                Text(item.title)
                    .font(.subheadline)
                    .bold()
                    .lineLimit(1)

                Spacer()

                if item.aiSummary != nil {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.accent)
                }
            }

            Text(item.rawText.prefix(100).description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .lineSpacing(2)
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
        .accessibilityLabel("\(item.kind.rawValue): \(item.title)")
        .accessibilityValue(accessibilityPreview)
        #endif
    }

    private var accessibilityPreview: String {
        var parts = [
            item.rawText.prefix(180).description,
            "Updated \(item.updatedAt.formatted(date: .abbreviated, time: .shortened))"
        ]
        if let summary = item.aiSummary, !summary.isEmpty {
            parts.append("Summary available")
        }
        return parts.joined(separator: ". ")
    }
}

private struct LibraryEmptyStateView: View {
    let onAdd: () -> Void

    var body: some View {
        AppEmptyStateView(
            title: "Your library is empty",
            systemImage: "books.vertical",
            description: "Add notes, snippets, or pasted text to use as source material in your chats.",
            actionTitle: "Add Item",
            actionSystemImage: "plus",
            actionAccessibilityIdentifier: "library.emptyState.add",
            action: onAdd
        )
    }
}
