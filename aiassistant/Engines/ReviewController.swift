// Engines/ReviewController.swift
// ai.assistant
//
// Tracks study-aid milestones and decides when to ask for an App Store review.
// Owned by DataModel; the root view observes `isReviewRequestPending` and
// triggers the system review prompt via the `requestReview` environment action.

import Foundation

@MainActor
@Observable
final class ReviewController {

    /// Set to `true` when the user has reached a positive milestone worth
    /// surfacing a review prompt for. The root view reacts and resets it.
    var isReviewRequestPending = false

    private let defaults: UserDefaults
    private let countKey = "review.studyArtifactCount"
    private let lastRequestedVersionKey = "review.lastRequestedVersion"

    /// Number of study aids (quizzes / flashcards) created before we ask.
    private let milestoneThreshold = 2

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Call when the user creates a quiz or flashcard deck — a moment of
    /// realized value that makes a good time to request a rating.
    func registerStudyArtifactCreated() {
        // Only ask once per app version so we never nag.
        guard !hasRequestedForCurrentVersion else { return }

        let newCount = defaults.integer(forKey: countKey) + 1
        defaults.set(newCount, forKey: countKey)

        if newCount >= milestoneThreshold {
            isReviewRequestPending = true
        }
    }

    /// Call once the system review prompt has been presented so we don't ask
    /// again until the next app version.
    func reviewRequestPresented() {
        isReviewRequestPending = false
        defaults.set(currentVersion, forKey: lastRequestedVersionKey)
    }

    private var hasRequestedForCurrentVersion: Bool {
        defaults.string(forKey: lastRequestedVersionKey) == currentVersion
    }

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
