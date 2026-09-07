import SwiftUI

struct PerfectSolveAward: View {
    let moves: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    private let highlight = Color(hex: "FFF0BA")
    private let bronze = Color(hex: "B86B21")

    var body: some View {
        VStack(spacing: 18) {
            medal
                .scaleEffect(revealed || reduceMotion ? 1 : 0.72)
                .rotationEffect(.degrees(revealed || reduceMotion ? 0 : -12))
            VStack(spacing: 8) {
                Text("PERFECT SOLVE")
                    .font(.caption.weight(.heavy))
                    .tracking(3)
                    .foregroundStyle(Palette.gold)
                Text("Every move mattered.")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(moves == 1 ? "1 move · Best possible" : "\(moves) moves · Best possible")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(highlight.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: 340)
        .background {
            RoundedRectangle(cornerRadius: 30)
                .fill(Palette.background.opacity(0.96))
                .overlay {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(LinearGradient(colors: [Palette.gold.opacity(0.12), .clear],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 30)
                        .strokeBorder(LinearGradient(colors: [highlight.opacity(0.65), Palette.gold.opacity(0.12)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.3), radius: 24, y: 12)
        }
        .opacity(revealed || reduceMotion ? 1 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Perfect solve. \(moves == 1 ? "1 move" : "\(moves) moves"). Best possible.")
        .accessibilityIdentifier("perfectSolveAward")
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.8)) {
                revealed = true
            }
        }
    }

    private var medal: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Palette.gold.opacity(0.22), .clear],
                                     center: .center, startRadius: 30, endRadius: 100))
                .frame(width: 200, height: 200)
            HStack(spacing: 70) {
                Image(systemName: "laurel.leading")
                Image(systemName: "laurel.trailing")
            }
            .font(.system(size: 66, weight: .light))
            .foregroundStyle(LinearGradient(colors: [highlight, bronze], startPoint: .top, endPoint: .bottom))
            ForEach([-1.0, 1.0], id: \.self) { side in
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 30, y: 0))
                    path.addLine(to: CGPoint(x: 30, y: 66))
                    path.addLine(to: CGPoint(x: 15, y: 55))
                    path.addLine(to: CGPoint(x: 0, y: 66))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [Palette.violet, Color(hex: "6551BF")], startPoint: .top, endPoint: .bottom))
                .frame(width: 30, height: 66)
                .rotationEffect(.degrees(side * -16))
                .offset(x: side * 18, y: 45)
            }
            Circle()
                .fill(LinearGradient(colors: [highlight, Palette.gold, bronze], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 102, height: 102)
                .overlay {
                    Circle().strokeBorder(highlight.opacity(0.9), lineWidth: 2).padding(4)
                }
                .overlay {
                    Circle().strokeBorder(bronze.opacity(0.6), lineWidth: 1).padding(10)
                }
                .overlay {
                    Image(systemName: "star.fill")
                        .font(.system(size: 41, weight: .semibold))
                        .foregroundStyle(LinearGradient(colors: [Color(hex: "9C581C"), Color(hex: "D79132")],
                                                        startPoint: .top, endPoint: .bottom))
                        .shadow(color: highlight, radius: 0, y: 1)
                }
                .shadow(color: bronze.opacity(0.28), radius: 10, y: 6)
            Image(systemName: "sparkle")
                .font(.system(size: 23, weight: .light))
                .foregroundStyle(highlight)
                .offset(x: 61, y: -43)
            Image(systemName: "sparkle")
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(Palette.gold)
                .offset(x: -70, y: 33)
        }
        .frame(height: 155)
        .accessibilityHidden(true)
    }
}
