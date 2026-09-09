import UIKit

/// More intricate signatures still fit inside the same cached 96-point sprites.
extension BallTrailTexture {
    static func solarCorona(color: UIColor, variant: Int, in context: CGContext) {
        context.setLineWidth(5)
        context.setShadow(offset: .zero, blur: 5, color: color.withAlphaComponent(0.55).cgColor)
        context.strokeEllipse(in: CGRect(x: 29, y: 29, width: 38, height: 38))
        for ray in 0..<8 {
            let angle = CGFloat(ray) * .pi / 4 + CGFloat(variant) * .pi / 8
            let radius: CGFloat = ray.isMultiple(of: 2) ? 39 : 33
            let path = UIBezierPath()
            path.move(to: polar(angle: angle - 0.13, radius: 25))
            path.addQuadCurve(to: polar(angle: angle + 0.13, radius: 25),
                              controlPoint: polar(angle: angle + 0.15, radius: radius))
            path.lineWidth = 5
            path.lineCapStyle = .round
            path.stroke()
        }
        context.setShadow(offset: .zero, blur: 0, color: nil)
        context.setFillColor(UIColor(red: 1, green: 0.94, blue: 0.66, alpha: 1).cgColor)
        context.fillEllipse(in: CGRect(x: 39, y: 39, width: 18, height: 18))
    }

    static func plasmaArc(color: UIColor, variant: Int, in context: CGContext) {
        let arc = UIBezierPath()
        let points = variant == 0
            ? [CGPoint(x: 60, y: 12), CGPoint(x: 28, y: 46), CGPoint(x: 51, y: 42),
               CGPoint(x: 35, y: 84), CGPoint(x: 70, y: 44), CGPoint(x: 50, y: 48)]
            : [CGPoint(x: 41, y: 12), CGPoint(x: 70, y: 42), CGPoint(x: 47, y: 40),
               CGPoint(x: 61, y: 84), CGPoint(x: 25, y: 46), CGPoint(x: 45, y: 48)]
        arc.move(to: points[0])
        for point in points.dropFirst() { arc.addLine(to: point) }
        arc.close()
        context.setShadow(offset: .zero, blur: 7, color: color.withAlphaComponent(0.8).cgColor)
        arc.fill()
        context.setShadow(offset: .zero, blur: 0, color: nil)
        let discharge = UIBezierPath()
        discharge.move(to: CGPoint(x: 14, y: 34))
        discharge.addLine(to: CGPoint(x: 23, y: 24))
        discharge.addLine(to: CGPoint(x: 21, y: 40))
        discharge.move(to: CGPoint(x: 78, y: 59))
        discharge.addLine(to: CGPoint(x: 84, y: 48))
        discharge.lineWidth = 4
        color.withAlphaComponent(0.7).setStroke()
        discharge.stroke()
        context.setFillColor(UIColor.white.withAlphaComponent(0.8).cgColor)
        context.fillEllipse(in: CGRect(x: 44, y: 43, width: 8, height: 8))
    }

    static func stellarShockwave(color: UIColor, variant: Int, in context: CGContext) {
        context.setLineWidth(4)
        context.setStrokeColor(color.withAlphaComponent(0.55).cgColor)
        context.strokeEllipse(in: CGRect(x: 12, y: 12, width: 72, height: 72))
        let burst = UIBezierPath()
        for point in 0..<24 {
            let angle = CGFloat(point) * .pi / 12 + CGFloat(variant) * .pi / 12
            let radius: CGFloat = point.isMultiple(of: 2) ? (point.isMultiple(of: 6) ? 40 : 29) : 9
            let position = polar(angle: angle, radius: radius)
            if point == 0 { burst.move(to: position) } else { burst.addLine(to: position) }
        }
        burst.close()
        context.setShadow(offset: .zero, blur: 4, color: color.withAlphaComponent(0.7).cgColor)
        burst.fill()
        context.setShadow(offset: .zero, blur: 0, color: nil)
        context.setFillColor(UIColor.white.withAlphaComponent(0.9).cgColor)
        context.fillEllipse(in: CGRect(x: 41, y: 41, width: 14, height: 14))
    }

