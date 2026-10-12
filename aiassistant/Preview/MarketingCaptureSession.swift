#if DEBUG
import SwiftUI
import SwiftData
import Observation

/// Opt-in capture fixtures never touch the user's disk store or CloudKit records.
@MainActor
@Observable
final class MarketingCaptureSession {
    enum Scene: String, CaseIterable {
        case writing, planning, outputs, library, study, privacy
    }

    static var isEnabled: Bool { ProcessInfo.processInfo.arguments.contains("-marketing-capture") || Bundle.main.object(forInfoDictionaryKey: "MarketingCaptureEnabled") as? Bool == true }
    static var current: MarketingCaptureSession? { isEnabled ? MarketingCaptureSession() : nil }
    var scene: Scene = .writing
    var captureError: String?
    private(set) var writingThread: Thread?
    private(set) var planningThread: Thread?
    private(set) var studyArtifactID: UUID?

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-marketing-scene"),
           arguments.indices.contains(index + 1), let scene = Scene(rawValue: arguments[index + 1]) {
            self.scene = scene
        }
    }

    func prepare(in context: ModelContext, model: DataModel) throws {
        guard writingThread == nil else { return }
        let date = Date.now.addingTimeInterval(-86400)
        let writing = Thread(title: "A thoughtful follow-up", createdAt: date, updatedAt: .now, pinned: true)
        let planning = Thread(title: "A calmer week", createdAt: date, updatedAt: date)
        context.insert(writing)
        context.insert(planning)
        let turns: [(Thread, AssistantMode, String, String)] = [
            (writing, .write, "Write a warm follow-up after our meeting.", "Hi Jordan,\n\nThanks for a great conversation. I’ll share the revised proposal on Thursday, then we can confirm the timeline together on Friday.\n\nLooking forward to our next step!\n\nAlex"),
            (planning, .plan, "Plan a focused week with room to recharge.", "A calmer week\n\n• Choose three meaningful priorities.\n• Protect a morning focus block.\n• Finish the draft by Thursday.\n• Review your progress on Friday.\n\nLeave a little breathing room each day.")
        ]
        for (thread, mode, prompt, response) in turns {
            let user = Message(thread: thread, role: .user, text: prompt, createdAt: date, mode: mode)
            let assistant = Message(thread: thread, role: .assistant, text: response, createdAt: date.addingTimeInterval(1), mode: mode)
            thread.messages = [user, assistant]
            context.insert(user)
            context.insert(assistant)
        }
        let outputs: [(ArtifactKind, String, String, [String])] = [
            (.draft, "A thoughtful follow-up", turns[0].3, ["writing", "work"]),
            (.plan, "A calmer week", turns[1].3, ["planning", "focus"]),
            (.summary, "The meeting, made clear", "The team agreed to simplify onboarding, improve performance, and share a revised proposal by Thursday.\n\nNext step: confirm ownership and timing at Friday’s check-in.", ["summary", "notes"]),
            (.flashcards, "Learn a little, remember more", "Q: What is active recall?\nA: Practice retrieving an idea from memory instead of only rereading it.\n\nQ: What is spaced repetition?\nA: Review ideas at increasing intervals to strengthen long-term memory.\n\nQ: How can you test your understanding?\nA: Explain the idea simply and check where your explanation needs work.", ["study", "learning"]),
            (.checklist, "Ready for the next step", "• Choose one meaningful priority\n• Make room for a focus block\n• Share a clear update\n• Review what you learned", ["checklist", "planning"])
        ]
        for (kind, title, content, tags) in outputs {
            let artifact = Artifact(kind: kind, title: title, content: content, tags: tags)
            context.insert(artifact)
            if kind == .flashcards { studyArtifactID = artifact.id }
        }
        context.insert(LibraryItem(title: "Project meeting notes", kind: .note, rawText: "Simplify onboarding. Improve performance. Share the revised proposal by Thursday and confirm the timeline on Friday.", aiSummary: "Three clear next steps: simplify, improve, and align on timing."))
        context.insert(LibraryItem(title: "A useful idea", kind: .snippet, rawText: "Make the next step small enough to start, and clear enough to finish."))
        context.insert(LibraryItem(title: "Learning notes", kind: .note, rawText: "Use active recall to test understanding. Space your practice over time. Explain each idea in your own words."))
        try context.save()
        writingThread = writing
        planningThread = planning
        selectConversation(in: model)
    }

    func selectConversation(in model: DataModel) {
        let thread = scene == .planning ? planningThread : writingThread
        model.activeThread = thread
        model.selectedMode = scene == .planning ? .plan : .write
        model.lastAssistantMessage = thread?.sortedMessages.last
    }

    func runTour() async {
        guard ProcessInfo.processInfo.arguments.contains("-marketing-tour") else { return }
        do {
            try await Task.sleep(for: .seconds(7))
            for next in [Scene.planning, .outputs, .library, .study] {
                scene = next
                try await Task.sleep(for: .seconds(4))
            }
        } catch { return }
    }

    var tab: AppTab {
        switch scene {
        case .outputs, .study: .outputs
        case .library: .library
        default: .chat
        }
    }
}

extension EnvironmentValues {
    @Entry var marketingCapture: MarketingCaptureSession? = nil
}
#endif
