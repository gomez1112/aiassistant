import SwiftUI
import SwiftData

// MARK: - Tag Editor

struct TagEditorSheet: View {
    @Bindable var artifact: Artifact
    @State private var newTag = ""
    @Environment(DataModel.self) private var dataModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = dataModel
        return NavigationStack {
            List {
                Section("Tags") {
                    ForEach(artifact.tags, id: \.self) { tag in
                        Text(tag)
                    }
                    .onDelete { offsets in
                        var tags = artifact.tags
                        tags.remove(atOffsets: offsets)
                        artifact.tags = tags
                        artifact.updatedAt = .now
                        saveChanges()
                    }
                }

                Section("Add Tag") {
                    HStack {
                        TextField("New tag", text: $newTag)
                        Button("Add", action: addTag)
                        .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .navigationTitle("Edit Tags")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .alert("Couldn’t save changes", item: $model.persistenceErrorMessage) { _ in } message: { message in
            Text(message)
        }
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.localizedLowercase
        guard !trimmed.isEmpty,
              !artifact.tags.contains(where: { $0.localizedLowercase == normalized }) else {
            newTag = ""
            return
        }
        var tags = artifact.tags
        tags.append(trimmed)
        artifact.tags = tags
        artifact.updatedAt = .now
        newTag = ""
        saveChanges()
    }

    private func saveChanges() {
        dataModel.saveChanges(in: modelContext, source: "editTags")
    }
}
