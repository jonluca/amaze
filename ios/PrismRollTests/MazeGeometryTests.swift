#if canImport(UIKit) && canImport(SceneKit)
import SceneKit
import XCTest
@testable import PrismRoll

@MainActor
final class MazeGeometryTests: XCTestCase {
    func testRenderedWallsLeaveEveryGeneratedChannelOpen() throws {
        // Level 18 previously produced self-touching contours that SCNShape
        // tessellated across playable channels, despite the level being valid.
        for number in [1, 2, 5, 12, 18, 26, 100, 1_000_000] {
            for mode in GameMode.allCases {
                let level = MazeLevel.generate(number: number, mode: mode)
                let triangles = try renderedTriangles(MazeWallGeometry.make(level: level))
                for row in 0..<level.height {
                    for column in 0..<level.width {
                        let cell = GridCell(row: row, column: column)
                        for offset in [Float(-0.35), 0, 0.35] {
                            let x = Float(column) - Float(level.width) / 2 + 0.5 + offset
                            let z = Float(row) - Float(level.height) / 2 + 0.5 - offset
                            let hits = rayHits(triangles, from: SIMD3(x, 2, z), to: SIMD3(x, 0.1, z))
                            XCTAssertEqual(hits, !level.openCells.contains(cell),
                                "Rendered channel mismatch: \(mode), level \(number), \(cell), offset \(offset)")
                        }
                    }
                }
            }
        }
    }

    func testChannelEdgesHavePhysicalRaisedWalls() throws {
        for number in [1, 18, 100] {
            let level = MazeLevel.generate(number: number, mode: .endless)
            let triangles = try renderedTriangles(MazeWallGeometry.make(level: level))
            for cell in level.openCells {
                let start = SIMD3(Float(cell.column) - Float(level.width) / 2 + 0.5,
                    Float(0.25), Float(cell.row) - Float(level.height) / 2 + 0.5)
                for direction in MoveDirection.allCases {
                    let neighbor = cell.neighbor(in: direction)
                    let end = SIMD3(start.x + Float(neighbor.column - cell.column) * 0.65,
                        start.y, start.z + Float(neighbor.row - cell.row) * 0.65)
                    XCTAssertEqual(rayHits(triangles, from: start, to: end), !level.openCells.contains(neighbor),
                        "Missing or obstructing side wall: level \(number), \(cell), \(direction)")
                }
            }
        }
    }

    // Read the actual mesh supplied to SceneKit. CPU triangle intersections avoid
    // requiring a rendered presentation tree or a GPU frame in a unit test.
    private func renderedTriangles(_ geometry: SCNGeometry) throws -> [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] {
        let source = try XCTUnwrap(geometry.sources(for: .vertex).first)
        XCTAssertEqual(source.bytesPerComponent, MemoryLayout<Float>.size)
        XCTAssertEqual(source.componentsPerVector, 3)
        let vertices: [SIMD3<Float>] = source.data.withUnsafeBytes { bytes in
            (0..<source.vectorCount).map { index in
                let offset = source.dataOffset + index * source.dataStride
                return SIMD3(bytes.loadUnaligned(fromByteOffset: offset, as: Float.self),
                    bytes.loadUnaligned(fromByteOffset: offset + 4, as: Float.self),
                    bytes.loadUnaligned(fromByteOffset: offset + 8, as: Float.self))
            }
        }
        var triangles: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] = []
        for element in geometry.elements {
            XCTAssertEqual(element.primitiveType, .triangles)
            XCTAssertEqual(element.bytesPerIndex, MemoryLayout<Int32>.size)
            element.data.withUnsafeBytes { bytes in
                for triangle in 0..<element.primitiveCount {
                    let indices = (0..<3).map { component in
                        Int(bytes.loadUnaligned(fromByteOffset: (triangle * 3 + component) * 4, as: Int32.self))
                    }
                    triangles.append((vertices[indices[0]], vertices[indices[1]], vertices[indices[2]]))
                }
            }
        }
        XCTAssertFalse(triangles.isEmpty)
        return triangles
    }

    private func rayHits(_ triangles: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)],
                         from start: SIMD3<Float>, to end: SIMD3<Float>) -> Bool {
        let direction = end - start
        for (a, b, c) in triangles {
            let edge1 = b - a
            let edge2 = c - a
            let perpendicular = simd_cross(direction, edge2)
            let determinant = simd_dot(edge1, perpendicular)
            if abs(determinant) < 0.00001 { continue }
            let inverse = 1 / determinant
            let offset = start - a
            let u = simd_dot(offset, perpendicular) * inverse
            if u < -0.00001 || u > 1.00001 { continue }
            let cross = simd_cross(offset, edge1)
            let v = simd_dot(direction, cross) * inverse
            if v < -0.00001 || u + v > 1.00001 { continue }
            let distance = simd_dot(edge2, cross) * inverse
            if distance >= 0 && distance <= 1 { return true }
        }
        return false
    }
}
#endif
