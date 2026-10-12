import SwiftUI
import SwiftData

// MARK: - Add Library Item Sheet

struct AddLibraryItemSheet: View {
    @Environment(DataModel.self) private var dataModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var kind: LibraryItemKind = .note
    @State private var rawText = ""

    var body: some View {
        @Bindable var model = dataModel
        return NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    Picker("Type", selection: $kind) {
                        ForEach(LibraryItemKind.allCases) { k in
                            Label(k.rawValue, systemImage: k.icon).tag(k)
                        }
                    }
                }
                Section("Content") {
                    TextField("Paste notes, snippets, or source text", text: $rawText, axis: .vertical)
                        .lineLimit(8...18)
                        .accessibilityLabel("Content")
                }
            }
            .navigationTitle("Add to Library")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                    .disabled(rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .bold()
                }
            }
        }
        .alert("Couldn’t save changes", item: $model.persistenceErrorMessage) { _ in } message: { message in
            Text(message)
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = LibraryItem(
            title: trimmedTitle.isEmpty ? "Untitled" : trimmedTitle,
            kind: kind,
            rawText: rawText
        )
        modelContext.insert(item)
        if dataModel.saveChanges(in: modelContext, source: "addLibraryItem") {
            dismiss()
        }
    }
}
