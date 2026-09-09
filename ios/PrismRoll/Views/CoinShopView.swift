import StoreKit
import SwiftUI

struct CoinShopView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var purchases: PurchaseService
    @EnvironmentObject private var ads: AdService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var videoStatus: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your balance").font(.subheadline).foregroundStyle(.secondary)
                        CoinBadge(amount: store.progress.points)
                            .accessibilityLabel("\(store.progress.points.formatted()) coins")
                            .accessibilityIdentifier("coinShopBalance")
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    if ads.canShowRewarded {
                        Button(action: watchVideo) {
                            offerLayout {
                                Label("\(GameStore.videoCoinReward) coins", systemImage: "play.rectangle")
                                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 12) }
                                Text("Watch ad").foregroundStyle(Palette.violet)
                            }
                            .frame(minHeight: 36, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(purchases.isBusy || store.isRewardPending || ads.isPresenting || ads.isPrivacyFormPresenting)
                        .accessibilityLabel("Watch an ad for \(GameStore.videoCoinReward) coins")
                        .accessibilityIdentifier("watchCoinAd")
                    } else {
                        Label(ads.rewardedAvailability == .loading ? "Loading a video…" : "No video available right now.",
                              systemImage: "play.rectangle")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Check for a video") { ads.prepare() }
                            .disabled(ads.isPresenting || ads.isPrivacyFormPresenting || ads.rewardedAvailability == .loading)
                            .accessibilityIdentifier("retryCoinAd")
                    }
                    if let videoStatus {
                        Text(videoStatus).foregroundStyle(.secondary)
                            .accessibilityIdentifier("coinAdStatus")
                    }
                } header: {
                    Text("Free coins")
                } footer: {
                    Text("Earn 50 coins per completed video.")
                }

                Section {
                    ForEach(purchases.coinProducts, id: \.id) { product in
                        if let pack = CoinPack.catalog.first(where: { $0.id == product.id }) {
                            Button {
                                Task { await purchases.purchaseCoins(productID: product.id) }
                            } label: {
                                offerLayout {
                                    CoinBadge(amount: pack.coins)
                                    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 12) }
                                    Text(product.displayPrice)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Palette.violet)
                                }
                                .frame(minHeight: 36, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(purchases.isBusy || store.isRewardPending || ads.isPresenting || ads.isPrivacyFormPresenting)
                            .accessibilityLabel("Buy \(pack.coins.formatted()) coins for \(product.displayPrice)")
                            .accessibilityIdentifier("buyCoins_\(pack.coins)")
                        }
                    }
                    if purchases.isBusy {
                        ProgressView("Contacting the App Store…")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if purchases.coinStatus != "Choose a coin pack." {
                        Text(purchases.coinStatus)
                            .font(.subheadline).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("coinPurchaseStatus")
                    }
                    if purchases.coinProducts.isEmpty && !purchases.isBusy {
                        Button("Reload coin packs") { Task { await purchases.load() } }
                            .accessibilityIdentifier("reloadCoinPacks")
                    }
                } header: {
                    Text("Coin packs")
                } footer: {
                    Text("Coins are saved on this device. Finished coin purchases cannot be restored after deleting the app.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Coins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("coinShopDone")
                }
            }
            .interactiveDismissDisabled(purchases.isBusy || store.isRewardPending)
            .task { ads.prepare(); await purchases.load() }
        }
        .tint(Palette.violet)
    }

    private var offerLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))
    }

    private func watchVideo() {
        guard ads.canShowRewarded, let requestID = store.beginCoinReward() else { return }
        videoStatus = nil
        ads.presentRewarded(onReward: {
            let amount = store.claimCoinReward(requestID)
            videoStatus = amount > 0 ? "Added \(amount) coins." : "Coins could not be saved. Please try again."
        }, onDismiss: {
            store.finishReward()
            if videoStatus == nil { videoStatus = "Complete a video to earn coins." }
        })
    }
}
