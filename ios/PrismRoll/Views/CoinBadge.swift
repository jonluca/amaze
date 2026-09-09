import SwiftUI

struct CoinBadge: View {
    let amount: Int
    var compactDisplay = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "circle.inset.filled").foregroundStyle(Palette.gold)
            Text(compactDisplay ? amount.formatted(.number.notation(.compactName)) : amount.formatted())
                .monospacedDigit()
        }
        .font(.subheadline.weight(.semibold))
        .fixedSize(horizontal: true, vertical: false)
    }
}