    static func accretionDisk(color: UIColor, variant: Int, in context: CGContext) {
        context.translateBy(x: 48, y: 48)
        context.rotate(by: variant == 0 ? -.pi / 6 : .pi / 6)
        context.setLineWidth(5)
        context.setShadow(offset: .zero, blur: 5, color: color.withAlphaComponent(0.6).cgColor)
        context.strokeEllipse(in: CGRect(x: -37, y: -18, width: 74, height: 36))
        context.setLineWidth(3)
        context.setStrokeColor(color.withAlphaComponent(0.55).cgColor)
        context.strokeEllipse(in: CGRect(x: -31, y: -30, width: 62, height: 60))
        context.setShadow(offset: .zero, blur: 0, color: nil)
        context.setFillColor(UIColor(red: 0.09, green: 0.06, blue: 0.21, alpha: 1).cgColor)
        context.fillEllipse(in: CGRect(x: -18, y: -18, width: 36, height: 36))
        let rim = UIBezierPath(arcCenter: .zero, radius: 19, startAngle: .pi * 1.05,
                               endAngle: .pi * 1.90, clockwise: true)
        rim.lineWidth = 4
        rim.lineCapStyle = .round
        UIColor.white.withAlphaComponent(0.9).setStroke()
        rim.stroke()
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: CGRect(x: 28, y: 6, width: 9, height: 9))
    }

    static func hypercube(color: UIColor, variant: Int, in context: CGContext) {
        let outer = [CGPoint(x: 48, y: 11), CGPoint(x: 80, y: 29), CGPoint(x: 80, y: 66),
                     CGPoint(x: 48, y: 85), CGPoint(x: 16, y: 66), CGPoint(x: 16, y: 29)]
        let inner = outer.map { point in
            CGPoint(x: 48 + (point.x - 48) * 0.48, y: 48 + (point.y - 48) * 0.48)
        }
        let edges = UIBezierPath()
        for vertices in [outer, inner] {
            edges.move(to: vertices[0])
            for vertex in vertices.dropFirst() { edges.addLine(to: vertex) }
            edges.close()
        }
        for index in outer.indices {
            edges.move(to: outer[index])
            edges.addLine(to: inner[index])
        }
        for index in stride(from: variant, to: 6, by: 2) {
            edges.move(to: inner[index])
            edges.addLine(to: CGPoint(x: 48, y: 48))
        }
        edges.lineWidth = 4
        edges.lineJoinStyle = .round
        context.setShadow(offset: .zero, blur: 4, color: color.withAlphaComponent(0.5).cgColor)
        edges.stroke()
        context.setShadow(offset: .zero, blur: 0, color: nil)
        context.setFillColor(UIColor.white.withAlphaComponent(0.9).cgColor)
        for index in stride(from: variant, to: 6, by: 2) {
            let vertex = outer[index]
            context.fillEllipse(in: CGRect(x: vertex.x - 3, y: vertex.y - 3, width: 6, height: 6))
        }
    }

    static func creationSigil(color: UIColor, variant: Int, in context: CGContext) {
        let spectrum: [UIColor] = [color,
                                  UIColor(red: 0.31, green: 0.85, blue: 0.87, alpha: 0.95),
                                  UIColor(red: 0.73, green: 0.52, blue: 0.98, alpha: 0.95)]
        context.saveGState()
        context.translateBy(x: 48, y: 48)
        context.rotate(by: CGFloat(variant) * .pi / 6)
        context.setLineWidth(4)
        for tone in spectrum {
            context.setStrokeColor(tone.cgColor)
            context.setShadow(offset: .zero, blur: 3, color: tone.withAlphaComponent(0.4).cgColor)
            context.strokeEllipse(in: CGRect(x: -37, y: -17, width: 74, height: 34))
            context.rotate(by: .pi / 3)
        }
        context.restoreGState()
        let core = UIBezierPath()
        for point in 0..<12 {
            let position = polar(angle: CGFloat(point) * .pi / 6,
                                 radius: point.isMultiple(of: 2) ? 22 : 7)
            if point == 0 { core.move(to: position) } else { core.addLine(to: position) }
        }
        core.close()
        color.setFill()
        core.fill()
        context.setFillColor(UIColor.white.withAlphaComponent(0.95).cgColor)
        context.fillEllipse(in: CGRect(x: 44, y: 44, width: 8, height: 8))
        for mote in 0..<3 {
            let position = polar(angle: CGFloat(mote) * .pi * 2 / 3 + CGFloat(variant) * .pi / 6,
                                 radius: 37)
            context.setFillColor(spectrum[mote].cgColor)
            context.fillEllipse(in: CGRect(x: position.x - 4, y: position.y - 4, width: 8, height: 8))
        }
    }

    private static func polar(angle: CGFloat, radius: CGFloat) -> CGPoint {
        CGPoint(x: 48 + cos(angle) * radius, y: 48 + sin(angle) * radius)
    }
}
