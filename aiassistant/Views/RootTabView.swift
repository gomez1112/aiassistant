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

            TabView(selection: $selectedTab) {
                Tab("Chat", systemImage: "bubble.left.and.bubble.right.fill", value: 0) {
                    ChatView(preferences: currentPreferences)
                }

                Tab("Outputs", systemImage: "doc.richtext", value: 1) {
                    OutputsView(preferences: currentPreferences)
                }

                Tab("Library", systemImage: "books.vertical.fill", value: 2) {
                    LibraryView(preferences: currentPreferences)
                }

            }
            .tabViewStyle(.sidebarAdaptable)
            .tint(AppTheme.accent)
            #if os(iOS)
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            #endif
        }
        .onAppear {
            preferences = dataModel.loadOrCreatePreferences(in: modelContext)
        }
    }

    private var currentPreferences: UserPreferences {
        preferences ?? .defaults
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
