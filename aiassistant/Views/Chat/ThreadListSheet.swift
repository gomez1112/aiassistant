// Views/Chat/ThreadListSheet.swift
// ai.assistant
//
// Sheet presenting the list of conversation threads
// with search, pin, delete, and new thread actions.

import SwiftUI

struct ThreadListSheet: View {
    let threads: [Thread]
    let activeThreadID: UUID?
    let onSelect: (Thread) -> Void
    let onDelete: (Thread) -> Void
    let onNew: () -> Void
    let onTogglePin: (Thread) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var threadPendingDeletion: Thread?

    private var filteredThreads: [Thread] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return threads }
        return threads.filter { thread in
            thread.title.localizedStandardContains(query) ||
            thread.lastMessagePreview.localizedStandardContains(query)
        }
    }

    private var pinnedThreads: [Thread] {
        filteredThreads.filter(\.pinned)
    }

    private var recentThreads: [Thread] {
        filteredThreads.filter { !$0.pinned }
    }

    var body: some View {
        NavigationStack {
            Group {
                if threads.isEmpty {
                    ContentUnavailableView(
                        "No conversations yet",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Start a new chat to begin.")
                    )
                } else if filteredThreads.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    threadList
                }
            }
            .navigationTitle("Chats")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .searchable(text: $searchText, prompt: "Search chats")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("threadList.done")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New chat", systemImage: "plus", action: onNew)
                        .labelStyle(.iconOnly)
                        .accessibilityLabel("New chat")
                        .accessibilityIdentifier("threadList.newChat")
                }
            }
            .confirmationDialog(
                "Delete this chat?",
                isPresented: Binding(
                    get: { threadPendingDeletion != nil },
                    set: { if !$0 { threadPendingDeletion = nil } }
                ),
                titleVisibility: .visible,
                presenting: threadPendingDeletion
            ) { thread in
                Button("Delete Chat", role: .destructive) {
                    onDelete(thread)
                }
                Button("Cancel", role: .cancel) {}
            } message: { thread in
                Text("“\(thread.title)” and its messages will be removed. Saved outputs are kept.")
            }
        }
        .accessibilityIdentifier("threadList.sheet")
    }

    private var threadList: some View {
        List {
            if !pinnedThreads.isEmpty {
                Section("Pinned") {
                    ForEach(pinnedThreads, id: \.id) { thread in
                        ThreadRow(
                            thread: thread,
                            isActive: thread.id == activeThreadID,
                            onSelect: { onSelect(thread) },
                            onTogglePin: { onTogglePin(thread) },
                            onDelete: { threadPendingDeletion = thread }
                        )
                    }
                }
            }

            if !recentThreads.isEmpty {
                Section("Recent") {
                    ForEach(recentThreads, id: \.id) { thread in
                        ThreadRow(
                            thread: thread,
                            isActive: thread.id == activeThreadID,
                            onSelect: { onSelect(thread) },
                            onTogglePin: { onTogglePin(thread) },
                            onDelete: { threadPendingDeletion = thread }
                        )
                    }
                }
            }
        }
    }
}

private struct ThreadRow: View {
    let thread: Thread
    let isActive: Bool
    let onSelect: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    private var preview: String {
        normalizedDisplayText(thread.lastMessagePreview)
            .replacing("\n", with: " ")
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: AppTheme.spacingMD) {
                VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                    Text(thread.title)
                        .font(.subheadline.weight(isActive ? .semibold : .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(preview)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Text(thread.updatedAt, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: AppTheme.spacingSM) {
                    if thread.pinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.accent)
                            .accessibilityHidden(true)
                    }
                    if isActive {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                            .accessibilityHidden(true)
                    }
                }
            }
            .padding(.vertical, AppTheme.spacingXS)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(thread.title), \(preview)")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Opens conversation")
        .accessibilityIdentifier("threadList.row.\(thread.id.uuidString)")
        .accessibilityAction(named: thread.pinned ? "Unpin" : "Pin", onTogglePin)
        .accessibilityAction(named: "Delete", onDelete)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(thread.pinned ? "Unpin" : "Pin", systemImage: thread.pinned ? "pin.slash" : "pin", action: onTogglePin)
                .tint(AppTheme.accent)
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
        .contextMenu {
            Button(thread.pinned ? "Unpin" : "Pin", systemImage: thread.pinned ? "pin.slash" : "pin", action: onTogglePin)
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }

    private var accessibilityValue: String {
        var parts: [String] = []
        if isActive { parts.append("Current chat") }
        if thread.pinned { parts.append("Pinned") }
        return parts.joined(separator: ", ")
    }
}
