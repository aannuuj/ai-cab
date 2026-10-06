import Foundation
import StoreKit
import Observation

/// StoreKit 2 subscriptions: products, entitlements, purchase and restore.
@MainActor
@Observable
final class PurchaseManager {
    enum ProductID {
        static let yearly = "com.aicab.pro.yearly"
        static let monthly = "com.aicab.pro.monthly"
        static let lifetime = "com.aicab.pro.lifetime"
        static let all = [yearly, monthly, lifetime]
    }

    private(set) var products: [Product] = []
    private(set) var purchasedIDs: Set<String> = []
    /// Set while the active entitlement is an introductory free trial.
    private(set) var trialEndDate: Date?
    private(set) var isEligibleForTrial = true
    private(set) var isLoading = false
    var lastError: String?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    var isPro: Bool { !purchasedIDs.isEmpty }
    var yearly: Product? { products.first { $0.id == ProductID.yearly } }
    var monthly: Product? { products.first { $0.id == ProductID.monthly } }
    var lifetime: Product? { products.first { $0.id == ProductID.lifetime } }

    func start() async {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await Product.products(for: ProductID.all)
            products = loaded.sorted { ProductID.all.firstIndex(of: $0.id) ?? 0 < ProductID.all.firstIndex(of: $1.id) ?? 0 }
            if let subscription = yearly?.subscription {
                isEligibleForTrial = await subscription.isEligibleForIntroOffer
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        var ids = Set<String>()
        var trialEnd: Date?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil else { continue }
            ids.insert(transaction.productID)
            if transaction.offer?.type == .introductory, let expiry = transaction.expirationDate, expiry > Date() {
                trialEnd = expiry
            }
        }
        purchasedIDs = ids
        trialEndDate = trialEnd
    }

    /// Returns true when the purchase completed and Pro is unlocked.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        lastError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    lastError = "We couldn't verify that purchase."
                    return false
                }
                await transaction.finish()
                await refreshEntitlements()
                return isPro
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            lastError = error.localizedDescription
        }
        await refreshEntitlements()
    }

    // MARK: - Display helpers

    func trialDays(for product: Product?) -> Int? {
        guard isEligibleForTrial, let offer = product?.subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        let period = offer.period
        switch period.unit {
        case .day: return period.value
        case .week: return period.value * 7
        case .month: return period.value * 30
        case .year: return period.value * 365
        @unknown default: return nil
        }
    }

    /// "₹166.58/month" for an annual plan.
    func monthlyEquivalent(of product: Product) -> String? {
        guard product.subscription?.subscriptionPeriod.unit == .year else { return nil }
        let monthly = product.price / 12
        return monthly.formatted(product.priceFormatStyle) + "/month"
    }

    func zeroPrice(like product: Product) -> String {
        Decimal(0).formatted(product.priceFormatStyle)
    }
}
