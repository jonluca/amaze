import SwiftUI

/// A still backdrop keeps the open maze silhouette clear without adding a
/// second animation loop or competing with the ball's motion.
struct MazeBackdrop: View {
    let theme: BoardTheme

    var body: some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            context.fill(Path(bounds), with: .linearGradient(
                Gradient(stops: [
                    .init(color: colors.0, location: 0),
                    .init(color: colors.1, location: 0.48),
                    .init(color: colors.0, location: 1)
                ]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            if theme == .aurora {
                for (x, y, radius, opacity) in [(0.12, 0.36, 0.65, 0.28), (0.9, 0.6, 0.7, 0.22)] {
                    context.fill(Path(bounds), with: .radialGradient(
                        Gradient(colors: [Color(hex: "AEA6FF").opacity(opacity), .clear]),
                        center: CGPoint(x: size.width * x, y: size.height * y),
                        startRadius: 0, endRadius: size.width * radius))
                }
                for index in 0..<64 {
                    let x = CGFloat((index * 37 + 11) % 101) / 101 * size.width
                    let y = CGFloat((index * 61 + 17) % 103) / 103 * size.height
                    let radius: CGFloat = index.isMultiple(of: 9) ? 1.2 : 0.65
                    let dot = CGRect(x: x, y: y, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: dot), with: .color(.white.opacity(index.isMultiple(of: 3) ? 0.32 : 0.15)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var colors: (Color, Color) {
        switch theme {
        case .aurora: return (Color(hex: "211D42"), Color(hex: "766BDD"))
        case .timber: return (Color(hex: "211C24"), Color(hex: "5A4357"))
        case .porcelain: return (Color(hex: "182535"), Color(hex: "557889"))
        case .midnight: return (Color(hex: "101426"), Color(hex: "323660"))
        }
    }
}
