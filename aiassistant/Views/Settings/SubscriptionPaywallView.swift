import SwiftUI
import FlexStore
import StoreKit

struct SubscriptionPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = StoreKitService<AppSubscriptionTier>()
    @State private var waitingForLifetimePurchase = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    SubscriptionPassStoreView(
                        groupID: Monetization.subscriptionGroupID,
                        visibleRelationships: .all,
                        iconProvider: { (_: AppSubscriptionTier, product: Product) in
                            switch product.id {
                            case Monetization.subscriptionWeeklyID:
                                return Image(systemName: "calendar.badge.clock")
                            case Monetization.subscriptionMonthlyID:
                                return Image(systemName: "calendar")
                            case Monetization.subscriptionYearlyID:
                                return Image(systemName: "calendar.badge.checkmark")
                            default:
                                return Image(systemName: "sparkles")
                            }
                        },
                        policies: .init(
                            privacyPolicyURL: Monetization.privacyPolicyURL,
                            termsOfServiceURL: Monetization.termsOfServiceURL
                        ),
                        marketing: { marketingHeader }
                    )

                    lifetimeSection
                }
            }
            .navigationTitle("Upgrade")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #if os(macOS)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .frame(minWidth: 760, minHeight: 760)
            #endif
        }
        .attachStoreKit(
            manager: store,
            groupID: Monetization.subscriptionGroupID,
            ids: Monetization.productIDs
        )
        .onChange(of: store.purchasedNonConsumables) { _, newValue in
            if waitingForLifetimePurchase, newValue.contains(Monetization.lifetimeID) {
                waitingForLifetimePurchase = false
                dismiss()
            }
        }
    }

    private var lifetimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Or own it forever")
                .font(.headline)

            Text("Lifetime access is a one-time purchase and priced higher than subscriptions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            NonConsumablePurchaseButton<AppSubscriptionTier>(
                productID: Monetization.lifetimeID,
                title: "Buy Lifetime Access",
                purchasedTitle: "Lifetime Unlocked"
            )
            .buttonStyle(.borderedProminent)
            .simultaneousGesture(
                TapGesture().onEnded {
                    waitingForLifetimePurchase = true
                }
            )

            HStack {
                RestorePurchasesButton<AppSubscriptionTier>()
                Spacer()
                ManageSubscriptionsButton()
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                Link("Privacy Policy", destination: Monetization.privacyPolicyURL)
                Link("Terms of Service", destination: Monetization.termsOfServiceURL)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(AppTheme.spacingLG)
        .background(.regularMaterial)
    }

    private var marketingHeader: some View {
        VStack(spacing: 18) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.accentGradient)
                .frame(width: 110, height: 110)
                .overlay {
                    Image(systemName: "sparkles")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.white)
                }

            Text("Ari+")
                .font(.largeTitle.weight(.bold))

            Text("Choose weekly, monthly, or yearly access.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 10) {
                Text("What's Included")
                    .font(.headline)
                ForEach(Monetization.paywallFeatures) { feature in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: feature.icon)
                            .foregroundStyle(feature.accentColor)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.title)
                                .font(.subheadline.weight(.semibold))
                            Text(feature.description)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, AppTheme.spacingLG)
        .padding(.top, AppTheme.spacingMD)
    }
}

#Preview {
    SubscriptionPaywallView()
}
