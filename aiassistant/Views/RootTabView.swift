// Views/RootTabView.swift
// ai.assistant
//
// Main tab navigation with 3 tabs: Chat, Outputs, Library.

import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(DataModel.self) private var dataModel
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTab = 0
    @State private var preferences: UserPreferences?

    var body: some View {
        ZStack {
            AppBackground()

            if let preferences {
                TabView(selection: $selectedTab) {
                    Tab("Chat", systemImage: "bubble.left.and.bubble.right.fill", value: 0) {
                        ChatView(preferences: preferences)
                    }

                    Tab("Outputs", systemImage: "doc.richtext", value: 1) {
                        OutputsView(preferences: preferences)
                    }

                    Tab("Library", systemImage: "books.vertical.fill", value: 2) {
                        LibraryView(preferences: preferences)
                    }

                }
                .tabViewStyle(.sidebarAdaptable)
                .tint(AppTheme.accent)
                #if os(iOS)
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                #endif
            } else {
                ProgressView("Loading…")
            }
        }
        .onAppear {
            preferences = dataModel.loadOrCreatePreferences(in: modelContext)
        }
    }
}

// MARK: - Preview

#Preview {
    RootTabView()
        .environment(DataModel())
        .modelContainer(for: [
            Thread.self, Message.self, Artifact.self,
            LibraryItem.self, UserPreferences.self
        ], inMemory: true)
}
