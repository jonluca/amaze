import SwiftUI

struct ChallengeBoardPreview: View {
    let level: MazeLevel

    var body: some View {
        Canvas { context, size in
            let tile = min(size.width / CGFloat(level.width), size.height / CGFloat(level.height))
            let origin = CGPoint(x: (size.width - tile * CGFloat(level.width)) / 2,
                                 y: (size.height - tile * CGFloat(level.height)) / 2)
            for cell in level.openCells {
                let rect = CGRect(x: origin.x + CGFloat(cell.column) * tile + tile * 0.055,
                                  y: origin.y + CGFloat(cell.row) * tile + tile * 0.055,
                                  width: tile * 0.89, height: tile * 0.89)
                let hue = 0.47 + 0.28 * Double(cell.row + cell.column) / Double(level.width + level.height)
                context.fill(Path(roundedRect: rect, cornerRadius: tile * 0.14),
                             with: .color(Color(hue: hue, saturation: 0.59, brightness: 0.93)))
            }
            let ball = CGRect(x: origin.x + (CGFloat(level.start.column) + 0.20) * tile,
                              y: origin.y + (CGFloat(level.start.row) + 0.20) * tile,
                              width: tile * 0.60, height: tile * 0.60)
            context.fill(Path(ellipseIn: ball), with: .color(.white))
            context.stroke(Path(ellipseIn: ball), with: .color(.black.opacity(0.16)), lineWidth: tile * 0.04)
        }
        .accessibilityLabel("\(level.width) by \(level.height) maze, \(level.openCells.count) open squares")
    }
}
