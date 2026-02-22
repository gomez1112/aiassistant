// Preview/SampleData.swift
// ai.assistant
//
// Sample data for SwiftUI previews and debug mode.

import Foundation
import SwiftData

enum SampleData {
    /// Seed sample threads, messages, artifacts, and library items into the given context.
    @MainActor
    static func seed(in context: ModelContext) {
        // Thread 1: Writing session
        let thread1 = Thread(title: "Blog post about productivity", pinned: true)
        context.insert(thread1)

        let msg1 = Message(
            thread: thread1,
            role: .user,
            text: "Help me write a blog post about staying productive while working from home.",
            mode: .write
        )
        context.insert(msg1)

        let msg2 = Message(
            thread: thread1,
            role: .assistant,
            text: "Here's a draft for your blog post:\n\n# Staying Productive at Home\n\nWorking from home offers flexibility, but it also comes with unique challenges. Here are proven strategies to maintain focus and output...",
            mode: .write,
            ariGuidance: "Nice — this is coming together. I can turn it into a polished draft next.",
            ariMood: .encouraging
        )
        context.insert(msg2)

        // Thread 2: Planning session
        let thread2 = Thread(title: "Vacation planning")
        context.insert(thread2)

        let msg3 = Message(
            thread: thread2,
            role: .user,
            text: "Help me plan a 5-day trip to Japan",
            mode: .plan
        )
        context.insert(msg3)

        let msg4 = Message(
            thread: thread2,
            role: .assistant,
            text: "## 5-Day Japan Itinerary\n\n### Day 1: Tokyo\n- Arrive at Narita/Haneda\n- Check into hotel in Shinjuku\n- Evening: Shibuya crossing, dinner in Yurakucho\n\n### Day 2: Tokyo\n- Morning: Senso-ji Temple\n- Afternoon: Akihabara\n- Evening: Roppongi or Ginza",
            mode: .plan,
            ariGuidance: "Let's stay focused. Want the short version or the detailed one?",
            ariMood: .focused
        )
        context.insert(msg4)

        // Artifacts
        let artifact1 = Artifact(
            kind: .draft,
            title: "Productivity Blog Post",
            content: "# Staying Productive at Home\n\nWorking from home offers flexibility, but it also comes with unique challenges...",
            tags: ["draft", "writing", "productivity"],
            sourceThreadID: thread1.id
        )
        context.insert(artifact1)

        let artifact2 = Artifact(
            kind: .plan,
            title: "Japan Trip Plan",
            content: "## 5-Day Japan Itinerary\n\n### Day 1: Tokyo\n- Arrive at Narita...",
            tags: ["plan", "travel", "japan"],
            sourceThreadID: thread2.id
        )
        context.insert(artifact2)

        let artifact3 = Artifact(
            kind: .checklist,
            title: "Morning Routine",
            content: "# Morning Routine\n\n- [ ] Wake up at 6:30\n- [ ] 10 min meditation\n- [ ] Exercise 30 min\n- [ ] Healthy breakfast\n- [ ] Review daily goals",
            tags: ["checklist", "routine"]
        )
        context.insert(artifact3)

        // Library Items
        let lib1 = LibraryItem(
            title: "Meeting Notes – Q3 Planning",
            kind: .note,
            rawText: "Discussed roadmap priorities for Q3. Focus on performance improvements and new onboarding flow. Team agreed to ship v2 of the dashboard by end of August.",
            aiSummary: "Q3 focus: performance, onboarding, and dashboard v2 by August."
        )
        context.insert(lib1)

        let lib2 = LibraryItem(
            title: "Interesting quote",
            kind: .snippet,
            rawText: "The best way to predict the future is to create it. — Peter Drucker"
        )
        context.insert(lib2)

        try? context.save()
    }
}
