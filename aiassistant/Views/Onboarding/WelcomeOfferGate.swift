// Views/Onboarding/WelcomeOfferGate.swift
// ai.assistant
//
// Presents the Ari+ subscription offer once, right after a brand-new user
// finishes first-launch onboarding. The paywall is fully dismissible — tapping
// Close keeps the free experience intact.

import SwiftUI
import OnboardingKit
import FlexStore

struct WelcomeOfferGate<Content: View>: View {
    @AppStorage(OnboardingManager.storageKey) private var lastSeenVersion = ""
    @AppStorage("welcomeOfferPresented") private var welcomeOfferPresented = false

    @Environment(StoreKitService<AppSubscriptionTier>.self) private var flexStore

    @State private var showWelcomeOffer = false

    @ViewBuilder var content: Content

    var body: some View {
        content
            .onChange(of: lastSeenVersion) { oldValue, newValue in
                // First-launch onboarding just completed: the stored version went
                // from empty to set. (A "What's New" update leaves it non-empty.)
                guard oldValue.isEmpty, !newValue.isEmpty else { return }
                presentWelcomeOfferIfNeeded()
            }
            .sheet(isPresented: $showWelcomeOffer) {
                SubscriptionPaywallView(context: .welcome)
            }
    }

    private func presentWelcomeOfferIfNeeded() {
        guard !welcomeOfferPresented else { return }
        welcomeOfferPresented = true

        // Skip the offer for anyone who already has access.
        guard !hasPremiumAccess else { return }

        Task {
            // Let the onboarding cover finish dismissing before presenting.
            try? await Task.sleep(for: .seconds(0.5))
            showWelcomeOffer = true
        }
    }

    private var hasPremiumAccess: Bool {
        flexStore.isSubscribed || flexStore.purchasedNonConsumables.contains(Monetization.lifetimeID)
    }
}
