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

    @Query(sort: \LibraryItem.updatedAt, order: .reverse)
    private var items: [LibraryItem]

    @State private var showAddSheet = false
    @State private var searchText = ""
    @State private var showPersistenceError = false
    #if !os(macOS)
    @State private var showSettings = false
    #endif

    private var filtered: [LibraryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.title.localizedStandardContains(query) ||
            $0.rawText.localizedStandardContains(query)
        }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    LibraryEmptyStateView(onAdd: presentAddSheet)
                } else {
                    Group {
                        if filtered.isEmpty {
                            unavailableFilteredState
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            List {
                                ForEach(filtered, id: \.id) { item in
                                    NavigationLink(value: item.id) {
                                        LibraryItemRow(item: item)
                                    }
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                }
                                .onDelete(perform: deleteItems)
                            }
                            .scrollContentBackground(.hidden)
                            .listStyle(.plain)
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search library")
                    .navigationDestination(for: UUID.self) { id in
                        if let item = items.first(where: { $0.id == id }) {
                            LibraryItemDetailView(item: item, preferences: preferences)
                        }
                    }
                }
            }
            .navigationTitle("Library")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Add library item", systemImage: "plus", action: presentAddSheet)
                        .labelStyle(.iconOnly)
                }
                ToolbarSpacer(.fixed)
                #if !os(macOS)
                ToolbarItem(placement: .automatic) {
                    Button("Settings", systemImage: "gearshape") {
                        showSettings = true
                    }
                    .labelStyle(.iconOnly)
                }
                #endif
            }
            #if os(iOS)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
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
            modelContext.delete(filtered[index])
        }
        dataModel.saveChanges(in: modelContext, source: "deleteLibraryItem")
    }
}

// MARK: - Library Item Row

struct LibraryItemRow: View {
    let item: LibraryItem

    var body: some View {
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
        .appSurface()
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
            action: onAdd
        )
    }
}

private struct LibrarySummaryCard: View {
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("AI Summary", systemImage: "sparkles")
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.accent)
            Text(summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
        }
        .padding(AppTheme.spacingLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appSurface()
    }
}

// MARK: - Add Library Item Sheet

struct AddLibraryItemSheet: View {
    @Environment(DataModel.self) private var dataModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var kind: LibraryItemKind = .note
    @State private var rawText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    Picker("Type", selection: $kind) {
                        ForEach(LibraryItemKind.allCases) { k in
                            Label(k.rawValue, systemImage: k.icon).tag(k)
                        }
                    }
                }
                Section("Content") {
                    TextField("Paste notes, snippets, or source text", text: $rawText, axis: .vertical)
                        .lineLimit(8...18)
                        .accessibilityLabel("Content")
                }
            }
            .navigationTitle("Add to Library")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                    .disabled(rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .bold()
                }
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = LibraryItem(
            title: trimmedTitle.isEmpty ? "Untitled" : trimmedTitle,
            kind: kind,
            rawText: rawText
        )
        modelContext.insert(item)
        if dataModel.saveChanges(in: modelContext, source: "addLibraryItem") {
            dismiss()
        }
    }
}

// MARK: - Library Item Detail View

struct LibraryItemDetailView: View {
    @Bindable var item: LibraryItem
    let preferences: UserPreferences

    @Environment(DataModel.self) private var dataModel
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreKitService<AppSubscriptionTier>.self) private var storeKitService

    @State private var isSummarizing = false
    @State private var showPaywall = false
    @State private var showUpgradeAlert = false
    @State private var upgradePromptMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    AppIconBadge(systemImage: item.kind.icon, tint: AppTheme.accent, size: 42)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.title3)
                            .bold()
                        Text(item.kind.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                // Content card
                VStack(alignment: .leading) {
                    Text(item.rawText)
                        .font(.body)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                }
                .padding(AppTheme.spacingLG)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appSurface()

                // AI Summary
                if let summary = item.aiSummary {
                    LibrarySummaryCard(summary: summary)
                }

                // Metadata
                HStack {
                    Text("Created")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text(item.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }
            .padding(AppTheme.spacingLG)
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    summarize()
                } label: {
                    Label(
                        isSummarizing ? "Summarizing…" : "Summarize with AI",
                        systemImage: "sparkles"
                    )
                }
                .disabled(isSummarizing || item.rawText.isEmpty)
            }
        }
        .overlay {
            if isSummarizing {
                ProgressView("Summarizing…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .sheet(isPresented: $showPaywall) {
            SubscriptionPaywallView()
        }
        .alert("Upgrade to Ari+", isPresented: $showUpgradeAlert) {
            Button("Not Now", role: .cancel) {}
            Button("Upgrade") { showPaywall = true }
        } message: {
            Text(upgradePromptMessage)
        }
    }

    private func summarize() {
        guard storeKitService.hasPremiumAccess else {
            upgradePromptMessage = "AI summaries for Library items are available on Ari+ plans."
            showUpgradeAlert = true
            return
        }

        isSummarizing = true
        Task {
            await dataModel.summarizeItem(item, in: modelContext)
            isSummarizing = false
        }
    }
}

// MARK: - Preview

#Preview {
    LibraryView(preferences: .defaults)
        .environment(DataModel())
        .modelContainer(for: [
            Thread.self, Message.self, Artifact.self,
            LibraryItem.self, UserPreferences.self
        ], inMemory: true)
}
