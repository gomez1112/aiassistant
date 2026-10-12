import Foundation
import SwiftData
import Testing
@testable import aiassistant

@MainActor
struct DataIntegrityTests {
    @Test func cancelledSendDoesNotInsertMessages() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let model = DataModel()
        let thread = model.createThread(in: context)
        let preferences = UserPreferences()

        let operation = Task {
            await model.sendMessage(text: "Cancelled request", in: thread, context: context, preferences: preferences)
        }
        operation.cancel()

        #expect(await operation.value == .cancelled)
        #expect(try context.fetchCount(FetchDescriptor<Message>()) == 0)
    }

    @Test func failedAndInterruptedTurnsAreExcludedFromModelContext() {
        let messages = [
            Message(text: "Finished request"),
            Message(text: "Failed request", status: .failed),
            Message(text: "Stopped request", status: .cancelled),
            Message(text: "Pending request", status: .pending),
            Message(role: .assistant, text: "Finished answer")
        ]
        let context = AssistantEngine().buildConversationContext(history: messages)
        #expect(context.contains("Finished request"))
        #expect(context.contains("Finished answer"))
        #expect(!context.contains("Failed request"))
        #expect(!context.contains("Stopped request"))
        #expect(!context.contains("Pending request"))
    }

    @Test func onlyCompletedUserMessagesCountTowardTheQuota() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        for status in MessageStatus.allCases {
            context.insert(Message(text: status.rawValue, status: status))
        }
        context.insert(Message(role: .assistant, text: "An answer"))
        try context.save()

        let descriptor = FetchDescriptor<Message>(predicate: #Predicate {
            $0.roleRaw == "user" && $0.statusRaw == "completed"
        })
        #expect(try context.fetchCount(descriptor) == 1)
    }

    @Test func savingAnOlderReplyKeepsItsOriginalSourceThread() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let model = DataModel()
        let original = model.createThread(in: context)
        let message = Message(thread: original, role: .assistant, text: "An older useful answer")
        context.insert(message)
        let current = model.createThread(in: context)

        let artifact = model.saveArtifact(
            from: ArtifactSuggestion(kind: .draft, title: "Saved", content: message.text, tags: []),
            message: message,
            in: context
        )
        #expect(artifact.sourceThreadID == original.id)
        #expect(artifact.sourceThreadID != current.id)
        #expect(artifact.sourceMessageID == message.id)
    }

    @Test func windowsKeepConversationStateIndependentWhileSharingProcessingChoice() {
        let settings = AssistantModelSettings()
        let first = DataModel(settings: settings)
        let second = DataModel(settings: settings)
        first.activeThread = Thread(title: "First window")
        first.selectedMode = .write

        #expect(second.activeThread == nil)
        #expect(second.selectedMode == .general)
        #expect(first.assistant !== second.assistant)
        #expect(first.assistant.settings === second.assistant.settings)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Thread.self, Message.self, Artifact.self, LibraryItem.self, UserPreferences.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }
}
