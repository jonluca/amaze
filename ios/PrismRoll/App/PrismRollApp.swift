import SwiftUI

@main
struct PrismRollApp: App {
    @StateObject private var store = GameStore()
    @StateObject private var ads = AdService()
    @StateObject private var duel = DuelService()
    @StateObject private var purchases = PurchaseService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(ads)
                .environmentObject(duel)
                .environmentObject(purchases)
                .preferredColorScheme(.dark)
        }
    }
}
