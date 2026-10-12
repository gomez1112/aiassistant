import SwiftUI
import SwiftData
import FlexStore

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
    @State private var activeSummaryID: UUID?

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
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(.hidden, for: .tabBar)
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
        .alert("Couldn’t summarize item", item: $summaryErrorMessage) { _ in } message: { message in
            Text(message)
        }
        .onDisappear {
            cancelSummary()
        }
        .onChange(of: hasPremiumAccess) {
            if !hasPremiumAccess { cancelSummary() }
        }
    }

    private func summarize() {
        guard hasPremiumAccess else {
            showPaywall = true
            return
        }

        summaryTask?.cancel()
        let summaryID = UUID()
        activeSummaryID = summaryID
        isSummarizing = true
        summaryTask = Task {
            defer {
                if activeSummaryID == summaryID {
                    isSummarizing = false
                    summaryTask = nil
                    activeSummaryID = nil
                }
            }
            let outcome = await dataModel.summarizeItem(item, in: modelContext)
            guard !Task.isCancelled, activeSummaryID == summaryID else { return }

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

    private func cancelSummary() {
        summaryTask?.cancel()
        summaryTask = nil
        activeSummaryID = nil
        isSummarizing = false
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
