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
        let edgeMaterial = matte(BallMaterialFactory.color(hex: theme.edgeHex))
        edgeMaterial.emission.contents = BallMaterialFactory.color(hex: theme.edgeHex)
        edgeMaterial.emission.intensity = 0.22

        // Only playable cells have a floor. There is no rectangular tray behind
        // the contour: exterior notches and interior islands show the backdrop.
        let floorGeometry = MazePathGeometry.makeFloor(level: level)
        floorGeometry.materials = [matte(BallMaterialFactory.color(hex: theme.pathHex))]
        let floor = SCNNode(geometry: floorGeometry)
        floor.name = "path-floor"
        floor.castsShadow = false
        root.addChildNode(floor)

        let sculpture = MazeWallGeometry.make(level: level)
        sculpture.materials = [topMaterial, sideMaterial, edgeMaterial]
        let walls = SCNNode(geometry: sculpture)
        walls.name = "sculpted-walls"
        root.addChildNode(walls)

        var tiles: [GridCell: SCNNode] = [:]
        let paintMaterial = BallMaterialFactory.paint(tint)
        for cell in level.openCells {
            let center = position(of: cell, in: level)
            // Paint remains continuous; the static grid is drawn just above it.
            let geometry = SCNPlane(width: 1, height: 1)
            geometry.materials = [paintMaterial]
            let paint = SCNNode(geometry: geometry)
            paint.eulerAngles.x = -.pi / 2
            paint.position = SCNVector3(center.x, 0.018, center.z)
            paint.opacity = 0
            paint.castsShadow = false
            root.addChildNode(paint)
            tiles[cell] = paint
        }
        let gridMaterial = SCNMaterial()
        gridMaterial.lightingModel = .constant
        gridMaterial.diffuse.contents = BallMaterialFactory.color(hex: theme.gridHex).withAlphaComponent(0.7)
        gridMaterial.writesToDepthBuffer = false
        let gridGeometry = MazePathGeometry.makeGrid(level: level)
        gridGeometry.materials = [gridMaterial]
        let grid = SCNNode(geometry: gridGeometry)
        grid.name = "path-grid"
        grid.castsShadow = false
        root.addChildNode(grid)
        root.addChildNode(MazeChannelOcclusion.make(level: level))

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
}
