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
    #if DEBUG
    @Environment(\.marketingCapture) private var capture
    #endif

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
            #if DEBUG
            if let capture {
                do { try capture.prepare(in: modelContext, model: dataModel) }
                catch { dataModel.persistenceErrorMessage = error.localizedDescription }
                selectedTab = capture.tab
            }
            #endif
            preferences = dataModel.loadOrCreatePreferences(in: modelContext)
        }
        #if DEBUG
        .task { await capture?.runTour() }
        .onChange(of: capture?.scene) {
            if let capture {
                capture.selectConversation(in: dataModel)
                selectedTab = capture.tab
            }
        }
        #endif
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
