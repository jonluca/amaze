import SceneKit
import UIKit

/// Neutral outlined rings identify unpainted cells independently of skin color.
@MainActor
enum MazePathMarkerBuilder {
    static func make(level: MazeLevel) -> [GridCell: SCNNode] {
        let outline = SCNTube(innerRadius: 0.07, outerRadius: 0.17, height: 0.004)
        let ring = SCNTube(innerRadius: 0.095, outerRadius: 0.145, height: 0.006)
        for (geometry, color) in [(outline, UIColor.black), (ring, UIColor.white)] {
            geometry.radialSegmentCount = 24
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = color
            geometry.materials = [material]
        }
        return Dictionary(uniqueKeysWithValues: level.openCells.map { cell in
            let marker = SCNNode(geometry: outline)
            marker.name = "unpainted-marker"
            marker.position = MazeBoardBuilder.position(of: cell, in: level)
            marker.position.y = 0.028
            marker.castsShadow = false
            let inset = SCNNode(geometry: ring)
            inset.position.y = 0.007
            inset.castsShadow = false
            marker.addChildNode(inset)
            return (cell, marker)
        })
    }
}
