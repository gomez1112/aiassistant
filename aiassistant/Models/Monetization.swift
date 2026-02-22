import SwiftUI
import FlexStore

enum AppSubscriptionTier: Int, CaseIterable, SubscriptionTier {
    case free = 0
    case weekly = 1
    case monthly = 2
    case yearly = 3

    static var defaultTier: AppSubscriptionTier { .free }

    init?(levelOfService: Int) {
        self.init(rawValue: levelOfService)
    }

    init?(productID: String) {
        switch productID {
        case Monetization.subscriptionWeeklyID:
            self = .weekly
        case Monetization.subscriptionMonthlyID:
            self = .monthly
        case Monetization.subscriptionYearlyID:
            self = .yearly
        default:
            return nil
        }
    }
}

enum Monetization {
    static let subscriptionGroupID = "21944633"

    static let subscriptionWeeklyID = "com.transfinite.aiassistant.premium.weekly"
    static let subscriptionMonthlyID = "com.transfinite.aiassistant.premium.monthly"
    static let subscriptionYearlyID = "com.transfinite.aiassistant.premium.yearly"
    static let lifetimeID = "com.transfinite.aiassistant.lifetime"
    static let privacyPolicyURL = URL(string: "https://gomez1112.github.io/Legal/privacy/")!
    static let termsOfServiceURL = URL(string: "https://gomez1112.github.io/Legal/terms/")!

    static let productIDs: Set<String> = [
        subscriptionWeeklyID,
        subscriptionMonthlyID,
        subscriptionYearlyID,
        lifetimeID
    ]

    static let freeDailyMessageLimit = 10

    static let appSubscriptionTiers: [FlexStore.AppSubscriptionTier] = [
        .init(productID: subscriptionWeeklyID, systemImage: "calendar.badge.clock", color: AppTheme.highlight),
        .init(productID: subscriptionMonthlyID, systemImage: "calendar", color: AppTheme.accent),
        .init(productID: subscriptionYearlyID, systemImage: "calendar.badge.checkmark", color: AppTheme.accentLight)
    ]

    static let paywallFeatures: [SubscriptionFeature] = [
        .init(icon: "message.badge.waveform", title: "Unlimited chats", description: "No daily cap for conversations and follow-ups.", accentColor: AppTheme.accent),
        .init(icon: "wand.and.stars", title: "Advanced transforms", description: "Premium writing, planning, and output transformations.", accentColor: AppTheme.highlight),
        .init(icon: "icloud", title: "Priority sync", description: "Faster CloudKit sync and cross-device continuity.", accentColor: AppTheme.accentLight)
    ]
}

extension StoreKitService where Tier == AppSubscriptionTier {
    var hasLifetimeAccess: Bool {
        purchasedNonConsumables.contains(Monetization.lifetimeID)
    }

    var hasPremiumAccess: Bool {
        subscriptionTier != .free || hasLifetimeAccess
    }
}
