import SwiftUI

struct SkinCard: View {
    let skin: BallSkin
    let owned: Bool
    let selected: Bool
    let coinBalance: Int
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            cardLayout {
                BallPreview(skin: skin)
                    .frame(width: dynamicTypeSize.isAccessibilitySize ? 52 : 76,
                           height: dynamicTypeSize.isAccessibilitySize ? 52 : 76)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(skin.name).font(.headline).foregroundStyle(Color.primary)
                    Label(skin.rarity.name, systemImage: skin.rarity.symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(hex: skin.rarity.hex))
                    Text(selected ? "Equipped" : owned ? "Tap to equip" : "Unlock · \(skin.price.formatted()) coins")
                        .font(.subheadline).foregroundStyle(Color.secondary)
                    if !owned, coinsNeeded > 0 {
                        Text("\(coinsNeeded.formatted()) more coins needed")
                            .font(.caption).foregroundStyle(Color.secondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: 8)
                    Image(systemName: selected ? "checkmark.circle.fill" : owned ? "circle" : "lock.fill")
                        .foregroundStyle(selected ? Palette.violet : owned ? Palette.secondary : Palette.gold)
                }
            }
        }
        .disabled(!owned && coinsNeeded > 0)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(selected ? "This ball is equipped" : owned ? "Equip this ball for free" : coinsNeeded == 0 ? "Shows confirmation before spending coins" : "Earn coins by finishing levels or claiming challenges")
        .accessibilityIdentifier("skin_\(skin.id)")
    }

    private var coinsNeeded: Int { max(0, skin.price - max(0, coinBalance)) }

    private var cardLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 16))
    }

    private var accessibilityLabel: String {
        let name = "\(skin.name), \(skin.rarity.name)"
        if selected { return "\(name), equipped" }
        if owned { return "\(name), owned, tap to equip" }
        let offer = "\(name), unlock for \(skin.price.formatted()) coins"
        return coinsNeeded == 0 ? offer : "\(offer), \(coinsNeeded.formatted()) more coins needed"
    }
}
