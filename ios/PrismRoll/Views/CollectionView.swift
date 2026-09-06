import SwiftUI

struct CollectionView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("A LITTLE PERSONALITY").font(.system(size: 9, weight: .heavy, design: .rounded))
                        .tracking(3).foregroundStyle(Palette.secondary)
                    Text("Find your color.").font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("Turn a few good moves into something you love.")
                        .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("SET THE SCENE").font(.system(size: 10, weight: .heavy)).tracking(1.5)
                    HStack(spacing: 9) {
                        ForEach(BoardTheme.allCases) { theme in
                            Button { store.theme = theme } label: {
                                VStack(spacing: 8) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 13).fill(Color(hex: theme.previewHex).gradient).frame(height: 49)
                                        Image(systemName: store.theme == theme ? "checkmark.circle.fill" : "square.stack.3d.up.fill")
                                            .foregroundStyle(Color(hex: "17223A")).font(.system(size: 20))
                                    }
                                    Text(theme.name).font(.system(size: 10, weight: .semibold))
                                }.frame(maxWidth: .infinity)
                            }.accessibilityIdentifier("theme_\(theme.id)").accessibilityLabel("\(theme.name) theme")
                        }
                    }
                    Text(store.theme.subtitle).font(.system(size: 11)).foregroundStyle(Palette.secondary)
                }
                HStack {
                    Text("THE BALL COLLECTION").font(.system(size: 10, weight: .heavy, design: .rounded)).tracking(1.5)
                    Spacer()
                    Text("\(store.progress.ownedSkinIDs.count) / \(BallSkin.catalog.count) owned")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.secondary)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    ForEach(BallSkin.catalog) { skin in
                        SkinCard(skin: skin, owned: store.progress.ownedSkinIDs.contains(skin.id),
                                 selected: store.progress.selectedSkinID == skin.id,
                                 affordable: store.progress.points >= skin.price) {
                            store.selectSkin(skin)
                        }
                    }
                }
                HStack(spacing: 10) {
                    Image(systemName: "sparkles").foregroundStyle(Palette.accent)
                    Text("Finish a new level to earn 50 coins.\nYour next favorite is a few swipes away.")
                        .font(.system(size: 11)).foregroundStyle(Palette.secondary).lineSpacing(3)
                }.padding(.vertical, 8)
            }.padding(.horizontal, 26).padding(.top, 10).padding(.bottom, 15)
        }.scrollIndicators(.hidden)
    }
}
