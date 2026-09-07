import SceneKit

/// A thin raised contour around the union of playable squares. The blocked
/// regions remain open to the background, including islands inside the maze.
@MainActor
enum MazeWallGeometry {
    static let rimWidth: Float = 0.11
    static let topHeight: Float = 0.34
    static let bevelWidth: Float = 0.025
    static let bottomHeight: Float = -0.22

    static func make(level: MazeLevel) -> SCNGeometry {
        // Every contour and bevel breakpoint lies on this adaptive lattice.
        // Occupancy uses at most nine neighboring cells, independent of maze size.
        let xs = coordinates(size: level.width)
        let zs = coordinates(size: level.height)
        let columns = xs.count - 1
        let rows = zs.count - 1
        let shoulder = topHeight - bevelWidth
        var occupied = [Bool](repeating: false, count: columns * rows)
        var heights = [Float](repeating: shoulder, count: xs.count * zs.count)
        for row in 0..<rows {
            for column in 0..<columns {
                let distance = distanceToPath(x: (xs[column] + xs[column + 1]) / 2,
                                              z: (zs[row] + zs[row + 1]) / 2, level: level)
                occupied[row * columns + column] = distance > 0 && distance < Double(rimWidth)
            }
        }
        for row in zs.indices {
            for column in xs.indices {
                heights[row * xs.count + column] = height(x: xs[column], z: zs[row], level: level)
            }
        }

        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var textureCoordinates: [CGPoint] = []
        var topIndices: [Int32] = []
        var sideIndices: [Int32] = []
        var bevelIndices: [Int32] = []

        func triangle(_ first: SCNVector3, _ second: SCNVector3, _ third: SCNVector3,
                      outward: SCNVector3, indices: inout [Int32]) {
            var b = second
            var c = third
            var normal = cross(subtract(b, first), subtract(c, first))
            if normal.x * outward.x + normal.y * outward.y + normal.z * outward.z < 0 {
                swap(&b, &c)
                normal = SCNVector3(-normal.x, -normal.y, -normal.z)
            }
            let length = sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z)
            guard length > 0 else { return }
            normal = SCNVector3(normal.x / length, normal.y / length, normal.z / length)
            let start = Int32(vertices.count)
            for point in [first, b, c] {
                vertices.append(point)
                normals.append(normal)
                textureCoordinates.append(CGPoint(
                    x: CGFloat((Float(point.x) + Float(level.width) / 2 + rimWidth) / (Float(level.width) + 2 * rimWidth)),
                    y: CGFloat((Float(point.z) + Float(level.height) / 2 + rimWidth) / (Float(level.height) + 2 * rimWidth))
                ))
            }
            indices.append(contentsOf: [start, start + 1, start + 2])
        }

        func side(_ a: SCNVector3, _ b: SCNVector3, normal: SCNVector3) {
            let lowA = SCNVector3(Float(a.x), bottomHeight, Float(a.z))
            let lowB = SCNVector3(Float(b.x), bottomHeight, Float(b.z))
            triangle(lowA, lowB, b, outward: normal, indices: &sideIndices)
            triangle(lowA, b, a, outward: normal, indices: &sideIndices)
        }

        func contains(row: Int, column: Int) -> Bool {
            row >= 0 && row < rows && column >= 0 && column < columns && occupied[row * columns + column]
        }

