import SceneKit
import UIKit

/// Builds explicit closed wall faces rather than passing self-touching maze
/// contours to SCNShape's polygon tessellator. Every channel stays open even
/// when several wall islands meet at a grid corner.
@MainActor
enum MazeWallGeometry {
    static func make(level: MazeLevel) -> SCNGeometry {
        var filled: Set<GridCell> = []
        for row in -1...level.height {
            for column in -1...level.width {
                let cell = GridCell(row: row, column: column)
                if !level.openCells.contains(cell) { filled.insert(cell) }
            }
        }
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var coordinates: [CGPoint] = []
        var topIndices: [Int32] = []
        var sideIndices: [Int32] = []
        var bevelIndices: [Int32] = []
        let top: Float = 0.51
        let bevel: Float = 0.035
        let shoulder = top - bevel
        let bottom: Float = -0.02

        func quad(_ points: [SCNVector3], normal: SCNVector3, indices: inout [Int32]) {
            let start = Int32(vertices.count)
            vertices.append(contentsOf: points)
            normals.append(contentsOf: Array(repeating: normal, count: 4))
            for point in points {
                coordinates.append(CGPoint(x: (CGFloat(point.x) + CGFloat(level.width) / 2 + 0.23) / (CGFloat(level.width) + 0.46),
                                           y: (CGFloat(point.z) + CGFloat(level.height) / 2 + 0.23) / (CGFloat(level.height) + 0.46)))
            }
            let a = SCNVector3(points[1].x - points[0].x, points[1].y - points[0].y, points[1].z - points[0].z)
            let b = SCNVector3(points[2].x - points[0].x, points[2].y - points[0].y, points[2].z - points[0].z)
            let cross = SCNVector3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
            let facing = cross.x * normal.x + cross.y * normal.y + cross.z * normal.z
            indices.append(contentsOf: facing >= 0 ? [start, start + 1, start + 2, start, start + 2, start + 3]
                : [start, start + 2, start + 1, start, start + 3, start + 2])
        }

        for cell in filled {
            let west = !filled.contains(GridCell(row: cell.row, column: cell.column - 1))
            let east = !filled.contains(GridCell(row: cell.row, column: cell.column + 1))
            let north = !filled.contains(GridCell(row: cell.row - 1, column: cell.column))
            let south = !filled.contains(GridCell(row: cell.row + 1, column: cell.column))
            let x0 = coordinate(cell.column, size: level.width)
            let x1 = coordinate(cell.column + 1, size: level.width)
            let z0 = coordinate(cell.row, size: level.height)
            let z1 = coordinate(cell.row + 1, size: level.height)
            let left = x0 + (west ? bevel : 0)
            let right = x1 - (east ? bevel : 0)
            let back = z0 + (north ? bevel : 0)
            let front = z1 - (south ? bevel : 0)
            quad([SCNVector3(left, top, back), SCNVector3(right, top, back), SCNVector3(right, top, front), SCNVector3(left, top, front)],
                 normal: SCNVector3(0, 1, 0), indices: &topIndices)
            if north {
                quad([SCNVector3(x0, bottom, z0), SCNVector3(x1, bottom, z0), SCNVector3(x1, shoulder, z0), SCNVector3(x0, shoulder, z0)], normal: SCNVector3(0, 0, -1), indices: &sideIndices)
                quad([SCNVector3(x0, shoulder, z0), SCNVector3(x1, shoulder, z0), SCNVector3(right, top, back), SCNVector3(left, top, back)], normal: SCNVector3(0, 0.707, -0.707), indices: &bevelIndices)
            }
            if south {
                quad([SCNVector3(x1, bottom, z1), SCNVector3(x0, bottom, z1), SCNVector3(x0, shoulder, z1), SCNVector3(x1, shoulder, z1)], normal: SCNVector3(0, 0, 1), indices: &sideIndices)
                quad([SCNVector3(x1, shoulder, z1), SCNVector3(x0, shoulder, z1), SCNVector3(left, top, front), SCNVector3(right, top, front)], normal: SCNVector3(0, 0.707, 0.707), indices: &bevelIndices)
            }
            if west {
                quad([SCNVector3(x0, bottom, z1), SCNVector3(x0, bottom, z0), SCNVector3(x0, shoulder, z0), SCNVector3(x0, shoulder, z1)], normal: SCNVector3(-1, 0, 0), indices: &sideIndices)
                quad([SCNVector3(x0, shoulder, z1), SCNVector3(x0, shoulder, z0), SCNVector3(left, top, back), SCNVector3(left, top, front)], normal: SCNVector3(-0.707, 0.707, 0), indices: &bevelIndices)
            }
            if east {
                quad([SCNVector3(x1, bottom, z0), SCNVector3(x1, bottom, z1), SCNVector3(x1, shoulder, z1), SCNVector3(x1, shoulder, z0)], normal: SCNVector3(1, 0, 0), indices: &sideIndices)
                quad([SCNVector3(x1, shoulder, z0), SCNVector3(x1, shoulder, z1), SCNVector3(right, top, front), SCNVector3(right, top, back)], normal: SCNVector3(0.707, 0.707, 0), indices: &bevelIndices)
            }
        }
        return SCNGeometry(sources: [SCNGeometrySource(vertices: vertices), SCNGeometrySource(normals: normals),
                                     SCNGeometrySource(textureCoordinates: coordinates)],
                           elements: [SCNGeometryElement(indices: topIndices, primitiveType: .triangles),
                                      SCNGeometryElement(indices: sideIndices, primitiveType: .triangles),
                                      SCNGeometryElement(indices: bevelIndices, primitiveType: .triangles)])
    }

    private static func coordinate(_ value: Int, size: Int) -> Float {
        if value < 0 { return -Float(size) / 2 - 0.23 }
        if value > size { return Float(size) / 2 + 0.23 }
        return Float(value) - Float(size) / 2
    }
}
