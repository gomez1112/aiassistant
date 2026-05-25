// Views/Chat/ThreadListSheet.swift
// ai.assistant
//
// Sheet presenting the list of conversation threads
// with pin, delete, and new thread actions.

import SwiftUI

struct ThreadListSheet: View {
    let threads: [Thread]
    let onSelect: (Thread) -> Void
    let onDelete: (Thread) -> Void
    let onNew: () -> Void
    let onTogglePin: (Thread) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if threads.isEmpty {
                    ContentUnavailableView(
                        "No conversations yet",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Start a new chat to begin.")
                    )
                } else {
                    // Pinned
                    let pinned = threads.filter(\.pinned)
                    if !pinned.isEmpty {
                        Section("Pinned") {
                            ForEach(pinned, id: \.id) { thread in
                                threadRow(thread)
                            }
                            .onDelete { offsets in
                                for index in offsets {
                                    onDelete(pinned[index])
                                }
                            }
                        }
                    }

                    // Recent
                    let recent = threads.filter { !$0.pinned }
                    Section("Recent") {
                        ForEach(recent, id: \.id) { thread in
                            threadRow(thread)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                onDelete(recent[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("Chats")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
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
        }
        .accessibilityIdentifier("threadList.sheet")
    }

    @ViewBuilder
    private func threadRow(_ thread: Thread) -> some View {
        Button {
            onSelect(thread)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(thread.title)
                        .font(.subheadline)
                        .bold()
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    Spacer()

                    if thread.pinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.highlight)
                    }
                }

                Text(thread.lastMessagePreview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(thread.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(thread.title), \(thread.lastMessagePreview), \(thread.pinned ? "Pinned" : "Not pinned")")
        .accessibilityHint("Opens conversation")
        .accessibilityIdentifier("threadList.row.\(thread.id.uuidString)")
        .accessibilityAction(named: thread.pinned ? "Unpin" : "Pin") {
            onTogglePin(thread)
        }
        .swipeActions(edge: .leading) {
            Button {
                onTogglePin(thread)
            } label: {
                Label(
                    thread.pinned ? "Unpin" : "Pin",
                    systemImage: thread.pinned ? "pin.slash" : "pin"
                )
            }
            .tint(AppTheme.highlight)
        }
    }
}
