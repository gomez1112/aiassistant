// Views/Outputs/ArtifactDetailView.swift
// ai.assistant
//
// Detail view for a single Artifact with actions:
// copy, transform, edit tags, delete.

import SwiftUI
import SwiftData
import FlexStore

struct ArtifactDetailView: View {
    @Bindable var artifact: Artifact
    let preferences: UserPreferences

    @Environment(DataModel.self) private var dataModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(StoreKitService<AppSubscriptionTier>.self) private var flexStore

    @Query(sort: \Artifact.updatedAt, order: .reverse)
    private var artifacts: [Artifact]

    @State private var isTransforming = false
    @State private var showTagEditor = false
    @State private var showDeleteConfirmation = false
    @State private var copiedFeedback = false
    @State private var showPaywall = false
    @State private var showPersistenceError = false
    @State private var transformErrorMessage: String?
    @State private var transformTask: Task<Void, Never>?
    @State private var activeTransformID: UUID?
    @State private var navigationTarget: ArtifactNavigationTarget?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    AppIconBadge(systemImage: artifact.kind.icon, tint: AppTheme.accent, size: 42)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(artifact.title)
                            .font(.title3)
                            .bold()
                        Text(artifact.kind.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                // Tags
                if !artifact.tags.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(artifact.tags, id: \.self) { tag in
                            AppTagPill(title: tag)
                        }
                    }
                }

                // Content
                ArtifactContentView(artifact: artifact)

                // Metadata
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Created")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(artifact.createdAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Updated")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(artifact.updatedAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
            ToolbarItem(placement: .automatic) {
                Button {
                    Clipboard.copy(artifact.content)
                    copiedFeedback = true
                } label: {
                    Label(copiedFeedback ? "Copied!" : "Copy", systemImage: "doc.on.doc")
                }
                .accessibilityIdentifier("output.detail.copy")
            }
            
            ToolbarItem(placement: .automatic) {
                Button {
                    showTagEditor = true
                } label: {
                    Label("Tags", systemImage: "tag")
                }
                .accessibilityIdentifier("output.detail.tags")
            }
            ToolbarSpacer(.fixed)
            ToolbarItem(placement: .automatic) {
                Menu {
                    ForEach(TransformType.allCases) { type in
                        Button {
                            transformArtifact(type: type)
                        } label: {
                            Label(type.rawValue, systemImage: type.icon)
                        }
                    }
                } label: {
                    Label("Transform", systemImage: "wand.and.stars")
                }
                .disabled(isTransforming)
                .accessibilityIdentifier("output.detail.transform")
            }
            ToolbarSpacer(.fixed)
            ToolbarItem(placement: .automatic) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .accessibilityIdentifier("output.detail.delete")
            }
        }
        .overlay {
            if isTransforming {
                ProgressView("Transforming…")
                    .padding()
                    .background(AppTheme.surfaceFill, in: RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                            .stroke(AppTheme.surfaceStroke, lineWidth: 0.6)
                    )
            }
        }
        .sensoryFeedback(.success, trigger: copiedFeedback)
        .task(id: copiedFeedback) {
            guard copiedFeedback else { return }
            do {
                try await Task.sleep(for: .seconds(1.5))
                copiedFeedback = false
            } catch { return }
        }
        .alert("Delete Artifact?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(artifact)
                if dataModel.saveChanges(in: modelContext, source: "deleteArtifact") {
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .sheet(isPresented: $showTagEditor) {
            TagEditorSheet(artifact: artifact)
        }
        .sheet(isPresented: $showPaywall) {
            SubscriptionPaywallView(context: .outputStudio)
        }
        .alert("Couldn’t save changes", isPresented: $showPersistenceError) {
            Button("OK", role: .cancel) {
                dataModel.persistenceErrorMessage = nil
            }
        } message: {
            Text(dataModel.persistenceErrorMessage ?? "Please try again.")
        }
        .onChange(of: dataModel.persistenceErrorMessage) { _, newValue in
            showPersistenceError = newValue != nil
        }
        .alert("Couldn’t transform output", item: $transformErrorMessage) { _ in } message: { message in
            Text(message)
        }
        .navigationDestination(item: $navigationTarget) { target in
            if let transformed = artifacts.first(where: { $0.id == target.id }) {
                ArtifactDetailView(artifact: transformed, preferences: preferences)
            } else {
                ContentUnavailableView(
                    "Output unavailable",
                    systemImage: "doc.badge.exclamationmark",
                    description: Text("The transformed output could not be opened.")
                )
            }
        }
        .onDisappear {
            cancelTransform()
        }
        .onChange(of: hasPremiumAccess) {
            if !hasPremiumAccess { cancelTransform() }
        }
    }

    private func transformArtifact(type: TransformType) {
        guard hasPremiumAccess else {
            showPaywall = true
            return
        }

        transformTask?.cancel()
        let transformID = UUID()
        activeTransformID = transformID
        isTransforming = true
        transformTask = Task {
            defer {
                if activeTransformID == transformID {
                    isTransforming = false
                    transformTask = nil
                    activeTransformID = nil
                }
            }

            let outcome = await dataModel.transformArtifact(
                artifact,
                type: type,
                preferences: preferences,
                in: modelContext
            )
            guard !Task.isCancelled, activeTransformID == transformID else { return }

            switch outcome {
            case .completed(let newArtifact):
                navigationTarget = ArtifactNavigationTarget(id: newArtifact.id)
            case .cancelled:
                break
            case .failed(let message):
                transformErrorMessage = message
            }
        }
    }

    private var hasPremiumAccess: Bool {
        flexStore.isSubscribed || flexStore.purchasedNonConsumables.contains(Monetization.lifetimeID)
    }

    private func cancelTransform() {
        transformTask?.cancel()
        transformTask = nil
        activeTransformID = nil
        isTransforming = false
    }


}

private struct ArtifactNavigationTarget: Identifiable, Hashable {
    let id: UUID
}
