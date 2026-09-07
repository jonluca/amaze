import UIKit

/// Tiny cached sprites, rasterized only when a ball's trail is first prepared.
@MainActor
enum BallTrailTexture {
    private static var cache: [BallTrailStyle: [UIImage]] = [:]

    static func make(for style: BallTrailStyle) -> [UIImage] {
        if let images = cache[style] { return images }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 96, height: 96), format: format)
        let images = (0..<2).map { variant in
            renderer.image { context in
                draw(style, variant: variant, in: context.cgContext)
            }
        }
        cache[style] = images
        return images
    }

    private static func draw(_ style: BallTrailStyle, variant: Int, in context: CGContext) {
        let palette = colors(for: style)
        let color = palette[variant]
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setFillColor(color.cgColor)
        context.setStrokeColor(color.cgColor)
        switch style {
        case .coral:
            cloud(color: color, variant: variant, in: context)
        case .mint:
            wisp(color: color, variant: variant, in: context)
        case .sunset:
            petal(color: color, in: context)
        case .tidal:
            bubble(color: color, variant: variant, in: context)
        case .galaxy:
            star(points: 5, innerRadius: 14, outerRadius: 35, color: color, in: context)
        case .orbit:
            ring(color: color, variant: variant, in: context)
        case .ember:
            flame(color: color, in: context)
        case .frost:
            snowflake(color: color, in: context)
        case .jade:
            leaf(color: color, in: context)
        case .nova:
            star(points: 8, innerRadius: 12, outerRadius: 37, color: color, in: context)
        case .aurora:
            ribbon(color: color, variant: variant, in: context)
        case .midnight:
            crescent(color: color, in: context)
        }
    }

    private static func colors(for style: BallTrailStyle) -> [UIColor] {
        let values: [UInt32]
        switch style {
        case .coral: values = [0xFFC19A, 0xFFDFC0]
        case .mint: values = [0x69DCB4, 0xB0F5DF]
        case .sunset: values = [0xFFB154, 0xF46C9F]
        case .tidal: values = [0x66B8FF, 0xA5E1FF]
        case .galaxy: values = [0xAD83FA, 0xDEC0FF]
        case .orbit: values = [0xE5AD48, 0xFFE29A]
        case .ember: values = [0xFF7944, 0xFFC548]
        case .frost: values = [0x84CBE9, 0xD9F7FF]
        case .jade: values = [0x47BC83, 0xB0EA83]
        case .nova: values = [0xF779B8, 0xFFD05B]
        case .aurora: values = [0x50D9D2, 0xBD8CFF]
        case .midnight: values = [0xD6AD61, 0xFFE5A0]
        }
        return values.map { value in
            UIColor(red: CGFloat((value >> 16) & 255) / 255,
                    green: CGFloat((value >> 8) & 255) / 255,
                    blue: CGFloat(value & 255) / 255, alpha: 1)
        }
    }

    private static func cloud(color: UIColor, variant: Int, in context: CGContext) {
        let path = UIBezierPath()
        let circles: [CGRect] = variant == 0
            ? [CGRect(x: 14, y: 34, width: 40, height: 39), CGRect(x: 28, y: 19, width: 42, height: 49),
               CGRect(x: 45, y: 32, width: 37, height: 39)]
            : [CGRect(x: 12, y: 39, width: 38, height: 33), CGRect(x: 24, y: 23, width: 45, height: 48),
               CGRect(x: 47, y: 35, width: 36, height: 35)]
        for rect in circles { path.append(UIBezierPath(ovalIn: rect)) }
        context.setShadow(offset: .zero, blur: 8, color: color.withAlphaComponent(0.75).cgColor)
        path.fill()
        context.setShadow(offset: .zero, blur: 0, color: nil)
        context.setFillColor(UIColor.white.withAlphaComponent(0.22).cgColor)
        context.fillEllipse(in: CGRect(x: 34, y: 25, width: 26, height: 18))
    }

    private static func wisp(color: UIColor, variant: Int, in context: CGContext) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 15, y: 66))
        path.addCurve(to: CGPoint(x: 70, y: 23), controlPoint1: CGPoint(x: 86, y: 87),
                      controlPoint2: CGPoint(x: 26, y: 15))
        path.addCurve(to: CGPoint(x: 78, y: 47), controlPoint1: CGPoint(x: 88, y: 25),
                      controlPoint2: CGPoint(x: 84, y: 39))
        path.lineWidth = variant == 0 ? 12 : 9
        path.lineCapStyle = .round
        context.setShadow(offset: .zero, blur: 7, color: color.withAlphaComponent(0.55).cgColor)
        path.stroke()
        context.setShadow(offset: .zero, blur: 0, color: nil)
        context.setFillColor(color.withAlphaComponent(0.5).cgColor)
        context.fillEllipse(in: CGRect(x: 20, y: 42, width: 10, height: 10))
    }

    private static func petal(color: UIColor, in context: CGContext) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 24, y: 72))
        path.addCurve(to: CGPoint(x: 69, y: 19), controlPoint1: CGPoint(x: 8, y: 34),
                      controlPoint2: CGPoint(x: 41, y: 6))
        path.addCurve(to: CGPoint(x: 24, y: 72), controlPoint1: CGPoint(x: 95, y: 55),
                      controlPoint2: CGPoint(x: 56, y: 86))
        path.fill()
        stroke(from: CGPoint(x: 29, y: 66), to: CGPoint(x: 60, y: 31),
               color: UIColor.white.withAlphaComponent(0.34), width: 5, in: context)
    }

    private static func bubble(color: UIColor, variant: Int, in context: CGContext) {
        let bounds = variant == 0 ? CGRect(x: 18, y: 18, width: 60, height: 60)
            : CGRect(x: 21, y: 23, width: 56, height: 56)
        context.setFillColor(color.withAlphaComponent(0.16).cgColor)
        context.fillEllipse(in: bounds)
        context.setLineWidth(6)
        context.strokeEllipse(in: bounds)
        let highlight = UIBezierPath(arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
                                     radius: bounds.width / 2 - 9, startAngle: .pi * 1.08,
                                     endAngle: .pi * 1.48, clockwise: true)
        highlight.lineWidth = 6
        highlight.lineCapStyle = .round
        UIColor.white.withAlphaComponent(0.9).setStroke()
        highlight.stroke()
    }

    private static func star(points: Int, innerRadius: CGFloat, outerRadius: CGFloat,
                             color: UIColor, in context: CGContext) {
        let path = UIBezierPath()
        for point in 0..<(points * 2) {
            let angle = CGFloat(point) * .pi / CGFloat(points) - .pi / 2
            let radius = point.isMultiple(of: 2) ? outerRadius : innerRadius
            let position = CGPoint(x: 48 + cos(angle) * radius, y: 48 + sin(angle) * radius)
            if point == 0 { path.move(to: position) } else { path.addLine(to: position) }
        }
        path.close()
        context.setShadow(offset: .zero, blur: 6, color: color.withAlphaComponent(0.6).cgColor)
        path.fill()
        context.setShadow(offset: .zero, blur: 0, color: nil)
        context.setFillColor(UIColor.white.withAlphaComponent(0.5).cgColor)
        context.fillEllipse(in: CGRect(x: 43, y: 43, width: 10, height: 10))
    }

    private static func ring(color: UIColor, variant: Int, in context: CGContext) {
        context.setLineWidth(7)
        context.strokeEllipse(in: CGRect(x: 13, y: variant == 0 ? 28 : 22, width: 70,
                                         height: variant == 0 ? 40 : 52))
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: CGRect(x: 67, y: 24, width: 13, height: 13))
    }

    private static func flame(color: UIColor, in context: CGContext) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 50, y: 10))
        path.addCurve(to: CGPoint(x: 71, y: 62), controlPoint1: CGPoint(x: 48, y: 35),
                      controlPoint2: CGPoint(x: 80, y: 42))
        path.addCurve(to: CGPoint(x: 28, y: 61), controlPoint1: CGPoint(x: 63, y: 92),
                      controlPoint2: CGPoint(x: 24, y: 84))
        path.addCurve(to: CGPoint(x: 50, y: 10), controlPoint1: CGPoint(x: 24, y: 43),
                      controlPoint2: CGPoint(x: 43, y: 34))
        path.fill()
        context.setFillColor(UIColor(red: 1, green: 0.95, blue: 0.65, alpha: 0.9).cgColor)
        context.fillEllipse(in: CGRect(x: 39, y: 52, width: 19, height: 25))
    }

    private static func snowflake(color: UIColor, in context: CGContext) {
        context.translateBy(x: 48, y: 48)
        for _ in 0..<6 {
            stroke(from: .zero, to: CGPoint(x: 0, y: -34), color: color, width: 5, in: context)
            stroke(from: CGPoint(x: 0, y: -21), to: CGPoint(x: -9, y: -28),
                   color: color, width: 4, in: context)
            stroke(from: CGPoint(x: 0, y: -21), to: CGPoint(x: 9, y: -28),
                   color: color, width: 4, in: context)
            context.rotate(by: .pi / 3)
        }
    }

    private static func leaf(color: UIColor, in context: CGContext) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 19, y: 77))
        path.addCurve(to: CGPoint(x: 76, y: 18), controlPoint1: CGPoint(x: 7, y: 26),
                      controlPoint2: CGPoint(x: 49, y: 29))
        path.addCurve(to: CGPoint(x: 19, y: 77), controlPoint1: CGPoint(x: 83, y: 63),
                      controlPoint2: CGPoint(x: 45, y: 85))
        path.fill()
        let vein = UIColor(red: 0.08, green: 0.36, blue: 0.23, alpha: 0.55)
        stroke(from: CGPoint(x: 19, y: 78), to: CGPoint(x: 64, y: 32), color: vein, width: 4, in: context)
        stroke(from: CGPoint(x: 40, y: 57), to: CGPoint(x: 37, y: 41), color: vein, width: 3, in: context)
        stroke(from: CGPoint(x: 49, y: 48), to: CGPoint(x: 65, y: 49), color: vein, width: 3, in: context)
    }

    private static func ribbon(color: UIColor, variant: Int, in context: CGContext) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 14, y: 70))
        path.addCurve(to: CGPoint(x: 82, y: 26), controlPoint1: CGPoint(x: 79, y: 86),
                      controlPoint2: CGPoint(x: 12, y: 4))
        path.addCurve(to: CGPoint(x: 14, y: 70), controlPoint1: CGPoint(x: 39, y: 20),
                      controlPoint2: CGPoint(x: 97, y: 93))
        path.close()
        context.setShadow(offset: .zero, blur: 6, color: color.withAlphaComponent(0.4).cgColor)
        path.fill()
        context.setShadow(offset: .zero, blur: 0, color: nil)
        let accent = UIBezierPath()
        accent.move(to: CGPoint(x: 16, y: 57))
        accent.addCurve(to: CGPoint(x: 69, y: 20), controlPoint1: CGPoint(x: 64, y: 64),
                        controlPoint2: CGPoint(x: 22, y: 14))
        accent.lineWidth = variant == 0 ? 3 : 4
        color.withAlphaComponent(0.55).setStroke()
        accent.stroke()
    }

    private static func crescent(color: UIColor, in context: CGContext) {
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: CGRect(x: 18, y: 13, width: 62, height: 70))
        context.setBlendMode(.clear)
        context.fillEllipse(in: CGRect(x: 37, y: 6, width: 59, height: 62))
        context.setBlendMode(.normal)
    }

    private static func stroke(from start: CGPoint, to end: CGPoint, color: UIColor,
                               width: CGFloat, in context: CGContext) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        context.beginPath()
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
    }
}
