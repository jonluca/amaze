import SwiftUI
import StoreKit

struct SettingsView: View {
    @ObservedObject private var analytics = AnalyticsService.shared
    @ObservedObject private var attribution = AppsFlyerAttributionService.shared
    @ObservedObject private var diagnostics = DiagnosticsService.shared
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var ads: AdService
    @EnvironmentObject private var purchases: PurchaseService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var onShowGameCenter: () -> Void = {}

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Sound", isOn: Binding(get: { store.progress.soundEnabled }, set: store.setSound))
                        .accessibilityIdentifier("soundToggle")
                    Toggle("Haptics", isOn: Binding(get: { store.progress.hapticsEnabled }, set: store.setHaptics))
                        .accessibilityIdentifier("hapticsToggle")
                } header: {
                    Text("Sound & haptics")
                } footer: {
                    Text("Turn both off to play without game sounds or vibrations.")
                }
                Section("Controls") {
                    Toggle("Direction buttons", isOn: Binding(
                        get: { store.progress.directionButtonsEnabled },
                        set: store.setDirectionButtons
                    ))
                    .accessibilityIdentifier("directionButtonsToggle")
                    Text("Tap a direction instead of swiping. Each tap rolls to a wall. Named buttons support Voice Control and Switch Control; arrow keys work while the controls are shown during play.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section("How to play") {
                    Label("Swipe to roll to a wall. Keep your finger down and drag to change direction.", systemImage: "hand.draw")
                    Label("Cover every open tile in color to complete the maze.", systemImage: "drop")
                    Label("Classic has no clock or move limit. Play at your own pace.", systemImage: "infinity")
                    Label("Time Rush: paint every maze in a round before one shared countdown ends. Your first valid swipe starts the clock. Each completed maze leads straight to the next.", systemImage: "timer")
                    Label("Limited Moves gives you a swipe budget. Blocked swipes never count.", systemImage: "scope")
                    Label("Earn coins from new levels, bonus boards, and challenges. Unlock balls in Collection.", systemImage: "circle.fill")
                    Label("Claim your daily reward and return tomorrow to grow your streak.", systemImage: "flame")
                }.font(.subheadline)
                Section("Game Center") {
                    Button(action: onShowGameCenter) {
                        Label("Achievements & leaderboards", systemImage: "trophy")
                    }
                    .accessibilityIdentifier("openGameCenter")
                    Text("Earn achievements, compare completed mazes with friends, and keep your best scores on Game Center.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("No Ads") {
                    if purchases.removesAds {
                        Label("No Ads is active", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Palette.cyan)
                    } else if let product = purchases.product {
                        Button {
                            Task { await purchases.purchase() }
                        } label: {
                            purchaseLayout {
                                Label("Remove between-level ads", systemImage: "sparkles")
                                    .fixedSize(horizontal: false, vertical: true)
                                if dynamicTypeSize < .xxLarge { Spacer(minLength: 8) }
                                Text(product.displayPrice).fontWeight(.bold)
                                    .fixedSize()
                            }
                        }
                        .disabled(purchases.isBusy)
                        .accessibilityIdentifier("purchaseNoAds")
                        Text("One-time purchase. Optional videos for hints, extra time, extra moves, and bonuses remain available.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text(purchases.status).font(.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("purchaseStatus")
                    purchaseLayout {
                        Button("Restore purchases") { Task { await purchases.restore() } }
                            .disabled(purchases.isBusy)
                            .accessibilityIdentifier("restorePurchases")
                        if dynamicTypeSize < .xxLarge { Spacer() }
                        if purchases.isBusy { ProgressView().tint(Palette.violet) }
                        else if purchases.product == nil && !purchases.removesAds {
                            Button("Retry") { Task { await purchases.load() } }
                        }
                    }
                    if purchases.removesAds {
                        Text("Optional reward videos remain available when you choose to watch one.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("Privacy & ads") {
                    Toggle("Share saved and future crash reports", isOn: Binding(
                        get: { diagnostics.isEnabled }, set: diagnostics.setEnabled
                    ))
                    .disabled(!diagnostics.isAvailable)
                    .accessibilityIdentifier("diagnosticsToggle")
                    Text("Send saved and future crash reports, selected save or purchase errors, app and device information, and an installation identifier to Firebase Crashlytics. Saved reports may include crashes from before you enabled this setting. Sharing is optional and separate from usage analytics. Turning it off stops new error recording and future upload requests; reports already authorized may still be sent.")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("Share usage analytics", isOn: Binding(
                        get: { analytics.isEnabled }, set: analytics.setEnabled
                    ))
                    .disabled(!analytics.isAvailable)
                    .accessibilityIdentifier("analyticsToggle")
                    Text("Help improve Prism Roll by sharing gameplay, feature use, and purchase activity with Google Analytics. No name, email, Game Center identity, or advertising identifier is sent by analytics. You can turn this off at any time.")
                        .font(.caption).foregroundStyle(.secondary)
                    if attribution.isAvailable {
                        Toggle("Share install attribution", isOn: Binding(
                            get: { attribution.isEnabled }, set: attribution.setEnabled
                        ))
                        .disabled(!analytics.isEnabled && !attribution.isEnabled)
                        .accessibilityIdentifier("attributionToggle")
                        Text("Share install and app-session information, campaign attribution, app and device information, IP address, and an installation identifier with AppsFlyer to understand how people find Prism Roll. AppsFlyer advertising and vendor identifiers, personalized advertising, and sharing with advertising partners are disabled. This also requires Share usage analytics; turning either choice off stops new AppsFlyer measurement.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("Privacy policy", systemImage: "hand.raised")
                    }
                    .accessibilityIdentifier("privacyPolicy")
                    if let supportURL = URL(string: "https://thoughtahead.com/prism-roll/support.html") {
                        Link(destination: supportURL) {
                            Label("Contact support", systemImage: "questionmark.circle")
                        }
                        .accessibilityIdentifier("supportWebsite")
                    }
                    Text("Maze saves, coins, and collection stay on this device. Game Center syncs achievements and scores when signed in. Ads may appear between levels; reward videos are always optional.")
                        .font(.subheadline)
                    if ads.privacyOptionsRequired {
                        Button("Manage ad privacy", action: ads.presentPrivacyOptions)
                            .disabled(ads.isPresenting || ads.isPrivacyFormPresenting)
                    }
                    Text(ads.statusMessage).font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Text("Prism Roll · 1.0\nFind your flow. Paint your path.")
                        .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .tint(Palette.violet)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
        .task { await purchases.load() }
    }

    private var purchaseLayout: AnyLayout {
        dynamicTypeSize >= .xxLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
    }
}
