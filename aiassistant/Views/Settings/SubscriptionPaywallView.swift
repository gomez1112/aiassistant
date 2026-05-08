import SwiftUI
import FlexStore
import StoreKit

struct SubscriptionPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreKitService<AppSubscriptionTier>.self) private var store
    private let featureColumns = [GridItem(.adaptive(minimum: 96), spacing: AppTheme.spacingSM)]

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
            .navigationTitle("Ari+")
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
        .onInAppPurchaseCompletion { _, result in
            if case .success = result {
                dismiss()
            }
        }
    }

    private var lifetimeSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingLG) {
            HStack(alignment: .top, spacing: AppTheme.spacingMD) {
                AppIconBadge(systemImage: "infinity", tint: AppTheme.highlight, size: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Prefer one purchase?")
                        .font(.headline)
                    Text("Lifetime unlocks Ari+ once and keeps the premium tools available without a subscription.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            NonConsumablePurchaseButton<AppSubscriptionTier>(
                productID: Monetization.lifetimeID,
                title: "Buy Lifetime",
                purchasedTitle: "Lifetime Unlocked"
            )
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(AppTheme.accent)

            VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
                HStack {
                    RestorePurchasesButton<AppSubscriptionTier>()
                    Spacer()
                    ManageSubscriptionsButton()
                }

                HStack(spacing: 14) {
                    Link("Privacy Policy", destination: Monetization.privacyPolicyURL)
                    Link("Terms of Service", destination: Monetization.termsOfServiceURL)
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(AppTheme.spacingLG)
        .appSurface(cornerRadius: AppTheme.radiusCard)
        .padding(.horizontal, AppTheme.spacingLG)
        .padding(.bottom, AppTheme.spacingLG)
    }

    private var marketingHeader: some View {
        VStack(spacing: AppTheme.spacingLG) {
            VStack(spacing: AppTheme.spacingSM) {
                PaywallHeroMark()

                VStack(spacing: AppTheme.spacingSM) {
                    Text("Get more done with Ari+")
                        .font(.title)
                        .bold()
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Unlimited chats, file uploads, and Output Studio for turning rough answers into work you can use.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: 460)
            }

            LazyVGrid(columns: featureColumns, spacing: AppTheme.spacingSM) {
                ForEach(Monetization.paywallFeatures) { feature in
                    PaywallFeatureChip(feature: feature)
                }
            }

            PaywallAssuranceGrid()
        }
        .padding(.horizontal, AppTheme.spacingLG)
        .padding(.top, AppTheme.spacingMD)
        .padding(.bottom, AppTheme.spacingMD)
    }
}

private struct PaywallHeroMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(AppTheme.accent)
                .frame(width: 68, height: 68)
                .shadow(color: AppTheme.accent.opacity(0.18), radius: 14, x: 0, y: 8)

            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
        }
        .accessibilityHidden(true)
    }
}

private struct PaywallAssuranceGrid: View {
    private let assurances = [
        ("checkmark.seal", "Cancel anytime"),
        ("lock.shield", "Apple checkout"),
        ("rectangle.and.pencil.and.ellipsis", "No ads")
    ]

    private let columns = [GridItem(.adaptive(minimum: 98), spacing: AppTheme.spacingSM)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: AppTheme.spacingSM) {
            ForEach(assurances, id: \.1) { assurance in
                Label(assurance.1, systemImage: assurance.0)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, AppTheme.spacingMD)
                    .padding(.vertical, AppTheme.spacingSM)
                    .background(.thinMaterial, in: Capsule())
            }
        }
    }
}

private struct PaywallFeatureChip: View {
    let feature: SubscriptionFeature

    var body: some View {
        VStack(spacing: AppTheme.spacingSM) {
            AppIconBadge(systemImage: feature.icon, tint: feature.accentColor, size: 34)

            Text(feature.title)
                .font(.footnote)
                .bold()
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 92)
        .padding(AppTheme.spacingSM)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                .stroke(AppTheme.surfaceStroke, lineWidth: 0.5)
        )
    }
}

#Preview {
    SubscriptionPaywallView()
}
