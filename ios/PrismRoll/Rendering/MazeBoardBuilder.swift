import SceneKit
import UIKit

@MainActor
enum MazeBoardBuilder {
    static func build(level: MazeLevel, tint: UIColor, theme: BoardTheme) -> (root: SCNNode, paintTiles: [GridCell: SCNNode], coins: [GridCell: SCNNode]) {
        let root = SCNNode()
        root.name = "maze-board"
        let topMaterial = matte(BallMaterialFactory.color(hex: theme.topHex))
        topMaterial.lightingModel = .blinn
        topMaterial.specular.contents = UIColor.white
        topMaterial.specular.intensity = theme == .midnight ? 0.5 : 0.18
        topMaterial.shininess = 0.65
        let sideMaterial = matte(BallMaterialFactory.color(hex: theme.sideHex))
        let rim = matte(BallMaterialFactory.color(hex: theme == .timber ? "3B2419" : "162039"))
        let base = box(width: CGFloat(level.width) + 0.58, height: 0.28,
                       length: CGFloat(level.height) + 0.58, radius: 0.12, material: rim)
        base.position.y = -0.17
        root.addChildNode(base)

        let edgeMaterial = matte(theme == .timber ? BallMaterialFactory.color(hex: "9D683B") : tint)
        edgeMaterial.emission.contents = theme == .timber ? UIColor.black : tint
        edgeMaterial.emission.intensity = 0.3
        let edge = box(width: CGFloat(level.width) + 0.54, height: 0.038,
                       length: CGFloat(level.height) + 0.54, radius: 0.018, material: edgeMaterial)
        edge.name = "board-accent"
        edge.position.y = -0.046
        root.addChildNode(edge)

        let floor = box(width: CGFloat(level.width) + 0.03, height: 0.04,
                        length: CGFloat(level.height) + 0.03, radius: 0.015,
                        material: matte(BallMaterialFactory.color(hex: theme.pathHex)))
        floor.position.y = -0.01
        floor.castsShadow = false
        root.addChildNode(floor)

        let sculpture = MazeWallGeometry.make(level: level)
        sculpture.materials = [topMaterial, sideMaterial, topMaterial]
        let walls = SCNNode(geometry: sculpture)
        walls.name = "sculpted-walls"
        root.addChildNode(walls)

        var tiles: [GridCell: SCNNode] = [:]
        let paintMaterial = BallMaterialFactory.paint(tint)
        for cell in level.openCells {
            let center = position(of: cell, in: level)
            // Shared edges have no bevel or gap: neighboring surfaces form a
            // continuous lacquered channel as they are painted.
            let geometry = SCNPlane(width: 1, height: 1)
            geometry.materials = [paintMaterial]
            let paint = SCNNode(geometry: geometry)
            paint.eulerAngles.x = -.pi / 2
            paint.position = SCNVector3(center.x, 0.018, center.z)
            paint.opacity = 0
            paint.castsShadow = false
            root.addChildNode(paint)
            tiles[cell] = paint
            addChannelOcclusion(cell: cell, level: level, to: root)
        }

        var coins: [GridCell: SCNNode] = [:]
        for cell in level.coinCells {
            let coin = MazeCoinBuilder.make()
            let center = position(of: cell, in: level)
            coin.position = SCNVector3(center.x, 0.39, center.z)
            root.addChildNode(coin)
            coins[cell] = coin
        }
        return (root, tiles, coins)
    }

    static func position(of cell: GridCell, in level: MazeLevel) -> SCNVector3 {
        SCNVector3(Float(cell.column) - Float(level.width - 1) / 2, 0,
                   Float(cell.row) - Float(level.height - 1) / 2)
    }

    static func matte(_ color: UIColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .lambert
        material.diffuse.contents = color
        material.locksAmbientWithDiffuse = true
        return material
    }

    private static func addChannelOcclusion(cell: GridCell, level: MazeLevel, to root: SCNNode) {
        let center = position(of: cell, in: level)
        let sides = [(0, -1), (0, 1), (-1, 0), (1, 0)]
        for (row, column) in sides where !level.openCells.contains(GridCell(row: cell.row + row, column: cell.column + column)) {
            let plane = SCNPlane(width: column == 0 ? 1 : 0.11, height: row == 0 ? 1 : 0.11)
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = UIColor.black.withAlphaComponent(0.16)
            material.writesToDepthBuffer = false
            plane.materials = [material]
            let node = SCNNode(geometry: plane)
            node.eulerAngles.x = -.pi / 2
            node.position = SCNVector3(center.x + Float(column) * 0.455, 0.023, center.z + Float(row) * 0.455)
            node.castsShadow = false
            root.addChildNode(node)
        }
    }

    private static func box(width: CGFloat, height: CGFloat, length: CGFloat, radius: CGFloat, material: SCNMaterial) -> SCNNode {
        let geometry = SCNBox(width: width, height: height, length: length, chamferRadius: radius)
        geometry.chamferSegmentCount = 4
        geometry.materials = [material]
        return SCNNode(geometry: geometry)
    }
}
