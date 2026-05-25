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
    @State private var items: [LibraryItem] = []
    @State private var totalItemCount = 0
    @State private var showPersistenceError = false
    #if !os(macOS)
    @State private var showSettings = false
    #endif

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
                            if let item = items.first(where: { $0.id == id }) {
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
            #if os(iOS)
            .toolbarBackground(AppTheme.groupedBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
            .sheet(isPresented: $showAddSheet, onDismiss: refreshItems) {
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
            .onAppear(perform: refreshItems)
            .onChange(of: searchText) { _, _ in refreshItems() }
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
        refreshItems()
    }

    private func refreshItems() {
        do {
            totalItemCount = try modelContext.fetchCount(FetchDescriptor<LibraryItem>())
            items = try modelContext.fetch(libraryFetchDescriptor())
        } catch {
            dataModel.persistenceErrorMessage = "Could not load library items. \(error.localizedDescription)"
        }
    }

    private func libraryFetchDescriptor() -> FetchDescriptor<LibraryItem> {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let sort = [SortDescriptor(\LibraryItem.updatedAt, order: .reverse)]

        guard !query.isEmpty else {
            return FetchDescriptor<LibraryItem>(sortBy: sort)
        }

        return FetchDescriptor<LibraryItem>(
            predicate: #Predicate<LibraryItem> { item in
                item.title.localizedStandardContains(query) ||
                item.rawText.localizedStandardContains(query) ||
                (item.aiSummary?.localizedStandardContains(query) ?? false)
            },
            sortBy: sort
        )
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
        .appSurface()
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
    @Environment(StoreKitService<AppSubscriptionTier>.self) private var flexStore

    @State private var isSummarizing = false
    @State private var showPaywall = false
    @State private var summaryErrorMessage: String?
    @State private var summaryTask: Task<Void, Never>?

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
        .safeAreaPadding(.bottom, 72)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
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
                    .background(AppTheme.surfaceFill, in: RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                            .stroke(AppTheme.surfaceStroke, lineWidth: 0.6)
                    )
            }
        }
        .sheet(isPresented: $showPaywall) {
            SubscriptionPaywallView(context: .librarySummary)
        }
        .alert("Couldn’t summarize item", isPresented: summaryErrorBinding) {
            Button("OK", role: .cancel) {
                summaryErrorMessage = nil
            }
        } message: {
            Text(summaryErrorMessage ?? "Please try again.")
        }
        .onDisappear {
            summaryTask?.cancel()
        }
    }

    private func summarize() {
        guard hasPremiumAccess else {
            showPaywall = true
            return
        }

        summaryTask?.cancel()
        isSummarizing = true
        summaryTask = Task {
            defer {
                isSummarizing = false
                summaryTask = nil
            }
            let outcome = await dataModel.summarizeItem(item, in: modelContext)
            guard !Task.isCancelled else { return }

            switch outcome {
            case .completed, .cancelled:
                break
            case .failed(let message):
                summaryErrorMessage = message
            }
        }
    }

    private var hasPremiumAccess: Bool {
        flexStore.isSubscribed || flexStore.purchasedNonConsumables.contains(Monetization.lifetimeID)
    }

    private var summaryErrorBinding: Binding<Bool> {
        Binding(
            get: { summaryErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    summaryErrorMessage = nil
                }
            }
        )
    }
}

// MARK: - Preview

#Preview {
        LibraryView(preferences: .defaults)
            .environment(DataModel())
        .environment(StoreKitService<AppSubscriptionTier>())
        .modelContainer(for: [
            Thread.self, Message.self, Artifact.self,
            LibraryItem.self, UserPreferences.self
        ], inMemory: true)
}
