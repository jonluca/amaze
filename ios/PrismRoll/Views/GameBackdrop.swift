import SwiftUI

struct GameBackdrop: View {
    var body: some View {
        ZStack {
            Palette.background
            RadialGradient(colors: [Palette.violet.opacity(0.10), .clear], center: .init(x: 0.75, y: 0.35), startRadius: 0, endRadius: 420)
            RadialGradient(colors: [Palette.cyan.opacity(0.035), .clear], center: .init(x: 0.1, y: 0.8), startRadius: 0, endRadius: 240)
        }.ignoresSafeArea()
    }
}