        for row in 0..<rows {
            for column in 0..<columns where occupied[row * columns + column] {
                let x0 = Float(xs[column]) - Float(level.width) / 2
                let x1 = Float(xs[column + 1]) - Float(level.width) / 2
                let z0 = Float(zs[row]) - Float(level.height) / 2
                let z1 = Float(zs[row + 1]) - Float(level.height) / 2
                let backLeft = SCNVector3(x0, heights[row * xs.count + column], z0)
                let backRight = SCNVector3(x1, heights[row * xs.count + column + 1], z0)
                let frontRight = SCNVector3(x1, heights[(row + 1) * xs.count + column + 1], z1)
                let frontLeft = SCNVector3(x0, heights[(row + 1) * xs.count + column], z1)
                let corners = [backLeft, backRight, frontRight, frontLeft]
                let up = SCNVector3(0, 1, 0)
                if corners.allSatisfy({ Float($0.y) == topHeight }) {
                    triangle(backLeft, backRight, frontRight, outward: up, indices: &topIndices)
                    triangle(backLeft, frontRight, frontLeft, outward: up, indices: &topIndices)
                } else {
                    // Shared corner heights and a center fan avoid tessellator
                    // ambiguity and cracks where diagonal maze cells touch.
                    let center = SCNVector3((x0 + x1) / 2,
                        height(x: (xs[column] + xs[column + 1]) / 2,
                               z: (zs[row] + zs[row + 1]) / 2, level: level), (z0 + z1) / 2)
                    for index in corners.indices {
                        triangle(corners[index], corners[(index + 1) % 4], center,
                                 outward: up, indices: &bevelIndices)
                    }
                }
                if !contains(row: row - 1, column: column) {
                    side(backLeft, backRight, normal: SCNVector3(0, 0, -1))
                }
                if !contains(row: row + 1, column: column) {
                    side(frontRight, frontLeft, normal: SCNVector3(0, 0, 1))
                }
                if !contains(row: row, column: column - 1) {
                    side(frontLeft, backLeft, normal: SCNVector3(-1, 0, 0))
                }
                if !contains(row: row, column: column + 1) {
                    side(backRight, frontRight, normal: SCNVector3(1, 0, 0))
                }
            }
        }
        return SCNGeometry(
            sources: [SCNGeometrySource(vertices: vertices), SCNGeometrySource(normals: normals),
                      SCNGeometrySource(textureCoordinates: textureCoordinates)],
            elements: [SCNGeometryElement(indices: topIndices, primitiveType: .triangles),
                       SCNGeometryElement(indices: sideIndices, primitiveType: .triangles),
                       SCNGeometryElement(indices: bevelIndices, primitiveType: .triangles)]
        )
    }

    private static func coordinates(size: Int) -> [Double] {
        let width = Double(rimWidth)
        let bevel = Double(bevelWidth)
        let offsets = [-width, -width + bevel, -bevel, 0, bevel, width - bevel, width]
        return (0...size).flatMap { boundary in offsets.map { Double(boundary) + $0 } }.sorted()
    }

    private static func height(x: Double, z: Double, level: MazeLevel) -> Float {
        let distance = distanceToPath(x: x, z: z, level: level)
        let rise = min(Double(bevelWidth), max(0, min(distance, Double(rimWidth) - distance)))
        return min(topHeight, topHeight - bevelWidth + Float(rise))
    }

    /// Chebyshev distance gives the square, mitered silhouette of a tile grid.
    /// The rim is narrower than a cell, so only the local 3×3 neighborhood matters.
    private static func distanceToPath(x: Double, z: Double, level: MazeLevel) -> Double {
        let column = Int(floor(x))
        let row = Int(floor(z))
        var nearest = Double.infinity
        for candidateRow in (row - 1)...(row + 1) {
            for candidateColumn in (column - 1)...(column + 1)
                where level.openCells.contains(GridCell(row: candidateRow, column: candidateColumn)) {
                let dx = max(0, max(Double(candidateColumn) - x, x - Double(candidateColumn + 1)))
                let dz = max(0, max(Double(candidateRow) - z, z - Double(candidateRow + 1)))
                nearest = min(nearest, max(dx, dz))
            }
        }
        return nearest
    }

    private static func subtract(_ a: SCNVector3, _ b: SCNVector3) -> SCNVector3 {
        SCNVector3(a.x - b.x, a.y - b.y, a.z - b.z)
    }

    private static func cross(_ a: SCNVector3, _ b: SCNVector3) -> SCNVector3 {
        SCNVector3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
    }
}
