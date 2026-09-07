import SwiftUI

struct SkinCard: View {
    let skin: BallSkin
    let owned: Bool
    let selected: Bool
    let affordable: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                BallPreview(skin: skin)
                    .frame(width: 76, height: 76)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(skin.name).font(.headline).foregroundStyle(.primary)
                    Text(selected ? "Equipped" : owned ? "Tap to equip" : "\(skin.price) coins")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : owned ? "circle" : "circle.inset.filled")
                    .foregroundStyle(selected ? Palette.violet : owned ? Palette.secondary : Palette.gold)
            }
        }
        .accessibilityLabel("\(skin.name), \(selected ? "equipped" : owned ? "owned" : "\(skin.price) coins")")
        .accessibilityHint(owned ? "Equip this ball" : affordable ? "Unlock and equip this ball" : "Earn more coins by finishing levels")
        .accessibilityIdentifier("skin_\(skin.id)")
    }
}
