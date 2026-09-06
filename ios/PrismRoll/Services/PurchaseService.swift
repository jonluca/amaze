import Combine
import Foundation
import StoreKit

/// StoreKit is the source of truth. No local flag can create a paid entitlement.
@MainActor
final class PurchaseService: ObservableObject {
    @Published private(set) var product: Product?
    @Published private(set) var removesAds = false
    @Published private(set) var isBusy = false
    @Published private(set) var status = "Checking purchases…"
    private let productID: String
    private var updatesTask: Task<Void, Never>?

    init(bundle: Bundle = .main) {
        let configured = (bundle.object(forInfoDictionaryKey: "PrismRemoveAdsProductID") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        productID = configured.flatMap { $0.isEmpty ? nil : $0 } ?? "com.jonluca.prismroll.removeads"
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { break }
                await self?.receiveUpdate(result)
            }
        }
    }

    deinit { updatesTask?.cancel() }

    func load() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        await refreshEntitlements()
        do {
            product = try await Product.products(for: [productID]).first { $0.id == productID && $0.type == .nonConsumable }
            status = removesAds ? "Between-level ads are removed. Optional reward videos remain available." :
                product == nil ? "No Ads is not available from the App Store yet." :
                "Remove between-level ads with a one-time purchase."
        } catch {
            product = nil
            status = removesAds ? "No Ads is active. The store could not refresh right now." :
                "The App Store could not load this purchase. Try again later."
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
            status = removesAds ? "No Ads restored." : "No active No Ads purchase was found for this Apple account."
        } catch {
            status = "Purchases could not be restored. Please try again."
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
        guard case .verified(let transaction) = result, transaction.productID == productID else { return }
        await refreshEntitlements()
        await transaction.finish()
        status = removesAds ? "No Ads is active." : "No Ads is no longer active for this account."
    }
}
