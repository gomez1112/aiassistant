import SwiftUI

enum AppSubscriptionTier: Int, CaseIterable, Comparable, Identifiable, Sendable {
    case free = 0
    case weekly = 1
    case monthly = 2
    case yearly = 3

    static var defaultTier: AppSubscriptionTier { .free }
    var id: Int { rawValue }

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

    var productID: String? {
        switch self {
        case .free:
            nil
        case .weekly:
            Monetization.subscriptionWeeklyID
        case .monthly:
            Monetization.subscriptionMonthlyID
        case .yearly:
            Monetization.subscriptionYearlyID
        }
    }

    var displayName: String {
        switch self {
        case .free:
            "Free"
        case .weekly:
            "Weekly"
        case .monthly:
            "Monthly"
        case .yearly:
            "Yearly"
        }
    }

    static func < (lhs: AppSubscriptionTier, rhs: AppSubscriptionTier) -> Bool {
        lhs.rawValue < rhs.rawValue
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

    static let subscriptionProductIDs: [String] = [
        subscriptionWeeklyID,
        subscriptionMonthlyID,
        subscriptionYearlyID
    ]

    static let paywallFeatures: [PaywallFeature] = [
        .init(icon: "message.badge.waveform", title: "Unlimited conversations", description: "Follow ideas all the way through without the daily message cap.", accentColor: AppTheme.accent),
        .init(icon: "paperclip", title: "File and image uploads", description: "Bring PDFs and images into chat when you need summaries or next steps.", accentColor: AppTheme.highlight),
        .init(icon: "wand.and.stars", title: "Output Studio", description: "Turn any answer into drafts, plans, checklists, or study material.", accentColor: AppTheme.accentLight)
    ]
}

struct PaywallFeature: Identifiable, Sendable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let accentColor: Color
}

struct SubscriptionCatalog: Sendable {
    let subscriptionGroupID: String
    let subscriptionProductIDs: [String]
    let lifetimeProductID: String

    var allProductIDs: [String] {
        subscriptionProductIDs + [lifetimeProductID]
    }

    var productIDSet: Set<String> {
        Set(allProductIDs)
    }

    static let ariPlus = SubscriptionCatalog(
        subscriptionGroupID: Monetization.subscriptionGroupID,
        subscriptionProductIDs: Monetization.subscriptionProductIDs,
        lifetimeProductID: Monetization.lifetimeID
    )
}
