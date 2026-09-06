import SwiftUI

struct CoinBadge: View {
    let amount: Int
    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle().fill(LinearGradient(colors: [Color(hex: "FFE9A0"), Palette.gold, Color(hex: "D78D31")], startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle().stroke(Color(hex: "8E581C").opacity(0.5), lineWidth: 1.3).padding(3)
                Text("P").font(.system(size: 10, weight: .black, design: .rounded)).foregroundStyle(Color(hex: "A16825"))
            }.frame(width: 22, height: 22)
            Text(amount.formatted()).font(.system(size: 15, weight: .bold, design: .rounded)).monospacedDigit()
        }.padding(.horizontal, 11).padding(.vertical, 9).background(Palette.paper, in: Capsule())
    }
}
