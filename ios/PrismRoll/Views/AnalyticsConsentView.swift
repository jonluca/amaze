import SwiftUI

struct AnalyticsConsentView: View {
    @ObservedObject private var analytics = AnalyticsService.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Help us understand which modes you enjoy and where puzzles get difficult.")
                    Text("If you agree, Google Analytics receives gameplay, feature use, purchase activity, app and device information, and a random app-instance identifier. Analytics does not receive your name, email, Game Center identity, or advertising identifier.")
                    Text("Sharing is optional. You can change your choice in Settings at any time.")
                    NavigationLink("Privacy policy") { PrivacyPolicyView() }
                }
                Section {
                    Button("Share usage data") {
                        analytics.setEnabled(true)
                        analytics.screen("play")
                    }
                    .accessibilityIdentifier("analyticsAllow")
                    Button("Not now") { analytics.setEnabled(false) }
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
