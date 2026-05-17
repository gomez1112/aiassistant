import SwiftUI
import FlexStore

enum AppSubscriptionTier: Int, CaseIterable, Comparable, Identifiable, Sendable, SubscriptionTier {
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
        case "com.transfinite.aiassistant.premium.weekly":
            self = .weekly
        case "com.transfinite.aiassistant.premium.monthly":
            self = .monthly
        case "com.transfinite.aiassistant.premium.yearly":
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
            "com.transfinite.aiassistant.premium.weekly"
        case .monthly:
            "com.transfinite.aiassistant.premium.monthly"
        case .yearly:
            "com.transfinite.aiassistant.premium.yearly"
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

    static let freeDailyMessageLimit = 3

    static let subscriptionProductIDs: [String] = [
        subscriptionWeeklyID,
        subscriptionMonthlyID,
        subscriptionYearlyID
    ]

    static let paywallFeatures: [PaywallFeature] = [
        .init(icon: "message.badge.waveform", title: "Unlimited chats", description: "No daily cap for conversations and follow-ups.", accentColor: AppTheme.accent),
        .init(icon: "wand.and.stars", title: "Advanced transforms", description: "Premium writing, planning, and output transformations.", accentColor: AppTheme.highlight),
        .init(icon: "icloud", title: "Priority sync", description: "Faster CloudKit sync and cross-device continuity.", accentColor: AppTheme.accentLight)
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

struct SubscriptionPaywallContext: Equatable, Sendable {
    let icon: String
    let eyebrow: String
    let title: String
    let subtitle: String

    static let general = SubscriptionPaywallContext(
        icon: "sparkles",
        eyebrow: "Ari+",
        title: "Unlock Ari without limits",
        subtitle: "Start with the free trial, then keep unlimited conversations, uploads, and Output Studio when Ari becomes part of your workflow."
    )

    static let settings = SubscriptionPaywallContext(
        icon: "sparkles",
        eyebrow: "Ari+",
        title: "Choose your Ari+ plan",
        subtitle: "Start with the free trial or pick the plan that matches how often you use Ari."
    )

    static let messageLimit = SubscriptionPaywallContext(
        icon: "message.badge",
        eyebrow: "Daily limit reached",
        title: "Keep the conversation going",
        subtitle: "Ari+ removes the daily cap so you can finish drafts, plans, summaries, and follow-ups in one session."
    )

    static let fileUpload = SubscriptionPaywallContext(
        icon: "paperclip",
        eyebrow: "File upload",
        title: "Bring documents into Ari",
        subtitle: "Ari+ unlocks PDFs and images so you can summarize, extract next steps, and ask follow-up questions."
    )

    static let outputStudio = SubscriptionPaywallContext(
        icon: "wand.and.stars",
        eyebrow: "Output Studio",
        title: "Turn answers into finished work",
        subtitle: "Ari+ unlocks transformations for drafts, checklists, study notes, plans, and cleaner versions of saved outputs."
    )

    static let librarySummary = SubscriptionPaywallContext(
        icon: "books.vertical",
        eyebrow: "Library summaries",
        title: "Summarize saved source material",
        subtitle: "Ari+ turns Library notes into concise summaries you can reuse in chat and saved outputs."
    )
}
