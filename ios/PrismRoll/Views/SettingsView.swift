import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var ads: AdService
    @EnvironmentObject private var purchases: PurchaseService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                    Text("Progress stays on this device. Ads may appear between levels; reward videos are always optional.")
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
