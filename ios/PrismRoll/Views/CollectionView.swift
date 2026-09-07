import SwiftUI

struct CollectionView: View {
    @EnvironmentObject private var store: GameStore
    @State private var skinToUnlock: BallSkin?

    var body: some View {
        List {
            Section {
                Picker("World", selection: $store.theme) {
                    ForEach(BoardTheme.allCases) { theme in
                        Label(theme.name, systemImage: "square.stack.3d.up")
                            .tag(theme)
                            .accessibilityIdentifier("theme_\(theme.id)")
                    }
                }
                .pickerStyle(.navigationLink)
                .accessibilityIdentifier("worldPicker")
                Text(store.theme.subtitle).font(.subheadline).foregroundStyle(.secondary)
            } header: {
                Text("Set the scene")
            }
            Section {
                ForEach(BallSkin.catalog) { skin in
                    SkinCard(skin: skin, owned: store.progress.ownedSkinIDs.contains(skin.id),
                             selected: store.progress.selectedSkinID == skin.id,
                             coinBalance: store.progress.points) {
                        if store.progress.ownedSkinIDs.contains(skin.id) {
                            store.selectSkin(skin)
                        } else if store.progress.points >= skin.price {
                            skinToUnlock = skin
                        }
                    }
                }
            } header: {
                Text("Balls · \(store.progress.ownedSkinIDs.count) of \(BallSkin.catalog.count) owned")
            } footer: {
                Text("Finish a new level to earn 50 coins. Unlocking a ball equips it immediately. You can switch between owned balls for free.")
            }
        }
        .listStyle(.insetGrouped)
        .alert("Unlock ball?", isPresented: Binding(
            get: { skinToUnlock != nil },
            set: { if !$0 { skinToUnlock = nil } }
        ), presenting: skinToUnlock) { skin in
            Button("Unlock \(skin.name) for \(skin.price.formatted()) coins") {
                store.selectSkin(skin)
            }
            .disabled(store.progress.points < skin.price)
            .accessibilityIdentifier("confirmSkinUnlock")
            Button("Cancel", role: .cancel) { }
                .accessibilityIdentifier("cancelSkinUnlock")
        } message: { skin in
            Text("Spend \(skin.price.formatted()) coins to unlock and equip \(skin.name).")
        }
    }
}
