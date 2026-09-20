import SwiftUI

struct AnalyticsConsentView: View {
    @ObservedObject private var analytics = AnalyticsService.shared
    @ObservedObject private var attribution = AppsFlyerAttributionService.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Help us understand which modes you enjoy and where puzzles get difficult.")
                    Text("If you agree, Google Analytics receives gameplay, feature use, purchase activity, app and device information, and a random app-instance identifier. Analytics does not receive your name, email, Game Center identity, or advertising identifier.")
                    if attribution.isAvailable {
                        Text("AppsFlyer also receives install and app-session information, campaign attribution when available, app and device information, IP address, and an installation identifier. This helps us understand how people find Prism Roll. AppsFlyer advertising and vendor identifiers, personalized advertising, and sharing with advertising partners are disabled.")
                    }
                    Text("Sharing is optional. You can change your choice in Settings at any time.")
                    NavigationLink("Privacy policy") { PrivacyPolicyView() }
                }
                Section {
                    Button("Share usage data") {
                        analytics.setEnabled(true)
                        if attribution.isAvailable { attribution.setEnabled(true) }
                        analytics.screen("play")
                    }
                    .accessibilityIdentifier("analyticsAllow")
                    Button("Not now") {
                        if attribution.isAvailable { attribution.setEnabled(false) }
                        analytics.setEnabled(false)
                    }
                        .accessibilityIdentifier("analyticsDecline")
                }
            }
            .navigationTitle("Help improve Prism Roll")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Palette.violet)
        }
        .interactiveDismissDisabled()
        .preferredColorScheme(.dark)
    }
}
