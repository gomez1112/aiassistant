// Views/Chat/OutputStudioSheet.swift
// ai.assistant
//
// Output Studio: user selects a target format and tone,
// then the assistant generates a new Artifact.

import SwiftUI
import SwiftData
import FlexStore

struct OutputStudioSheet: View {
    let sourceText: String
    let preferences: UserPreferences

    @Environment(DataModel.self) private var dataModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreKitService<AppSubscriptionTier>.self) private var flexStore

    @State private var selectedKind: ArtifactKind = .draft
    @State private var selectedTransform: TransformType? = nil
    @State private var title = ""
    @State private var isProcessing = false
    @State private var result: String?
    @State private var errorMessage: String?
    @State private var processingTask: Task<Void, Never>?
    @State private var activeProcessingID: UUID?
    @State private var showPaywall = false
    @State private var isSourceExpanded = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var transformColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 120), spacing: AppTheme.spacingMD)]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Source") {
                    Text(sourceText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(isSourceExpanded ? nil : 5)
                    Button(isSourceExpanded ? "Show Less" : "Show More") {
                        isSourceExpanded.toggle()
                    }
                    .font(.caption.weight(.semibold))
                }

                Section("Output Type") {
                    Picker("Kind", selection: $selectedKind) {
                        ForEach(ArtifactKind.allCases) { kind in
                            Label(kind.rawValue, systemImage: kind.icon)
                                .tag(kind)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Transform") {
                    LazyVGrid(columns: transformColumns, spacing: 12) {
                        ForEach(TransformType.allCases) { type in
                            TransformButton(
                                type: type,
                                isSelected: selectedTransform == type,
                                action: { selectedTransform = type }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Title") {
                    TextField("Artifact title", text: $title)
                        .accessibilityLabel("Artifact title")
                }

                if let result {
                    Section("Preview") {
                        Text(result)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Output Studio")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        processingTask?.cancel()
                        activeProcessingID = nil
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if result != nil {
                        Button("Save") { saveArtifact() }
                            .bold()
                    } else {
                        Button("Generate") { generate() }
                            .bold()
                            .disabled(isProcessing || selectedTransform == nil)
                    }
                }
                if result != nil {
                    ToolbarItem(placement: .automatic) {
                        Button("Regenerate") { generate() }
                            .disabled(isProcessing || selectedTransform == nil)
                    }
                }
            }
            .overlay {
                if isProcessing {
                    ProgressView("Generating…")
                        .padding()
                        .background(AppTheme.surfaceFill, in: RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                                .stroke(AppTheme.surfaceStroke, lineWidth: 0.6)
                        )
                }
            }
            .alert("Couldn’t generate output", item: $errorMessage) { _ in } message: { message in
                Text(message)
            }
            .onChange(of: selectedKind) { _, _ in
                invalidateResult()
            }
            .onChange(of: selectedTransform) { _, _ in
                invalidateResult()
            }
            .onDisappear {
                invalidateResult()
            }
            .onChange(of: hasPremiumAccess) {
                if !hasPremiumAccess { invalidateResult() }
            }
            .sheet(isPresented: $showPaywall) {
                SubscriptionPaywallView(context: .outputStudio)
            }
        }
    }

    private func generate() {
        guard hasPremiumAccess else {
            showPaywall = true
            return
        }
        guard let transform = selectedTransform else { return }
        processingTask?.cancel()
        let processingID = UUID()
        activeProcessingID = processingID
        let kind = selectedKind
        result = nil
        isProcessing = true
        processingTask = Task {
            defer {
                if activeProcessingID == processingID {
                    isProcessing = false
                    processingTask = nil
                    activeProcessingID = nil
                }
            }
            let outcome = await dataModel.assistant.transform(
                content: sourceText,
                type: transform,
                preferences: preferences
            )
            guard !Task.isCancelled, activeProcessingID == processingID else { return }

            switch outcome {
            case .success(let output):
                let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    errorMessage = "The output was empty. Try a different transform."
                    return
                }
                result = trimmed
                if title.isEmpty {
                    title = "\(kind.rawValue) - \(transform.rawValue)"
                }
            case .cancelled:
                break
            case .failed(let message):
                errorMessage = message
            }
        }
    }

    private func saveArtifact() {
        guard hasPremiumAccess else {
            showPaywall = true
            return
        }
        guard let content = result else { return }
        let _ = dataModel.saveArtifact(
            kind: selectedKind,
            title: title.isEmpty ? "Untitled" : title,
            content: content,
            tags: [selectedKind.rawValue.lowercased()],
            in: modelContext
        )
        if let message = dataModel.persistenceErrorMessage {
            errorMessage = message
        } else {
            dismiss()
        }
    }

    private func invalidateResult() {
        processingTask?.cancel()
        processingTask = nil
        activeProcessingID = nil
        isProcessing = false
        result = nil
    }

    private var hasPremiumAccess: Bool {
        flexStore.isSubscribed || flexStore.purchasedNonConsumables.contains(Monetization.lifetimeID)
    }
}

struct TransformButton: View {
    let type: TransformType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.title3)
                Text(type.rawValue)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: AppTheme.minimumTapTarget)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                    .fill(isSelected ? AppTheme.accent.opacity(0.12) : AppTheme.surfaceFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                    .stroke(isSelected ? AppTheme.accent : AppTheme.surfaceStroke, lineWidth: isSelected ? 1.2 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(type.rawValue)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}
