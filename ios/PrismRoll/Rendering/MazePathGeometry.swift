import SceneKit

/// The board has no backing rectangle: both meshes contain playable cells only.
@MainActor
enum MazePathGeometry {
    static let gridHeight: Float = 0.021
    static let gridInset: Float = 0.028
    static let gridWidth: Float = 0.02

    static func makeFloor(level: MazeLevel) -> SCNGeometry {
        make(level: level, grid: false)
    }

    static func makeGrid(level: MazeLevel) -> SCNGeometry {
        make(level: level, grid: true)
    }

    private static func make(level: MazeLevel, grid: Bool) -> SCNGeometry {
        var vertices: [SCNVector3] = []
        var indices: [Int32] = []
        let quadsPerCell = grid ? 4 : 1
        vertices.reserveCapacity(level.openCells.count * quadsPerCell * 4)
        indices.reserveCapacity(level.openCells.count * quadsPerCell * 6)

        func quad(x0: Float, x1: Float, z0: Float, z1: Float) {
            let first = Int32(vertices.count)
            let y = grid ? gridHeight : 0
            vertices.append(contentsOf: [SCNVector3(x0, y, z0), SCNVector3(x0, y, z1),
                                         SCNVector3(x1, y, z1), SCNVector3(x1, y, z0)])
            indices.append(contentsOf: [first, first + 1, first + 2, first, first + 2, first + 3])
        }

        for cell in level.openCells.sorted() {
            let x0 = Float(cell.column) - Float(level.width) / 2
            let z0 = Float(cell.row) - Float(level.height) / 2
            guard grid else {
                quad(x0: x0, x1: x0 + 1, z0: z0, z1: z0 + 1)
                continue
            }
            // Separate inset outlines keep individual squares legible on painted
            // paths. The four strips meet without overlapping at their corners.
            let left = x0 + gridInset
            let right = x0 + 1 - gridInset
            let back = z0 + gridInset
            let front = z0 + 1 - gridInset
            quad(x0: left, x1: right, z0: back, z1: back + gridWidth)
            quad(x0: left, x1: right, z0: front - gridWidth, z1: front)
            quad(x0: left, x1: left + gridWidth, z0: back + gridWidth, z1: front - gridWidth)
            quad(x0: right - gridWidth, x1: right, z0: back + gridWidth, z1: front - gridWidth)
        }
        return SCNGeometry(
            sources: [SCNGeometrySource(vertices: vertices),
                      SCNGeometrySource(normals: Array(repeating: SCNVector3(0, 1, 0), count: vertices.count))],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
    }
}
