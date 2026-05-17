import SwiftUI
import StoreKit

struct SubscriptionPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(SubscriptionStore.self) private var store

    private let featureColumns = [GridItem(.adaptive(minimum: 100), spacing: AppTheme.spacingSM)]
    private let subscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingLG) {
                    marketingHeader
                    subscriptionSection
                    lifetimeSection
                    policySection
                }
                .padding(.horizontal, AppTheme.spacingLG)
                .padding(.top, AppTheme.spacingMD)
                .padding(.bottom, AppTheme.spacingLG)
            }
            .navigationTitle("Ari+")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            #if os(macOS)
            .frame(minWidth: 760, minHeight: 760)
            #endif
        }
        .task {
            await store.refresh()
        }
        .onChange(of: store.hasPremiumAccess) { _, hasAccess in
            if hasAccess {
                dismiss()
            }
        }
        .alert("StoreKit", isPresented: errorBinding) {
            Button("OK", role: .cancel) {
                store.errorMessage = nil
            }
        } message: {
            Text(store.errorMessage ?? "Please try again.")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    store.errorMessage = nil
                }
            }
        )
    }

    @ViewBuilder
    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMD) {
            PaywallSectionHeader(
                icon: "sparkles",
                title: "Subscriptions",
                subtitle: "Weekly, monthly, or yearly access. StoreKit keeps entitlement changes in sync."
            )

            if store.subscriptionProducts.isEmpty {
                ProductLoadingState(
                    state: store.loadingState,
                    retry: { Task { await store.refresh() } }
                )
            } else {
                VStack(spacing: AppTheme.spacingSM) {
                    ForEach(store.subscriptionProducts, id: \.id) { product in
                        ProductPurchaseRow(
                            product: product,
                            icon: icon(for: product.id),
                            tint: tint(for: product.id),
                            isCurrent: store.purchasedProductIDs.contains(product.id),
                            isPurchasing: store.purchaseInProgressProductID == product.id,
                            action: { purchase(product) }
                        )
                    }
                }
            }
        }
        .padding(AppTheme.spacingLG)
        .appSurface(cornerRadius: AppTheme.radiusCard)
    }

    @ViewBuilder
    private var lifetimeSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMD) {
            PaywallSectionHeader(
                icon: "infinity",
                title: "Lifetime",
                subtitle: "Unlock Ari+ once without a renewing subscription."
            )

            if let product = store.lifetimeProduct {
                ProductPurchaseRow(
                    product: product,
                    icon: "infinity",
                    tint: AppTheme.highlight,
                    isCurrent: store.hasLifetimeAccess,
                    isPurchasing: store.purchaseInProgressProductID == product.id,
                    action: { purchase(product) }
                )
            } else {
                ProductLoadingState(
                    state: store.loadingState,
                    retry: { Task { await store.refresh() } }
                )
            }
        }
        .padding(AppTheme.spacingLG)
        .appSurface(cornerRadius: AppTheme.radiusCard)
    }

    private var policySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            HStack {
                Button {
                    Task { await store.restorePurchases() }
                } label: {
                    Label("Restore", systemImage: "arrow.clockwise")
                }

                Spacer()

                Button {
                    openURL(subscriptionsURL)
                } label: {
                    Label("Manage", systemImage: "slider.horizontal.3")
                }
            }
            .font(.footnote)
            .buttonStyle(.borderless)

            HStack(spacing: 14) {
                Link("Privacy Policy", destination: Monetization.privacyPolicyURL)
                Link("Terms of Service", destination: Monetization.termsOfServiceURL)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private var marketingHeader: some View {
        VStack(spacing: AppTheme.spacingLG) {
            VStack(spacing: AppTheme.spacingSM) {
                PaywallHeroMark()

                VStack(spacing: AppTheme.spacingSM) {
                    Text("Get more done with Ari+")
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Unlimited chats, file uploads, and Output Studio for turning rough answers into work you can use.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
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
    }

    private func purchase(_ product: Product) {
        Task {
            let outcome = await store.purchase(product)
            if outcome == .purchased {
                dismiss()
            }
        }
    }

    private func icon(for productID: String) -> String {
        switch productID {
        case Monetization.subscriptionWeeklyID:
            "calendar.badge.clock"
        case Monetization.subscriptionMonthlyID:
            "calendar"
        case Monetization.subscriptionYearlyID:
            "calendar.badge.checkmark"
        default:
            "sparkles"
        }
    }

    private func tint(for productID: String) -> Color {
        switch productID {
        case Monetization.subscriptionWeeklyID:
            AppTheme.highlight
        case Monetization.subscriptionMonthlyID:
            AppTheme.accent
        case Monetization.subscriptionYearlyID:
            AppTheme.accentLight
        default:
            AppTheme.accent
        }
    }
}

private struct PaywallSectionHeader: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingMD) {
            AppIconBadge(systemImage: icon, tint: AppTheme.accent, size: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct ProductPurchaseRow: View {
    let product: Product
    let icon: String
    let tint: Color
    let isCurrent: Bool
    let isPurchasing: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.spacingMD) {
            AppIconBadge(systemImage: icon, tint: tint, size: 36)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: AppTheme.spacingSM) {
                    Text(product.displayName)
                        .font(.headline)

                    if isCurrent {
                        Text("Active")
                            .font(.caption)
                            .bold()
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.accent.opacity(0.12), in: Capsule())
                    }
                }

                Text(product.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: AppTheme.spacingSM)

            Button(action: action) {
                if isPurchasing {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 68)
                } else {
                    Text(isCurrent ? "Current" : product.displayPrice)
                        .font(.subheadline)
                        .bold()
                        .frame(minWidth: 68)
                }
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(AppTheme.accent)
            .disabled(isCurrent || isPurchasing)
        }
        .padding(AppTheme.spacingMD)
        .background(AppTheme.surfaceFill, in: RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                .stroke(isCurrent ? tint.opacity(0.45) : AppTheme.surfaceStroke, lineWidth: isCurrent ? 1 : 0.5)
        )
    }
}

private struct ProductLoadingState: View {
    let state: SubscriptionStore.LoadingState
    let retry: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.spacingSM) {
            switch state {
            case .loading:
                ProgressView("Loading plans...")
            case .failed(let message):
                ContentUnavailableView(
                    "Plans Unavailable",
                    systemImage: "wifi.exclamationmark",
                    description: Text(message)
                )

                Button("Retry", action: retry)
                    .buttonStyle(.bordered)
            case .idle, .loaded:
                ContentUnavailableView(
                    "Plans Unavailable",
                    systemImage: "cart.badge.questionmark",
                    description: Text("StoreKit did not return products for this storefront.")
                )

                Button("Retry", action: retry)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.spacingLG)
    }
}

private struct PaywallHeroMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                .fill(AppTheme.accent)
                .frame(width: 58, height: 58)

            Image(systemName: "sparkles")
                .font(.system(size: 24, weight: .semibold))
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
                    .background(AppTheme.surfaceFill, in: Capsule())
                    .overlay(Capsule().stroke(AppTheme.surfaceStroke, lineWidth: 0.5))
            }
        }
    }
}

private struct PaywallFeatureChip: View {
    let feature: PaywallFeature

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
        .frame(minHeight: 84)
        .padding(AppTheme.spacingSM)
        .background(AppTheme.surfaceFill, in: RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                .stroke(AppTheme.surfaceStroke, lineWidth: 0.5)
        )
    }
}

#Preview {
    SubscriptionPaywallView()
        .environment(SubscriptionStore())
}
