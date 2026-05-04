import Foundation
import Testing
@testable import aiassistant

@MainActor
struct AIAssistantTests {
    @Test func assistantIntentClassificationUsesExpectedModes() {
        let engine = AssistantEngine()

        #expect(engine.classifyIntent("Draft a launch email") == .write)
        #expect(engine.classifyIntent("Summarize this transcript") == .summarize)
        #expect(engine.classifyIntent("Explain how CloudKit sync works") == .explain)
        #expect(engine.classifyIntent("Plan my release checklist") == .plan)
        #expect(engine.classifyIntent("Brainstorm names for the app") == .brainstorm)
        #expect(engine.classifyIntent("   ") == .general)
    }

    @Test func artifactTagsRoundTripThroughStorageString() {
        let artifact = Artifact(
            kind: .summary,
            title: "Notes",
            content: "A useful summary",
            tags: ["summary", "release"]
        )

        #expect(artifact.tags == ["summary", "release"])

        artifact.tags = ["updated", "important"]

        #expect(artifact.tagsRaw == "updated\nimportant")
        #expect(artifact.tags == ["updated", "important"])
    }

    @Test func threadMessagesSortChronologically() {
        let older = Message(text: "First", createdAt: Date(timeIntervalSince1970: 10))
        let newer = Message(text: "Second", createdAt: Date(timeIntervalSince1970: 20))
        let thread = Thread(messages: [newer, older])

        #expect(thread.sortedMessages.map(\.text) == ["First", "Second"])
        #expect(thread.lastMessagePreview == "Second")
    }
}
