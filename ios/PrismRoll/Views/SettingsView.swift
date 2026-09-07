import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var ads: AdService
    @EnvironmentObject private var purchases: PurchaseService
    @EnvironmentObject private var duel: DuelService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Feel every move") {
                    Toggle("Haptics", isOn: Binding(get: { store.progress.hapticsEnabled }, set: store.setHaptics))
                        .accessibilityIdentifier("hapticsToggle")
                    Toggle("Move sounds", isOn: Binding(get: { store.progress.soundEnabled }, set: store.setSound))
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
                    Label("Swipe in any direction. The ball rolls until a wall stops it.", systemImage: "hand.draw")
                    Label("Cover every open tile in color to complete the maze.", systemImage: "drop")
                    Label("Classic has no clock or move limit. Play at your own pace.", systemImage: "infinity")
                    Label("Time Rush: paint every maze in a round before one shared countdown ends. Your first valid swipe starts the clock. Each completed maze leads straight to the next.", systemImage: "timer")
                    Label("Limited Moves gives you a swipe budget. Blocked swipes never count.", systemImage: "scope")
                    Label("Earn coins from new levels, bonus boards, and challenges. Unlock balls in Collection.", systemImage: "circle.fill")
                    Label("Claim your daily reward and return tomorrow to grow your streak.", systemImage: "flame")
                }.font(.subheadline)
                Section("No Ads") {
                    if purchases.removesAds {
                        Label("No Ads is active", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Palette.cyan)
                    } else if let product = purchases.product {
                        Button {
                            Task { await purchases.purchase() }
                        } label: {
                            HStack {
                                Label("Remove between-level ads", systemImage: "sparkles")
                                Spacer(minLength: 8)
                                Text(product.displayPrice).fontWeight(.bold)
                            }
                        }
                        .disabled(purchases.isBusy)
                        .accessibilityIdentifier("purchaseNoAds")
                        Text("One-time purchase. Optional videos for hints, extra time, extra moves, and bonuses remain available.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text(purchases.status).font(.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("purchaseStatus")
                    HStack {
                        Button("Restore purchases") { Task { await purchases.restore() } }
                            .disabled(purchases.isBusy)
                            .accessibilityIdentifier("restorePurchases")
                        Spacer()
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
                Section("Game Center") {
                    Label(duel.authenticated ? "Connected to Game Center" : "Race a friend in Duel",
                          systemImage: duel.authenticated ? "person.crop.circle.badge.checkmark" : "person.2.fill")
                    Text(duel.status).font(.caption).foregroundStyle(.secondary)
                    if !duel.authenticated {
                        Button("Sign in to Game Center", action: duel.authenticate)
                            .accessibilityIdentifier("signInGameCenter")
                    }
                    Text("Open Challenges to find a match. Both players paint the same maze; the first to finish wins.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Privacy & ads") {
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
                    Text("Solo progress stays on this device. Duel uses Game Center to connect players. Ads may appear between levels; reward videos are always optional.")
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
}
