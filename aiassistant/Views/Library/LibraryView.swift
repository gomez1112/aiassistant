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
    #if !os(macOS)
    @State private var showSettings = false
    #endif

    private var filtered: [LibraryItem] {
        guard !searchText.isEmpty else { return items }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter {
            $0.title.localizedStandardContains(query) ||
            $0.rawText.localizedStandardContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "books.vertical")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(AppTheme.accentGradient)
                        VStack(spacing: 8) {
                            Text("Your library is empty")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("Add notes, snippets, or pasted text\nto use as source material in your chats.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                        }
                        Button {
                            showAddSheet = true
                        } label: {
                            Text("Add Item")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 10)
                                .background(AppTheme.accentGradient, in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
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
                        .onDelete { offsets in
                            for index in offsets {
                                modelContext.delete(filtered[index])
                            }
                            try? modelContext.save()
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search library")
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)
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
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.medium)
                    }
                    .accessibilityLabel("Add library item")
                }
                ToolbarSpacer(.fixed)
                #if !os(macOS)
                ToolbarItem(placement: .automatic) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .fontWeight(.medium)
                    }
                    .accessibilityLabel("Settings")
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
        }
    }
}

// MARK: - Library Item Row

struct LibraryItemRow: View {
    let item: LibraryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: item.kind.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
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

// MARK: - Add Library Item Sheet

struct AddLibraryItemSheet: View {
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
                    TextEditor(text: $rawText)
                        .frame(minHeight: 200)
                        .accessibilityLabel("Content text editor")
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
                    Button("Save") {
                        let item = LibraryItem(
                            title: title.isEmpty ? "Untitled" : title,
                            kind: kind,
                            rawText: rawText
                        )
                        modelContext.insert(item)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
                }
            }
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
                    Image(systemName: item.kind.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 40, height: 40)
                        .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.title3)
                            .fontWeight(.bold)
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
                    VStack(alignment: .leading, spacing: 8) {
                        Label("AI Summary", systemImage: "sparkles")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppTheme.accent)
                        Text(summary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                    }
                    .padding(AppTheme.spacingLG)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                            .fill(AppTheme.accent.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                            .stroke(AppTheme.accent.opacity(0.15), lineWidth: 0.5)
                    )
                }

                // Metadata
                HStack {
                    Text("Created")
                        .font(.caption2)
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
