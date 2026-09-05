import Foundation
import SwiftData
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

    @Test func displayTextKeepsGeneratedTextExactOutsideSimpleMarkdownCleanup() {
        let raw = """
        Here are some tips.Use headings:
        * **Use headings:** Headings help.
        * **Use shorter sentences:** Shorter is clearer.
        URL: https://example.com/a:b
        """

        let displayText = normalizedDisplayText(raw)

        #expect(displayText.contains("tips.Use headings"))
        #expect(displayText.contains("• Use headings: Headings help."))
        #expect(displayText.contains("• Use shorter sentences: Shorter is clearer."))
        #expect(displayText.contains("https://example.com/a:b"))
        #expect(!displayText.contains("**"))
    }

    @Test func subscriptionCatalogUsesExpectedProductIDs() {
        let catalog = SubscriptionCatalog.ariPlus

        #expect(catalog.subscriptionGroupID == Monetization.subscriptionGroupID)
        #expect(catalog.subscriptionProductIDs == [
            Monetization.subscriptionWeeklyID,
            Monetization.subscriptionMonthlyID,
            Monetization.subscriptionYearlyID
        ])
        #expect(catalog.allProductIDs.contains(Monetization.lifetimeID))
        #expect(catalog.productIDSet.count == catalog.allProductIDs.count)
    }

    @Test func freeChatLimitTriggersAfterThreeMessages() {
        #expect(Monetization.freeDailyMessageLimit == 3)
    }

    @Test func subscriptionTierMapsFromProductID() {
        #expect(AppSubscriptionTier(productID: Monetization.subscriptionWeeklyID) == .weekly)
        #expect(AppSubscriptionTier(productID: Monetization.subscriptionMonthlyID) == .monthly)
        #expect(AppSubscriptionTier(productID: Monetization.subscriptionYearlyID) == .yearly)
        #expect(AppSubscriptionTier(productID: Monetization.lifetimeID) == nil)
        #expect(AppSubscriptionTier.yearly > .monthly)
    }

    @Test func paywallUsesYearlyFirstSubscriptionPath() {
        let preferredOrder = [
            Monetization.subscriptionYearlyID,
            Monetization.subscriptionMonthlyID,
            Monetization.subscriptionWeeklyID
        ]

        #expect(preferredOrder.first == Monetization.subscriptionYearlyID)
        #expect(preferredOrder.allSatisfy { Monetization.subscriptionProductIDs.contains($0) })
    }

    @Test func paywallContextsMatchPremiumFeatureGates() {
        #expect(SubscriptionPaywallContext.messageLimit.title == "Keep the conversation going")
        #expect(SubscriptionPaywallContext.fileUpload.eyebrow == "File upload")
        #expect(SubscriptionPaywallContext.outputStudio.icon == "wand.and.stars")
        #expect(SubscriptionPaywallContext.librarySummary.title == "Summarize saved source material")
    }
    @Test func startNewThreadReusesEmptyActiveThread() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: Thread.self, Message.self, Artifact.self, LibraryItem.self, UserPreferences.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let model = DataModel()

        let first = model.startNewThread(in: context)
        let second = model.startNewThread(in: context)
        #expect(first.id == second.id)

        context.insert(Message(thread: first, role: .user, text: "Hello"))
        let third = model.startNewThread(in: context)
        #expect(third.id != first.id)
        #expect(model.activeThread?.id == third.id)
    }

    @Test func starterPromptsCoverDistinctModesWithUniqueMessages() {
        let prompts = StarterPrompt.defaults

        #expect(!prompts.isEmpty)
        #expect(Set(prompts.map(\.message)).count == prompts.count)
        #expect(Set(prompts.map(\.mode)).count == prompts.count)
        #expect(prompts.allSatisfy { !$0.title.isEmpty && !$0.systemImage.isEmpty })
    }
}
