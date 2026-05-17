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
        Group {
            if let preferences {
                #if os(macOS)
                HStack(spacing: 0) {
                    MacAppSidebar(selectedTab: $selectedTab)

                    Divider()

                    selectedContent(for: preferences)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppTheme.appBackground)
                }
                .background(AppTheme.appBackground)
                #else
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
                .tint(AppTheme.accent)
                .toolbarBackground(AppTheme.groupedBackground, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                #endif
            } else {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.appBackground)
            }
        }
        .onAppear {
            preferences = dataModel.loadOrCreatePreferences(in: modelContext)
        }
    }

    @ViewBuilder
    private func selectedContent(for preferences: UserPreferences) -> some View {
        switch selectedTab {
        case .chat:
            ChatView(preferences: preferences)
        case .outputs:
            OutputsView(preferences: preferences)
        case .library:
            LibraryView(preferences: preferences)
        }
    }
}

#if os(macOS)
private struct MacAppSidebar: View {
    @Binding var selectedTab: AppTab

    private let tabs: [AppTab] = [.chat, .outputs, .library]

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingLG) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Ari")
                    .font(.title3.weight(.semibold))

                Text("Workspace")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, AppTheme.spacingMD)
            .padding(.top, AppTheme.spacingLG)

            VStack(spacing: AppTheme.spacingXS) {
                ForEach(tabs, id: \.self) { tab in
                    MacSidebarTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        selectedTab = tab
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.spacingSM)
        .padding(.bottom, AppTheme.spacingLG)
        .frame(width: 188)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(AppTheme.macSidebarBackground)
    }
}

private struct MacSidebarTabButton: View {
    let tab: AppTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(tab.title, systemImage: tab.systemImage)
                .font(.callout.weight(isSelected ? .semibold : .regular))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(isSelected ? AnyShapeStyle(AppTheme.accent) : AnyShapeStyle(.primary))
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 34)
                .padding(.horizontal, AppTheme.spacingSM)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                        .fill(isSelected ? AppTheme.accent.opacity(0.12) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous))
    }
}
#endif

// MARK: - Preview

#Preview {
    RootTabView()
        .environment(DataModel())
        .environment(SubscriptionStore())
        .modelContainer(for: [
            Thread.self, Message.self, Artifact.self,
            LibraryItem.self, UserPreferences.self
        ], inMemory: true)
}
