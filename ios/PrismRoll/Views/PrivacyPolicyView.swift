import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        Form {
            policySection("About this policy", text: "Prism Roll saves your solo game on your device. Online features use services provided by Google and Apple.\n\nPublisher: JonLuca De Caro\nLast updated September 16, 2026.\nPrivacy contact: privacy@thoughtahead.com")

            policySection("Your saved game", text: "Prism Roll stores maze progress, active runs and timers, earned coins, unlocked skins, selected worlds, daily and milestone reward history, and sound/haptic preferences on your device. The app uses this information to resume play and prevent duplicate rewards. Solo play does not require a publisher account, and this version does not upload solo saves to a publisher-operated game server.\n\nDeleting the app removes its local saves; offloading the app keeps its data. Device backups may include saved app data according to your Apple settings. You can manage app storage and device backups in iOS Settings. Prism Roll does not provide its own cloud-save or account-transfer service.")

            policySection("Optional usage analytics", text: "If you choose to share usage data, Prism Roll uses Google Analytics for Firebase to understand sessions, returning players, screens, modes, level outcomes, hints, rewards, collection choices, and purchase activity. Analytics uses a random app-instance identifier and app/device information; Google may derive approximate location from network information. We do not send your name, email, Game Center identity, saved maze layout, or payment-card details. Analytics advertising-identifier and vendor-identifier collection are disabled, and analytics advertising consent remains denied.\n\nAnalytics starts only after you choose Share usage data. You can decline and keep playing, or change Share usage analytics in Settings. Turning it off stops future analytics collection and resets the analytics identifier on this device; it does not delete reports already received by Google. This choice is separate from advertising privacy choices.")

            policySection("Ads and optional videos", text: "When advertising is enabled, Prism Roll uses Google Mobile Ads to show between-level ads and optional reward videos. Google states that its advertising SDK may process IP addresses and approximate location, device or app identifiers, ad views and interactions, crash information, and performance data for advertising, analytics, and service improvement. The exact processing depends on the advertising configuration and applicable choices.\n\nPrism Roll requests non-personalized Google ads, disables Google’s publisher first-party ID, and enables restricted data processing. These settings limit advertising personalization; the services still process the information described above to deliver and measure ads and operate the service.\n\nReward videos are optional. You can continue solo gameplay when ads are unavailable. No Ads removes between-level advertisements; videos for rewards remain available when you choose them.")

            policySection("Your ad privacy choices", text: "Google's User Messaging Platform manages applicable advertising privacy choices. The app checks the platform's permission to request ads before loading them. When required, you can reopen the choices through Settings → Manage ad privacy.\n\nYou can choose whether to watch reward videos, adjust available ad-privacy choices, and manage Apple's services through your device and Apple Account settings.")

            policySection("Purchases", text: "Apple processes payments for No Ads and coin packs through the App Store. Prism Roll reads verified StoreKit transactions to deliver purchases. The app does not receive your payment-card number.\n\nNo Ads can be restored through Settings and responds to entitlement revocation. Coin balances and delivered transaction identifiers are saved together on this device to prevent duplicate credits. Finished coin purchases cannot be restored after deleting the app or transferred to another device through Prism Roll. Purchases do not create a Prism Roll account or restore local game progress.")

            policySection("Optional crash reports", text: "If you turn on Share saved and future crash reports in Settings, Prism Roll uses Firebase Crashlytics to diagnose crashes and selected save or purchase-delivery errors. Reports include crash stack traces, app and device information, and a Crashlytics installation identifier. Selected error reports contain only a fixed operation category, error domain, and numeric code; we do not add your name, email, Game Center identity, saved maze, receipt, or transaction identifier. If you also enable usage analytics, Crashlytics may include analytics events as breadcrumbs.\n\nReport sharing is off by default and separate from usage analytics and advertising choices. After Firebase starts, Crashlytics can keep crash information locally even while sharing is off. Turning this setting on authorizes sending saved reports, including crashes from before your choice, as well as future reports. Reports from the current run are normally sent on a later opted-in launch. Turning sharing off stops new custom error recording and future upload requests; it cannot cancel reports already authorized for upload or delete reports Google has received.")

            Section("Provider privacy information") {
                policyLink("Firebase Crashlytics data disclosure", url: "https://firebase.google.com/docs/ios/app-store-data-collection")
                policyLink("Firebase Analytics data disclosure", url: "https://support.google.com/analytics/answer/10285841")
                policyLink("Google SDK data disclosure", url: "https://developers.google.com/admob/ios/privacy/data-disclosure")
                policyLink("Google privacy policy", url: "https://policies.google.com/privacy")
                policyLink("App Store & Privacy", url: "https://www.apple.com/legal/privacy/data/en/app-store/")
                Text("Apple and Google describe retention, deletion, and account controls in these policies. Removing Prism Roll does not delete records those services maintain. Requests concerning their services can be directed through those resources. These links require an internet connection.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section("Support and privacy questions") {
                Text("If you email info@thoughtahead.com or privacy@thoughtahead.com, your address, message, and any attachments are shared with the recipient to address your request. Include only the details you want to share. You can use the privacy address to ask about a support conversation or request its deletion.\n\nOur support and privacy webpages contain no analytics scripts, advertising code, or contact forms. Provider links take you to websites governed by their own privacy policies.")
                    .textSelection(.enabled)
                policyLink("Contact support", url: "https://thoughtahead.com/prism-roll/support.html")
                policyLink("Online privacy policy", url: "https://thoughtahead.com/prism-roll/privacy.html")
                policyLink("Email privacy support", url: "mailto:privacy@thoughtahead.com")
            }
        }
        .tint(Palette.violet)
        .navigationTitle("Privacy policy")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("privacyPolicyPage")
    }

    private func policySection(_ title: String, text: String) -> some View {
        Section(title) {
            Text(text).textSelection(.enabled)
        }
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
