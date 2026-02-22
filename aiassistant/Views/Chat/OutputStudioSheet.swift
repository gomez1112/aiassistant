// Views/Chat/OutputStudioSheet.swift
// ai.assistant
//
// Output Studio: user selects a target format and tone,
// then the assistant generates a new Artifact.

import SwiftUI

struct OutputStudioSheet: View {
    let sourceText: String
    let preferences: UserPreferences

    @Environment(DataModel.self) private var dataModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedKind: ArtifactKind = .draft
    @State private var selectedTransform: TransformType? = nil
    @State private var title = ""
    @State private var isProcessing = false
    @State private var result: String?
    private let transformColumns = [GridItem(.adaptive(minimum: 96, maximum: 170), spacing: 12)]

    var body: some View {
        NavigationStack {
            Form {
                Section("Source") {
                    Text(sourceText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(5)
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
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if result != nil {
                        Button("Save") { saveArtifact() }
                            .fontWeight(.semibold)
                    } else {
                        Button("Generate") { generate() }
                            .fontWeight(.semibold)
                            .disabled(isProcessing || selectedTransform == nil)
                    }
                }
            }
            .overlay {
                if isProcessing {
                    ProgressView("Generating…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func generate() {
        guard let transform = selectedTransform else { return }
        isProcessing = true
        Task {
            let output = await dataModel.assistant.transform(
                content: sourceText,
                type: transform,
                preferences: preferences
            )
            result = output
            if title.isEmpty {
                title = "\(selectedKind.rawValue) — \(transform.rawValue)"
            }
            isProcessing = false
        }
    }

    private func saveArtifact() {
        guard let content = result else { return }
        let _ = dataModel.saveArtifact(
            kind: selectedKind,
            title: title.isEmpty ? "Untitled" : title,
            content: content,
            tags: [selectedKind.rawValue.lowercased()],
            in: modelContext
        )
        dismiss()
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
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : AppTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(type.rawValue)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}
