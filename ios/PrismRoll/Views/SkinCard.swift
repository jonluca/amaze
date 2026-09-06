import SwiftUI

struct SkinCard: View {
    let skin: BallSkin
    let owned: Bool
    let selected: Bool
    let affordable: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    BallPreview(skin: skin).frame(height: 96).frame(maxWidth: .infinity)
                    if selected {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.ink)
                            .font(.system(size: 18))
                    }
                }
                Text(skin.name).font(.system(size: 16, weight: .bold, design: .rounded))
                HStack(spacing: 5) {
                    if !owned { Image(systemName: "sparkle").foregroundStyle(Palette.accent) }
                    Text(selected ? "Equipped" : owned ? "Tap to equip" : "\(skin.price) coins")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(selected ? Palette.ink : Palette.secondary)
                .padding(.vertical, 8).frame(maxWidth: .infinity)
                .background(selected ? Palette.violet.opacity(0.2) : Palette.background, in: Capsule())
            }
            .padding(15).background(Palette.paper, in: RoundedRectangle(cornerRadius: 25))
            .overlay(RoundedRectangle(cornerRadius: 25).stroke(selected ? Palette.violet.opacity(0.7) : Palette.line,
                                                               lineWidth: selected ? 1.5 : 1))
        }
        .accessibilityLabel("\(skin.name), \(selected ? "equipped" : owned ? "owned" : "\(skin.price) coins")")
        .accessibilityHint(owned ? "Equip this ball" : affordable ? "Unlock and equip this ball" : "Earn more coins by finishing levels")
        .accessibilityIdentifier("skin_\(skin.id)")
    }
}
