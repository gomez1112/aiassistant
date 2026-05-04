// Views/RootTabView.swift
// ai.assistant
//
// Main tab navigation with 3 tabs: Chat, Outputs, Library.

import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(DataModel.self) private var dataModel
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTab: AppTab = .chat
    @State private var preferences: UserPreferences?

    var body: some View {
        ZStack {
            AppBackground()

            if let preferences {
                TabView(selection: $selectedTab) {
                    Tab(AppTab.chat.title, systemImage: AppTab.chat.systemImage, value: AppTab.chat) {
                        ChatView(preferences: preferences)
                    }

                    Tab(AppTab.outputs.title, systemImage: AppTab.outputs.systemImage, value: AppTab.outputs) {
                        OutputsView(preferences: preferences)
                    }

                    Tab(AppTab.library.title, systemImage: AppTab.library.systemImage, value: AppTab.library) {
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
