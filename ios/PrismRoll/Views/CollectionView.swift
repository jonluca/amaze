import SwiftUI

struct CollectionView: View {
    @EnvironmentObject private var store: GameStore

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
                             affordable: store.progress.points >= skin.price) {
                        store.selectSkin(skin)
                    }
                }
            } header: {
                Text("Balls · \(store.progress.ownedSkinIDs.count) of \(BallSkin.catalog.count) owned")
            } footer: {
                Text("Finish a new level to earn 50 coins. Unlock a ball with coins, then select it to equip it.")
            }
        }
        .listStyle(.insetGrouped)
    }
}
