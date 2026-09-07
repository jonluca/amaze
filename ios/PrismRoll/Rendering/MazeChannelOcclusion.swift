import SceneKit
import UIKit

/// Static shading for every channel edge shares one geometry and material.
@MainActor
enum MazeChannelOcclusion {
    static func make(level: MazeLevel) -> SCNNode {
        var vertices: [SCNVector3] = []
        var indices: [Int32] = []
        let sides = [(0, -1), (0, 1), (-1, 0), (1, 0)]
        for cell in level.openCells.sorted() {
            let center = MazeBoardBuilder.position(of: cell, in: level)
            for (row, column) in sides where !level.openCells.contains(GridCell(row: cell.row + row, column: cell.column + column)) {
                let x = center.x + Float(column) * 0.44
                let z = center.z + Float(row) * 0.44
                let halfWidth: Float = column == 0 ? 0.5 : 0.06
                let halfDepth: Float = row == 0 ? 0.5 : 0.06
                let first = Int32(vertices.count)
                vertices.append(contentsOf: [
                    SCNVector3(x - halfWidth, 0.023, z - halfDepth),
                    SCNVector3(x - halfWidth, 0.023, z + halfDepth),
                    SCNVector3(x + halfWidth, 0.023, z + halfDepth),
                    SCNVector3(x + halfWidth, 0.023, z - halfDepth)
                ])
                indices.append(contentsOf: [first, first + 1, first + 2, first, first + 2, first + 3])
            }
        }
        let node = SCNNode()
        node.name = "channel-occlusion"
        node.castsShadow = false
        guard !vertices.isEmpty else { return node }
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = UIColor.black.withAlphaComponent(0.22)
        material.writesToDepthBuffer = false
        let geometry = SCNGeometry(
            sources: [SCNGeometrySource(vertices: vertices),
                      SCNGeometrySource(normals: Array(repeating: SCNVector3(0, 1, 0), count: vertices.count))],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
        geometry.materials = [material]
        node.geometry = geometry
        return node
    }
}
