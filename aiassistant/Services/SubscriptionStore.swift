import Foundation
import StoreKit

@MainActor
@Observable
final class SubscriptionStore {
    enum LoadingState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    enum PurchaseOutcome: Equatable {
        case purchased
        case pending
        case cancelled
        case failed(String)
    }

    private let catalog: SubscriptionCatalog
    private var transactionUpdatesTask: Task<Void, Never>?

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var activeSubscriptionTier: AppSubscriptionTier = .free
    private(set) var hasLifetimeAccess = false
    private(set) var loadingState: LoadingState = .idle
    private(set) var purchaseInProgressProductID: String?
    private(set) var lastPurchaseOutcome: PurchaseOutcome?
    var errorMessage: String?

    init(catalog: SubscriptionCatalog = .ariPlus) {
        self.catalog = catalog
    }

    var subscriptionProducts: [Product] {
        catalog.subscriptionProductIDs.compactMap(product)
    }

    var lifetimeProduct: Product? {
        product(for: catalog.lifetimeProductID)
    }

    var hasPremiumAccess: Bool {
        activeSubscriptionTier != .free || hasLifetimeAccess
    }

    var entitlementDescription: String {
        if hasLifetimeAccess {
            "Lifetime"
        } else {
            activeSubscriptionTier.displayName
        }
    }

    func start() async {
        if transactionUpdatesTask == nil {
            transactionUpdatesTask = observeTransactionUpdates()
        }

        await refresh()
    }

    func refresh() async {
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        loadingState = .loading

        do {
            let loadedProducts = try await Product.products(for: catalog.allProductIDs)
            products = loadedProducts.sorted { lhs, rhs in
                productRank(lhs.id) < productRank(rhs.id)
            }
            loadingState = .loaded
            errorMessage = nil
        } catch {
            let message = error.localizedDescription
            loadingState = .failed(message)
            errorMessage = "Could not load subscription products. \(message)"
        }
    }

    @discardableResult
    func purchase(_ product: Product) async -> PurchaseOutcome {
        purchaseInProgressProductID = product.id
        defer { purchaseInProgressProductID = nil }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                lastPurchaseOutcome = .purchased
                errorMessage = nil
                return .purchased
            case .pending:
                lastPurchaseOutcome = .pending
                errorMessage = "Purchase is pending approval."
                return .pending
            case .userCancelled:
                lastPurchaseOutcome = .cancelled
                return .cancelled
            @unknown default:
                let message = "StoreKit returned an unknown purchase result."
                lastPurchaseOutcome = .failed(message)
                errorMessage = message
                return .failed(message)
            }
        } catch {
            let message = error.localizedDescription
            lastPurchaseOutcome = .failed(message)
            errorMessage = "Purchase failed. \(message)"
            return .failed(message)
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            errorMessage = nil
        } catch {
            errorMessage = "Restore failed. \(error.localizedDescription)"
        }
    }

    private func product(for productID: String) -> Product? {
        products.first { $0.id == productID }
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }

                do {
                    let transaction = try self.checkVerified(result)
                    await transaction.finish()
                    await self.refreshEntitlements()
                } catch {
                    self.errorMessage = "A transaction could not be verified."
                }
            }
        }
    }

    private func refreshEntitlements() async {
        var activeProductIDs: Set<String> = []

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                guard catalog.productIDSet.contains(transaction.productID),
                      transaction.revocationDate == nil,
                      !transaction.isUpgraded else {
                    continue
                }
                activeProductIDs.insert(transaction.productID)
            } catch {
                errorMessage = "A current entitlement could not be verified."
            }
        }

        purchasedProductIDs = activeProductIDs
        hasLifetimeAccess = activeProductIDs.contains(catalog.lifetimeProductID)
        activeSubscriptionTier = activeProductIDs
            .compactMap(AppSubscriptionTier.init(productID:))
            .max() ?? .free
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            safe
        case .unverified:
            throw SubscriptionVerificationError.failedVerification
        }
    }

    private func productRank(_ productID: String) -> Int {
        if let subscriptionIndex = catalog.subscriptionProductIDs.firstIndex(of: productID) {
            return subscriptionIndex
        }

        if productID == catalog.lifetimeProductID {
            return catalog.subscriptionProductIDs.count
        }

        return Int.max
    }
}

private enum SubscriptionVerificationError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        "StoreKit could not verify this transaction."
    }
}
