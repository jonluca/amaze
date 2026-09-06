import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        Form {
            policySection("About this policy", text: "Prism Roll saves your solo game on your device. Online features use services provided by Google and Apple.\n\nPublisher: JonLuca De Caro\nLast updated September 6, 2026.\nPrivacy contact: privacy@thoughtahead.com")

            policySection("Your saved game", text: "Prism Roll stores maze progress, active runs and timers, earned coins, unlocked skins, selected worlds, daily and milestone reward history, and sound/haptic preferences on your device. The app uses this information to resume play and prevent duplicate rewards. Solo play does not require a publisher account, and this version does not upload solo saves to a publisher-operated game server.\n\nDeleting the app removes its local saves; offloading the app keeps its data. Device backups may include saved app data according to your Apple settings. You can manage app storage and device backups in iOS Settings. Prism Roll does not provide its own cloud-save or account-transfer service.")

            policySection("Ads and optional videos", text: "When advertising is enabled, Prism Roll uses Google Mobile Ads to show between-level ads and optional reward videos. Google states that its advertising SDK may process IP addresses and approximate location, device or app identifiers, ad views and interactions, crash information, and performance data for advertising, analytics, and service improvement. The exact processing depends on the advertising configuration and applicable choices.\n\nPrism Roll requests non-personalized Google ads, disables Google’s publisher first-party ID, and enables restricted data processing. These settings limit advertising personalization; the services still process the information described above to deliver and measure ads and operate the service.\n\nReward videos are optional. You can continue solo gameplay when ads are unavailable. No Ads removes between-level advertisements; videos for rewards remain available when you choose them.")

            policySection("Your ad privacy choices", text: "Google's User Messaging Platform manages applicable advertising privacy choices. The app checks the platform's permission to request ads before loading them. When required, you can reopen the choices through Settings → Manage ad privacy.\n\nYou can play solo without signing in to Game Center, choose whether to watch reward videos, adjust available ad-privacy choices, and manage Apple's services through your device and Apple Account settings.")

            policySection("Purchases", text: "If you purchase No Ads, Apple processes payment through the App Store. Prism Roll reads verified StoreKit transaction and entitlement information to enable or restore that benefit and respond to revocation. The app does not receive your payment-card number. StoreKit's verified purchase can be restored through Settings; the purchase does not create a Prism Roll account or restore local game progress.")

            policySection("Game Center Duel", text: "If you choose Duel, Apple's Game Center provides sign-in, matchmaking, and the connection to another player. Prism Roll uses Game Center player identifiers and display names for the match. The players exchange a match identifier, maze seed, painted-tile counts, move counts, completion messages, and the winner identifier to run the race. Solo coins, purchase entitlements, and saved solo progress are not included in those match messages.\n\nDuel state is held in memory for the match and its result screen; this version does not save a match history with your solo progress. Apple separately processes Game Center account and activity information. Your nickname and other profile information may be visible to other players according to your Game Center settings.")

            Section("Provider privacy information") {
                policyLink("Google SDK data disclosure", url: "https://developers.google.com/admob/ios/privacy/data-disclosure")
                policyLink("Google privacy policy", url: "https://policies.google.com/privacy")
                policyLink("Game Center & Privacy", url: "https://www.apple.com/legal/privacy/data/en/game-center/")
                policyLink("App Store & Privacy", url: "https://www.apple.com/legal/privacy/data/en/app-store/")
                Text("Apple and Google describe retention, deletion, and account controls in these policies. Removing Prism Roll does not delete records those services maintain. Requests concerning their services can be directed through those resources. These links require an internet connection.")
                    .font(.footnote).foregroundStyle(Palette.secondary)
            }.listRowBackground(Palette.paper)

            Section("Support and privacy questions") {
                Text("If you email info@thoughtahead.com or privacy@thoughtahead.com, your address, message, and any attachments are shared with the recipient to address your request. Include only the details you want to share. You can use the privacy address to ask about a support conversation or request its deletion.\n\nOur support and privacy webpages contain no analytics scripts, advertising code, or contact forms. Provider links take you to websites governed by their own privacy policies.")
                    .textSelection(.enabled)
                policyLink("Contact support", url: "https://thoughtahead.com/prism-roll/support.html")
                policyLink("Online privacy policy", url: "https://thoughtahead.com/prism-roll/privacy.html")
                policyLink("Email privacy support", url: "mailto:privacy@thoughtahead.com")
            }.listRowBackground(Palette.paper)
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .foregroundStyle(Palette.ink)
        .tint(Palette.violet)
        .navigationTitle("Privacy policy")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("privacyPolicyPage")
    }

    private func policySection(_ title: String, text: String) -> some View {
        Section(title) {
            Text(text).textSelection(.enabled)
        }.listRowBackground(Palette.paper)
    }

    @ViewBuilder
    private func policyLink(_ title: String, url: String) -> some View {
        if let destination = URL(string: url) {
            Link(destination: destination) {
                Label(title, systemImage: "arrow.up.right.square")
            }
        }
    }
}
