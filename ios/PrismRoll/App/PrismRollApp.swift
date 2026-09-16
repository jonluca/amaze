import SwiftUI
import GoogleMobileAds

@main
struct PrismRollApp: App {
    init() {
        // AdMob's exception handlers otherwise replace Crashlytics' handlers.
        MobileAds.shared.disableSDKCrashReporting()
        DiagnosticsService.shared.configure()
        AnalyticsService.shared.configure()
        _store = StateObject(wrappedValue: GameStore())
    }

    @StateObject private var store: GameStore
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
                .task { await DiagnosticsService.shared.runDebugSmokeCrashIfRequested() }
        }
    }
}
