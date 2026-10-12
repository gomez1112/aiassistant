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
    @State private var offerPending = false

    @ViewBuilder var content: Content

    var body: some View {
        content
            .onChange(of: lastSeenVersion) { oldValue, newValue in
                // First-launch onboarding just completed: the stored version went
                // from empty to set. (A "What's New" update leaves it non-empty.)
                guard oldValue.isEmpty, !newValue.isEmpty else { return }
                presentWelcomeOfferIfNeeded()
            }
            .task(id: offerPending) {
                guard offerPending else { return }
                do {
                    try await Task.sleep(for: .seconds(0.5))
                    try Task.checkCancellation()
                    guard !welcomeOfferPresented, !hasPremiumAccess else { offerPending = false; return }
                    welcomeOfferPresented = true
                    showWelcomeOffer = true
                    offerPending = false
                } catch { return }
            }
            .sheet(isPresented: $showWelcomeOffer) {
                SubscriptionPaywallView(context: .welcome)
            }
    }

    private func presentWelcomeOfferIfNeeded() {
        guard !welcomeOfferPresented else { return }

        // Skip the offer for anyone who already has access.
        guard !hasPremiumAccess else { return }

        offerPending = true
    }

    private var hasPremiumAccess: Bool {
        flexStore.isSubscribed || flexStore.purchasedNonConsumables.contains(Monetization.lifetimeID)
    }
}
