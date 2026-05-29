import SwiftUI
import StoreKit
import FlexStore

struct SubscriptionPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.persistenceMode) private var persistenceMode
    @Environment(StoreKitService<AppSubscriptionTier>.self) private var flexStore

    let context: SubscriptionPaywallContext

    @State private var selectedProductID = Monetization.subscriptionYearlyID
    @State private var purchasingProductID: String?
    @State private var errorMessage: String?

    private let subscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions") ?? URL(fileURLWithPath: "/")
    private let productOrder = [
        Monetization.subscriptionYearlyID,
        Monetization.subscriptionMonthlyID,
        Monetization.subscriptionWeeklyID
    ]

    init(context: SubscriptionPaywallContext = .general) {
        self.context = context
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.spacingXL) {
                    paywallHero
                    includedFeatures
                    subscriptionPlans
                    subscribeButton
                    if shouldShowLifetimeSection {
                        lifetimeSection
                    }
                    policySection
                }
                .padding(.horizontal, AppTheme.spacingXL)
                .padding(.top, AppTheme.spacingLG)
                .padding(.bottom, AppTheme.spacingXL)
            }
            .background(AppBackground())
            .navigationTitle("Upgrade")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            #if os(macOS)
            .frame(minWidth: 620, minHeight: 760)
            #endif
        }
        .tint(AppTheme.paywallTint)
        .task {
            await refreshProductsAndEntitlements()
            syncSelection()
        }
        .onChange(of: flexStore.products.map(\.id)) { _, _ in
            syncSelection()
        }
        .onChange(of: hasPremiumAccess) { _, hasAccess in
            if hasAccess {
                dismiss()
            }
        }
        .alert("Purchase Error", isPresented: errorBinding) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    private var hasPremiumAccess: Bool {
        flexStore.isSubscribed || flexStore.purchasedNonConsumables.contains(Monetization.lifetimeID)
    }

    private var subscriptionProducts: [Product] {
        productOrder.compactMap { flexStore.product(for: $0) }
    }

    private var selectedProduct: Product? {
        flexStore.product(for: selectedProductID) ?? subscriptionProducts.first
    }

    private var lifetimeProduct: Product? {
        flexStore.product(for: Monetization.lifetimeID)
    }

    private var shouldShowLifetimeSection: Bool {
        flexStore.isLoading || lifetimeProduct != nil || !flexStore.products.isEmpty
    }

    private var displayedFeatures: [PaywallFeature] {
        if persistenceMode.isLocalOnly {
            Monetization.paywallFeatures.filter { $0.title != "Priority sync" }
        } else {
            Monetization.paywallFeatures
        }
    }

    private var paywallHero: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMD) {
            Image(systemName: context.icon)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(AppTheme.brandGradient)
                .frame(width: 72, height: 72)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(AppTheme.brandWash)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(AppTheme.accent.opacity(0.18), lineWidth: 1)
                )

            Text(context.eyebrow.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.accent)
                .tracking(0.8)

            Text(context.title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(context.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var includedFeatures: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMD) {
            Text("What's included")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)

            if persistenceMode.isLocalOnly, let message = persistenceMode.userMessage {
                AppBanner(
                    systemImage: "icloud.slash",
                    message: message,
                    tint: AppTheme.warning
                )
            }

            VStack(spacing: AppTheme.spacingSM) {
                ForEach(displayedFeatures) { feature in
                    PaywallFeatureRow(feature: feature)
                }
            }
        }
    }

    private var subscriptionPlans: some View {
        VStack(spacing: AppTheme.spacingLG) {
            if flexStore.isLoading && subscriptionProducts.isEmpty {
                ProgressView("Loading plans...")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.spacingXL)
            } else if subscriptionProducts.isEmpty {
                ContentUnavailableView {
                    Label("Plans unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("Ari could not load subscription plans. Check your connection and try again.")
                } actions: {
                    Button("Retry") {
                        Task {
                            await refreshProductsAndEntitlements()
                            syncSelection()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("paywall.plans.retry")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.spacingXL)
            } else {
                ForEach(subscriptionProducts, id: \.id) { product in
                    SubscriptionPlanCard(
                        product: product,
                        isSelected: selectedProductID == product.id,
                        action: { selectedProductID = product.id }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var subscribeButton: some View {
        if let selectedProduct {
            Button {
                purchase(selectedProduct)
            } label: {
                VStack(spacing: 4) {
                    if purchasingProductID == selectedProduct.id {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Text("Subscribe")
                            .font(.title3.weight(.bold))
                    }

                    Text(renewalDisclosure(for: selectedProduct))
                        .font(.footnote.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 58)
            }
            .buttonStyle(.plain)
            .background(AppTheme.brandGradient, in: Capsule())
            .shadow(color: AppTheme.accent.opacity(0.3), radius: 12, y: 5)
            .disabled(purchasingProductID != nil)
            .accessibilityLabel("Subscribe. \(renewalDisclosure(for: selectedProduct))")
        }
    }

    private var lifetimeSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMD) {
            Text("Or own it forever")
                .font(.title3.weight(.bold))

            Text("Lifetime access is a one-time purchase and priced higher than subscriptions.")
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                if let lifetimeProduct {
                    purchase(lifetimeProduct)
                }
            } label: {
                if purchasingProductID == Monetization.lifetimeID {
                    HStack(spacing: AppTheme.spacingSM) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                        Text("Purchasing...")
                    }
                } else if flexStore.purchasedNonConsumables.contains(Monetization.lifetimeID) {
                    Label("Lifetime Active", systemImage: "checkmark.circle.fill")
                } else {
                    Text(lifetimeProduct == nil ? "Loading Lifetime Access" : "Buy Lifetime Access")
                }
            }
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, AppTheme.spacingXL)
            .frame(minHeight: AppTheme.minimumTapTarget)
            .background(AppTheme.paywallTint, in: Capsule())
            .buttonStyle(.plain)
            .disabled(lifetimeProduct == nil || purchasingProductID != nil || flexStore.purchasedNonConsumables.contains(Monetization.lifetimeID))
        }
        .padding(.top, AppTheme.spacingXL)
    }

    private var policySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMD) {
            HStack {
                Button("Restore Purchases") {
                    Task {
                        await flexStore.restorePurchases()
                    }
                }

                Spacer()

                Button {
                    openURL(subscriptionsURL)
                } label: {
                    Label("Manage Subscriptions", systemImage: "gearshape")
                }
            }

            HStack(spacing: AppTheme.spacingXL) {
                Link("Privacy Policy", destination: Monetization.privacyPolicyURL)
                Link("Terms of Service", destination: Monetization.termsOfServiceURL)
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
    }

    private func purchase(_ product: Product) {
        guard purchasingProductID == nil else { return }

        purchasingProductID = product.id
        Task {
            defer { purchasingProductID = nil }

            do {
                let outcome = try await flexStore.purchase(product)
                await refreshProductsAndEntitlements()
                switch outcome {
                case .success:
                    dismiss()
                case .cancelled:
                    break
                case .pending:
                    errorMessage = "Purchase is pending approval."
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func syncSelection() {
        if flexStore.product(for: selectedProductID) == nil,
           let firstProduct = subscriptionProducts.first {
            selectedProductID = firstProduct.id
        }
    }

    private func refreshProductsAndEntitlements() async {
        if flexStore.products.isEmpty {
            await flexStore.loadProducts(Monetization.productIDs)
        }
        await flexStore.refreshSubscriptionStatus(groupID: Monetization.subscriptionGroupID)
    }

    private func renewalDisclosure(for product: Product) -> String {
        switch product.id {
        case Monetization.subscriptionYearlyID:
            "Plan auto-renews for \(product.displayPrice)/year until canceled."
        case Monetization.subscriptionMonthlyID:
            "Plan auto-renews for \(product.displayPrice)/month until canceled."
        case Monetization.subscriptionWeeklyID:
            "Plan auto-renews for \(product.displayPrice)/week until canceled."
        default:
            "\(product.displayPrice) one-time purchase."
        }
    }
}

private struct PaywallFeatureRow: View {
    let feature: PaywallFeature

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingMD) {
            Image(systemName: feature.icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(feature.accentColor)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                Text(feature.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(feature.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, AppTheme.spacingLG)
        .padding(.vertical, AppTheme.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surfaceFill, in: RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                .stroke(AppTheme.surfaceStroke, lineWidth: 0.6)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct SubscriptionPlanCard: View {
    let product: Product
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppTheme.spacingLG) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
                        Text(product.displayName)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)

                        Text(priceLine(for: product))
                            .font(.headline.weight(.regular))
                            .foregroundStyle(.primary)
                    }

                    Spacer(minLength: AppTheme.spacingMD)

                    SelectionIndicator(isSelected: isSelected)
                }

                Divider()

                Label(descriptionLine(for: product), systemImage: icon(for: product.id))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AppTheme.spacingLG)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surfaceFill, in: RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                    .stroke(isSelected ? AppTheme.paywallTint : AppTheme.surfaceStrokeStrong, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(product.displayName), \(priceLine(for: product)), \(descriptionLine(for: product))")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityIdentifier("paywall.plan.\(product.id)")
    }

    private func priceLine(for product: Product) -> String {
        switch product.id {
        case Monetization.subscriptionYearlyID:
            "\(product.displayPrice)/year"
        case Monetization.subscriptionMonthlyID:
            "\(product.displayPrice)/month"
        case Monetization.subscriptionWeeklyID:
            "3 days free, then \(product.displayPrice)/week"
        default:
            product.displayPrice
        }
    }

    private func descriptionLine(for product: Product) -> String {
        switch product.id {
        case Monetization.subscriptionYearlyID:
            "Best value yearly premium access."
        case Monetization.subscriptionMonthlyID:
            "Monthly premium access."
        case Monetization.subscriptionWeeklyID:
            "Weekly premium access with a 3-day free trial."
        default:
            product.description
        }
    }

    private func icon(for productID: String) -> String {
        switch productID {
        case Monetization.subscriptionYearlyID:
            "calendar.badge.checkmark"
        case Monetization.subscriptionMonthlyID:
            "calendar"
        case Monetization.subscriptionWeeklyID:
            "calendar.badge.clock"
        default:
            "sparkles"
        }
    }
}

private struct SelectionIndicator: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(isSelected ? AppTheme.paywallTint : AppTheme.surfaceStrokeStrong, lineWidth: 2)
                .frame(width: 28, height: 28)

            if isSelected {
                Circle()
                    .fill(AppTheme.paywallTint)
                    .frame(width: 28, height: 28)

                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    SubscriptionPaywallView()
        .environment(StoreKitService<AppSubscriptionTier>())
}
