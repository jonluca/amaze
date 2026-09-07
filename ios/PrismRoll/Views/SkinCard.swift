import SwiftUI

struct SkinCard: View {
    let skin: BallSkin
    let owned: Bool
    let selected: Bool
    let coinBalance: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                BallPreview(skin: skin)
                    .frame(width: 76, height: 76)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(skin.name).font(.headline).foregroundStyle(Color.primary)
                    Text(selected ? "Equipped" : owned ? "Tap to equip" : "Unlock · \(skin.price.formatted()) coins")
                        .font(.subheadline).foregroundStyle(Color.secondary)
                    if !owned, coinsNeeded > 0 {
                        Text("\(coinsNeeded.formatted()) more coins needed")
                            .font(.caption).foregroundStyle(Color.secondary)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : owned ? "circle" : "circle.inset.filled")
                    .foregroundStyle(selected ? Palette.violet : owned ? Palette.secondary : Palette.gold)
            }
        }
        .disabled(!owned && coinsNeeded > 0)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(selected ? "This ball is equipped" : owned ? "Equip this ball for free" : coinsNeeded == 0 ? "Shows confirmation before spending coins" : "Earn coins by finishing levels or claiming challenges")
        .accessibilityIdentifier("skin_\(skin.id)")
    }

    private var coinsNeeded: Int { max(0, skin.price - max(0, coinBalance)) }

    private var accessibilityLabel: String {
        if selected { return "\(skin.name), equipped" }
        if owned { return "\(skin.name), owned, tap to equip" }
        let offer = "\(skin.name), unlock for \(skin.price.formatted()) coins"
        return coinsNeeded == 0 ? offer : "\(offer), \(coinsNeeded.formatted()) more coins needed"
    }
}
