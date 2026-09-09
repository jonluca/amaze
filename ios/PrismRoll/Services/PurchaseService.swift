import Combine
import Foundation
import StoreKit

/// StoreKit is the source of truth. No local flag can create a paid entitlement.
@MainActor
final class PurchaseService: ObservableObject {
    @Published private(set) var product: Product?
    @Published private(set) var coinProducts: [Product] = []
    @Published private(set) var removesAds = false
    @Published private(set) var isBusy = false
    @Published private(set) var status = "Checking purchases…"
    @Published private(set) var coinStatus = "Checking coin packs…"
    private let productID: String
    private var updatesTask: Task<Void, Never>?
    private var deliverCoins: (@MainActor (CoinPurchase) throws -> CoinDeliveryResult)?

    init(bundle: Bundle = .main,
         deliverCoins: (@MainActor (CoinPurchase) throws -> CoinDeliveryResult)? = nil) {
        let configured = (bundle.object(forInfoDictionaryKey: "PrismRemoveAdsProductID") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        productID = configured.flatMap { $0.isEmpty ? nil : $0 } ?? "com.jonluca.prismroll.removeads"
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
            product = nil
            coinProducts = []
            status = removesAds ? "No Ads is active. The store could not refresh right now." :
                "The App Store could not load this purchase. Try again later."
            coinStatus = "The App Store could not load coin packs. Try again later."
        }
    }

    func purchaseCoins(productID: String) async {
        guard !isBusy else { return }
        guard deliverCoins != nil,
              let product = coinProducts.first(where: { $0.id == productID }) else {
            coinStatus = "This coin pack is unavailable. Try again later."
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                await receiveCoinPurchase(result, expectedProductID: productID)
            case .userCancelled:
                coinStatus = "Purchase cancelled."
            case .pending:
                coinStatus = "Your purchase is awaiting approval."
            @unknown default:
                coinStatus = "The App Store could not complete this purchase."
            }
        } catch StoreKitError.userCancelled {
            coinStatus = "Purchase cancelled."
        } catch {
            coinStatus = "The purchase could not complete. Please try again."
        }
    }

    func purchase() async {
        guard !isBusy else { return }
        guard let product else {
            status = "No Ads is not available from the App Store yet."
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification, transaction.productID == productID else {
                    status = "The purchase could not be verified. No entitlement was changed."
                    return
                }
                await refreshEntitlements()
                await transaction.finish()
                status = removesAds ? "No Ads is active. Thank you!" : "This purchase is not currently active."
            case .userCancelled:
                status = "Purchase cancelled."
            case .pending:
                status = "Your purchase is awaiting approval."
            @unknown default:
                status = "The App Store could not complete this purchase."
            }
        } catch {
            status = "The purchase could not complete. Please try again."
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

    func receiveCoinPurchase(_ result: VerificationResult<Transaction>, expectedProductID: String? = nil) async {
        guard case .verified(let transaction) = result,
              transaction.productType == .consumable,
              CoinPack.catalog.contains(where: { $0.id == transaction.productID }),
              expectedProductID.map({ $0 == transaction.productID }) ?? true else {
            coinStatus = "The purchase could not be verified. No coins were added."
            return
        }
        guard transaction.revocationDate == nil, !transaction.isUpgraded,
              transaction.expirationDate.map({ $0 > Date() }) ?? true else {
            // A refunded transaction must never deliver currency, including on recovery.
            await transaction.finish()
            coinStatus = "This purchase is no longer active. No coins were added."
            return
        }
        guard let deliverCoins else { return }
        let purchase = CoinPurchase(transactionID: String(transaction.id), productID: transaction.productID,
                                    quantity: transaction.purchasedQuantity)
        guard purchase.coins != nil else {
            coinStatus = "The purchase could not be verified. No coins were added."
            return
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
        } catch {
            // Leave the StoreKit transaction unfinished so launch/Retry can deliver it.
            coinStatus = "Your purchase is saved by the App Store. Reopen the shop to finish adding your coins."
        }
    }
}
