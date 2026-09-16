import Combine
import Foundation
import StoreKit

/// StoreKit is the source of truth. No local flag can create a paid entitlement.
@MainActor
final class PurchaseService: ObservableObject {
    enum PurchaseOutcome: String {
        case success, cancelled, pending, unavailable, unverified, inactive, failed, unknown
        case deliveryPending = "delivery_pending"
    }

    @Published private(set) var product: Product?
    @Published private(set) var coinProducts: [Product] = []
    @Published private(set) var removesAds = false
    @Published private(set) var isBusy = false
    @Published private(set) var status = "Checking purchases…"
    @Published private(set) var coinStatus = "Checking coin packs…"
    private let productID: String
    private let analytics: any AnalyticsRecording
    private let diagnostics: any DiagnosticsRecording
    private var updatesTask: Task<Void, Never>?
    private var deliverCoins: (@MainActor (CoinPurchase) throws -> CoinDeliveryResult)?

    init(bundle: Bundle = .main,
         analytics: (any AnalyticsRecording)? = nil,
         diagnostics: (any DiagnosticsRecording)? = nil,
         deliverCoins: (@MainActor (CoinPurchase) throws -> CoinDeliveryResult)? = nil) {
        let configured = (bundle.object(forInfoDictionaryKey: "PrismRemoveAdsProductID") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        productID = configured.flatMap { $0.isEmpty ? nil : $0 } ?? "com.jonluca.prismroll.removeads"
        self.analytics = analytics ?? AnalyticsService.shared
        self.diagnostics = diagnostics ?? DiagnosticsService.shared
        self.deliverCoins = deliverCoins
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { break }
                await self?.receiveUpdate(result)
            }
        }
    }

    deinit { updatesTask?.cancel() }

    /// The wallet must commit both the currency and transaction ID before returning.
    /// Attach it before `load()`; purchases remain unfinished while no wallet is attached.
    func configureCoinDelivery(_ delivery: @escaping @MainActor (CoinPurchase) throws -> CoinDeliveryResult) {
        deliverCoins = delivery
    }

    func load() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        await refreshEntitlements()
        await recoverUnfinishedPurchases()
        do {
            let products = try await Product.products(for: [productID] + CoinPack.catalog.map(\.id))
            product = products.first { $0.id == productID && $0.type == .nonConsumable }
            coinProducts = CoinPack.catalog.compactMap { pack in
                products.first { $0.id == pack.id && $0.type == .consumable }
            }
            status = removesAds ? "Between-level ads are removed. Optional reward videos remain available." :
                product == nil ? "No Ads is not available from the App Store yet." :
                "Remove between-level ads with a one-time purchase."
            if !coinStatus.hasPrefix("Added ") && !coinStatus.hasPrefix("Your purchase is saved") {
                coinStatus = coinProducts.isEmpty ? "Coin packs are unavailable. Try again later." :
                    "Choose a coin pack."
            }
        } catch {
            diagnostics.record(error: error, operation: .storeLoad)
            product = nil
            coinProducts = []
            status = removesAds ? "No Ads is active. The store could not refresh right now." :
                "The App Store could not load this purchase. Try again later."
            coinStatus = "The App Store could not load coin packs. Try again later."
        }
    }

    func purchaseCoins(productID: String) async {
        guard !isBusy else { return }
        recordPurchaseStarted(productID: productID)
        guard deliverCoins != nil,
              let product = coinProducts.first(where: { $0.id == productID }) else {
            coinStatus = "This coin pack is unavailable. Try again later."
            recordPurchaseResult(.unavailable, productID: productID)
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                let outcome = await receiveCoinPurchase(result, expectedProductID: productID)
                recordPurchaseResult(outcome, productID: productID)
            case .userCancelled:
                coinStatus = "Purchase cancelled."
                recordPurchaseResult(.cancelled, productID: productID)
            case .pending:
                coinStatus = "Your purchase is awaiting approval."
                recordPurchaseResult(.pending, productID: productID)
            @unknown default:
                coinStatus = "The App Store could not complete this purchase."
                recordPurchaseResult(.unknown, productID: productID)
            }
        } catch StoreKitError.userCancelled {
            coinStatus = "Purchase cancelled."
            recordPurchaseResult(.cancelled, productID: productID)
        } catch {
            coinStatus = "The purchase could not complete. Please try again."
            recordPurchaseResult(.failed, productID: productID)
        }
    }

    func purchase() async {
        guard !isBusy else { return }
        recordPurchaseStarted(productID: productID)
        guard let product else {
            status = "No Ads is not available from the App Store yet."
            recordPurchaseResult(.unavailable, productID: productID)
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification, transaction.productID == productID else {
                    status = "The purchase could not be verified. No entitlement was changed."
                    recordPurchaseResult(.unverified, productID: productID)
                    return
                }
                await refreshEntitlements()
                await transaction.finish()
                status = removesAds ? "No Ads is active. Thank you!" : "This purchase is not currently active."
                recordPurchaseResult(removesAds ? .success : .inactive, productID: productID)
            case .userCancelled:
                status = "Purchase cancelled."
                recordPurchaseResult(.cancelled, productID: productID)
            case .pending:
                status = "Your purchase is awaiting approval."
                recordPurchaseResult(.pending, productID: productID)
            @unknown default:
                status = "The App Store could not complete this purchase."
                recordPurchaseResult(.unknown, productID: productID)
            }
        } catch {
            status = "The purchase could not complete. Please try again."
            if case StoreKitError.userCancelled = error {
                recordPurchaseResult(.cancelled, productID: productID)
            } else {
                recordPurchaseResult(.failed, productID: productID)
            }
        }
    }

    func restore() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            // Explicit Restore action only; StoreKit may display an account prompt.
            try await AppStore.sync()
            await refreshEntitlements()
            await recoverUnfinishedPurchases()
            status = removesAds ? "No Ads restored." : "No active No Ads purchase was found for this Apple account."
        } catch {
            status = "Purchases could not be restored. Please try again."
        }
    }

    /// Finished consumables are intentionally excluded: this device's durable wallet
    /// already accounts for them. Replaying full history would recreate spent coins.
    func recoverUnfinishedPurchases() async {
        for await result in Transaction.unfinished {
            guard !Task.isCancelled else { return }
            await receiveUpdate(result)
        }
    }

    private func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == productID,
                  transaction.revocationDate == nil,
                  transaction.expirationDate.map({ $0 > Date() }) ?? true else { continue }
            entitled = true
        }
        removesAds = entitled
    }

    private func receiveUpdate(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        if CoinPack.catalog.contains(where: { $0.id == transaction.productID }) {
            await receiveCoinPurchase(result)
            return
        }
        guard transaction.productID == productID, transaction.productType == .nonConsumable else { return }
        await refreshEntitlements()
        await transaction.finish()
        status = removesAds ? "No Ads is active." : "No Ads is no longer active for this account."
    }

    @discardableResult
    func receiveCoinPurchase(_ result: VerificationResult<Transaction>, expectedProductID: String? = nil) async -> PurchaseOutcome {
        guard case .verified(let transaction) = result,
              transaction.productType == .consumable,
              CoinPack.catalog.contains(where: { $0.id == transaction.productID }),
              expectedProductID.map({ $0 == transaction.productID }) ?? true else {
            coinStatus = "The purchase could not be verified. No coins were added."
            return .unverified
        }
        guard transaction.revocationDate == nil, !transaction.isUpgraded,
              transaction.expirationDate.map({ $0 > Date() }) ?? true else {
            // A refunded transaction must never deliver currency, including on recovery.
            await transaction.finish()
            coinStatus = "This purchase is no longer active. No coins were added."
            return .inactive
        }
        guard let deliverCoins else { return .deliveryPending }
        let purchase = CoinPurchase(transactionID: String(transaction.id), productID: transaction.productID,
                                    quantity: transaction.purchasedQuantity)
        guard purchase.coins != nil else {
            coinStatus = "The purchase could not be verified. No coins were added."
            return .unverified
        }
        do {
            // No suspension between checking the ledger and saving the credit. The
            // wallet owns idempotency if updates and purchase completion overlap.
            let delivery = try deliverCoins(purchase)
            await transaction.finish()
            switch delivery {
            case .credited(let coins): coinStatus = "Added \(coins.formatted()) coins."
            case .alreadyDelivered: coinStatus = "This purchase is already in your balance."
            }
            return .success
        } catch {
            // Leave the StoreKit transaction unfinished so launch/Retry can deliver it.
            diagnostics.record(error: error, operation: .coinDelivery)
            coinStatus = "Your purchase is saved by the App Store. Reopen the shop to finish adding your coins."
            return .deliveryPending
        }
    }

    private func recordPurchaseStarted(productID: String) {
        guard isCatalogProduct(productID) else { return }
        analytics.record("purchase_started", parameters: ["product_id": productID])
    }

    private func recordPurchaseResult(_ result: PurchaseOutcome, productID: String) {
        guard isCatalogProduct(productID) else { return }
        // Count the explicit purchase attempt once. StoreKit updates and recovery
        // must not duplicate this funnel or Firebase's automatic in_app_purchase.
        analytics.record("purchase_result", parameters: ["product_id": productID, "result": result.rawValue])
    }

    private func isCatalogProduct(_ id: String) -> Bool {
        id == productID || CoinPack.catalog.contains { $0.id == id }
    }
}
