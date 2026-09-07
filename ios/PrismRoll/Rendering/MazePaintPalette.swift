import UIKit

/// Keeps the selected ball recognizable while giving each level its own paint.
@MainActor
enum MazePaintPalette {
    private static let colors = ["39B8AF", "7691E5", "AF77D2", "D96797", "E8AF5B", "9BBB52"]

    static func hex(for skin: BallSkin, levelNumber: Int) -> String {
        let primaryHue = hue(skin.hex)
        let contrasting = colors.filter { distance(hue($0), primaryHue) >= 0.15 }
        let accentHue = hue(skin.accentHex)
        let patterned = contrasting.filter { distance(hue($0), accentHue) >= 0.15 }
        // Pattern accents also inform the pairing, but never reduce variation to
        // one color. The ball's primary color always remains distinct.
        let palette = skin.pattern != "plain" && patterned.count >= 2 ? patterned : contrasting
        return palette[(max(1, levelNumber) - 1) % palette.count]
    }

    private static func hue(_ hex: String) -> CGFloat {
        var value: CGFloat = 0
        BallMaterialFactory.color(hex: hex).getHue(&value, saturation: nil, brightness: nil, alpha: nil)
        return value
    }

    private static func distance(_ first: CGFloat, _ second: CGFloat) -> CGFloat {
        let difference = abs(first - second)
        return min(difference, 1 - difference)
    }
}
