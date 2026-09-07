import SwiftUI

struct CoinBadge: View {
    let amount: Int

    var body: some View {
        Label {
            Text(amount.formatted()).monospacedDigit()
        } icon: {
            Image(systemName: "circle.inset.filled").foregroundStyle(Palette.gold)
        }
        .labelStyle(.titleAndIcon)
        .font(.subheadline.weight(.semibold))
        .fixedSize()
    }
}
