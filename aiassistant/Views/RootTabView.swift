// Views/RootTabView.swift
// ai.assistant
//
// Main tab navigation with 3 tabs: Chat, Outputs, Library.

import SwiftUI
import SwiftData
import StoreKit
import FlexStore

@available(iOS 27.0, macOS 27.0, *)
struct RootTabView: View {
    @Environment(DataModel.self) private var dataModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview

    @State private var selectedTab: AppTab = .chat
    @State private var preferences: UserPreferences?

    var body: some View {
        Group {
            if let preferences {
                TabView(selection: $selectedTab) {
                    Tab(AppTab.chat.title, systemImage: AppTab.chat.systemImage, value: AppTab.chat) {
                        ChatView(preferences: preferences)
                            .accessibilityIdentifier("tab.chat.content")
                    }

                    Tab(AppTab.outputs.title, systemImage: AppTab.outputs.systemImage, value: AppTab.outputs) {
                        OutputsView(preferences: preferences)
                            .accessibilityIdentifier("tab.outputs.content")
                    }

                    Tab(AppTab.library.title, systemImage: AppTab.library.systemImage, value: AppTab.library) {
                        LibraryView(preferences: preferences)
                            .accessibilityIdentifier("tab.library.content")
                    }
                }
                .tabViewStyle(.sidebarAdaptable)
                #if os(iOS)
                .defaultTabBarPlacement(.sidebar)
                #endif
                .tint(AppTheme.accent)
            } else {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.appBackground)
            }
        }
        .task {
            preferences = dataModel.loadOrCreatePreferences(in: modelContext)
        }
        .task(id: dataModel.review.isReviewRequestPending) {
            guard dataModel.review.isReviewRequestPending else { return }
            // Cancel the delayed prompt when its window disappears.
            do {
                try await Task.sleep(for: .seconds(0.7))
                try Task.checkCancellation()
                requestReview()
                dataModel.review.reviewRequestPresented()
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }
    }

}
