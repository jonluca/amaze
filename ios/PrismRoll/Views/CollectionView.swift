import SwiftUI

struct CollectionView: View {
    var onGetCoins: () -> Void = {}
    @EnvironmentObject private var store: GameStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var skinToUnlock: BallSkin?
    @State private var selectedRarity: BallRarity?

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
                Button(action: onGetCoins) {
                    Label("Get coins", systemImage: "plus.circle.fill")
                        .frame(minHeight: 32)
                }
                .accessibilityIdentifier("collectionGetCoins")
                Picker("Rarity", selection: $selectedRarity) {
                    Text("All rarities").tag(nil as BallRarity?)
                    ForEach(BallRarity.allCases) { rarity in
                        Label(rarity.name, systemImage: rarity.symbol).tag(Optional(rarity))
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("rarityPicker")
            } header: {
                Text("Balls · \(ownedCount) of \(BallSkin.catalog.count) owned")
            } footer: {
                Text("Earn 50 coins for each new level.")
            }
            ForEach(visibleRarities) { rarity in
                Section {
                    ForEach(BallSkin.catalog.filter { $0.rarity == rarity }) { skin in
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
                    rarityHeaderLayout {
                        Label(rarity.name, systemImage: rarity.symbol)
                            .foregroundStyle(Color(hex: rarity.hex))
                        if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                        Text("\(ownedCount(in: rarity)) / \(BallSkin.catalog.filter { $0.rarity == rarity }.count) owned")
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("rarity_\(rarity.id)")
                } footer: {
                    if rarity == visibleRarities.last {
                        Text("Unlocking a ball equips it immediately. Switch between owned balls for free.")
                    }
                }
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
            Text("Spend \(skin.price.formatted()) coins to unlock and equip \(skin.name), a \(skin.rarity.name.lowercased()) ball.")
        }
    }

    private var visibleRarities: [BallRarity] {
        selectedRarity.map { [$0] } ?? BallRarity.allCases
    }

    private var rarityHeaderLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout())
    }

    private var ownedCount: Int {
        BallSkin.catalog.filter { store.progress.ownedSkinIDs.contains($0.id) }.count
    }

    private func ownedCount(in rarity: BallRarity) -> Int {
        BallSkin.catalog.filter { $0.rarity == rarity && store.progress.ownedSkinIDs.contains($0.id) }.count
    }
}
