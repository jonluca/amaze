#if canImport(UIKit) && canImport(SceneKit)
import SceneKit
import XCTest
@testable import PrismRoll

@MainActor
final class MazeGeometryTests: XCTestCase {
    func testRenderedRimLeavesAllTileInteriorsAndExteriorOpen() throws {
        // Self-touching contours once tessellated across playable channels.
        // The new rim must also leave blocked-cell centers as visible cutouts.
        for number in [1, 2, 5, 12, 18, 26, 100, 1_000_000] {
            for mode in GameMode.allCases {
                let level = MazeLevel.generate(number: number, mode: mode)
                let triangles = try renderedTriangles(MazeWallGeometry.make(level: level))
                for row in -1...level.height {
                    for column in -1...level.width {
                        let cell = GridCell(row: row, column: column)
                        for offset in [Float(-0.35), 0, 0.35] {
                            let center = position(of: cell, in: level)
                            let point = SIMD3(center.x + offset, Float(2), center.z - offset)
                            XCTAssertFalse(rayHits(triangles, from: point, to: SIMD3(point.x, -0.2, point.z)),
                                "Rim filled a tile interior: \(mode), level \(number), \(cell), offset \(offset)")
                        }
                    }
                }
            }
        }
    }

    func testChannelEdgesHavePhysicalRaisedRimsWithoutBlockingNeighbors() throws {
        let generated = [1, 18, 100].map { MazeLevel.generate(number: $0, mode: .endless) }
        for level in generated + shapeFixtures {
            let triangles = try renderedTriangles(MazeWallGeometry.make(level: level))
            for cell in level.openCells {
                let center = position(of: cell, in: level)
                for direction in MoveDirection.allCases {
                    let neighbor = cell.neighbor(in: direction)
                    let dx = Float(neighbor.column - cell.column)
                    let dz = Float(neighbor.row - cell.row)
                    for offset in [Float(-0.42), 0, 0.42] {
                        let start = SIMD3(center.x + dz * offset, Float(0.1), center.z + dx * offset)
                        let end = SIMD3(start.x + dx * 0.65, start.y, start.z + dz * 0.65)
                        XCTAssertEqual(rayHits(triangles, from: start, to: end), !level.openCells.contains(neighbor),
                            "Missing or obstructing rim: level \(level.number), \(cell), \(direction), offset \(offset)")
                    }
                }
            }
        }
    }

    func testFloorExactlyFollowsRaggedPathsAndLeavesHolesTransparent() throws {
        for level in shapeFixtures {
            let triangles = try renderedTriangles(MazePathGeometry.makeFloor(level: level))
            for row in -1...level.height {
                for column in -1...level.width {
                    let cell = GridCell(row: row, column: column)
                    let center = position(of: cell, in: level)
                    for dx in [Float(-0.49), 0, 0.49] {
                        for dz in [Float(-0.49), 0, 0.49] {
                            let start = SIMD3(center.x + dx, Float(1), center.z + dz)
                            XCTAssertEqual(rayHits(triangles, from: start, to: SIMD3(start.x, -0.2, start.z)),
                                level.openCells.contains(cell),
                                "Floor bridged a cutout or lost a path: fixture \(level.number), \(cell), offset \(dx), \(dz)")
                        }
                    }
                }
            }
            XCTAssertEqual(projectedArea(of: triangles), Float(level.openCells.count), accuracy: 0.0001,
                "The floor must cover exactly the playable squares, without a rectangular base")
        }
    }

    func testLateBoardFloorAndGridPreserveAllOpenTilesAndCutouts() throws {
        let level = MazeLevel.generate(number: 100, mode: .endless)
        XCTAssertEqual(level.width, 16)
        XCTAssertEqual(level.height, 16)
        XCTAssertGreaterThan(level.openCells.count, 150)
        let triangles = try renderedTriangles(MazePathGeometry.makeFloor(level: level))
        for row in 0..<level.height {
            for column in 0..<level.width {
                let cell = GridCell(row: row, column: column)
                let center = position(of: cell, in: level)
                XCTAssertEqual(rayHits(triangles, from: center + SIMD3(0, 1, 0), to: center - SIMD3(0, 1, 0)),
                    level.openCells.contains(cell), "Late-board floor coverage differs at \(cell)")
            }
        }
        XCTAssertEqual(projectedArea(of: triangles), Float(level.openCells.count), accuracy: 0.001)
        try assertGridStaysOnPaths(level)
    }

    func testGridLinesStayOnPathTilesAroundConcaveAndTouchingCorners() throws {
        for level in shapeFixtures { try assertGridStaysOnPaths(level) }
    }

    func testCornerTouchingPathsCannotPassThroughRimJunctions() throws {
        let level = fixture([".#", "#."], number: 90)
        let triangles = try renderedTriangles(MazeWallGeometry.make(level: level))
        let start = position(of: GridCell(row: 0, column: 0), in: level) + SIMD3(0, 0.1, 0)
        let end = position(of: GridCell(row: 1, column: 1), in: level) + SIMD3(0, 0.1, 0)
        XCTAssertTrue(rayHits(triangles, from: start, to: end), "Diagonal contact left a gap through two closed boundaries")
    }

    private var shapeFixtures: [MazeLevel] {
        [
            fixture(["...##", ".#.##", ".....", "##.#.", "##..."], number: 81),
            fixture([".....", ".###.", ".###.", ".###.", "....."], number: 82),
            fixture(["....", ".#..", "..#.", "...."], number: 83),
            fixture([".#", "#."], number: 84),
            fixture([".#..", "....", ".#.#", "...#"], number: 85)
        ]
    }

    private func fixture(_ rows: [String], number: Int) -> MazeLevel {
        var cells: Set<GridCell> = []
        for (row, line) in rows.enumerated() {
            for (column, value) in line.enumerated() where value == "." {
                cells.insert(GridCell(row: row, column: column))
            }
        }
        return MazeLevel(number: number, mode: .endless, width: rows[0].count, height: rows.count,
            openCells: cells, start: cells.sorted()[0], solution: [], moveLimit: nil)
    }

    private func position(of cell: GridCell, in level: MazeLevel) -> SIMD3<Float> {
        SIMD3(Float(cell.column) - Float(level.width - 1) / 2, 0,
            Float(cell.row) - Float(level.height - 1) / 2)
    }

    private func projectedArea(of triangles: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)]) -> Float {
        triangles.reduce(0) { total, triangle in
            let (a, b, c) = triangle
            return total + abs((b.x - a.x) * (c.z - a.z) - (b.z - a.z) * (c.x - a.x)) / 2
        }
    }

    private func assertGridStaysOnPaths(_ level: MazeLevel, file: StaticString = #filePath, line: UInt = #line) throws {
        let grid = try renderedTriangles(MazePathGeometry.makeGrid(level: level))
        let floor = try renderedTriangles(MazePathGeometry.makeFloor(level: level))
        XCTAssertGreaterThan(projectedArea(of: grid), 0, file: file, line: line)
        XCTAssertLessThan(projectedArea(of: grid), Float(level.openCells.count) * 0.15,
            "Grid obscures too much of the playable floor", file: file, line: line)
        for (a, b, c) in grid {
            for point in [a, b, c, (a + b + c) / 3] {
                let liesOnPath = level.openCells.contains { cell in
                    let center = position(of: cell, in: level)
                    return abs(center.x - point.x) <= 0.50001 && abs(center.z - point.z) <= 0.50001
                }
                XCTAssertTrue(liesOnPath, "Grid spills into a hole or outside the board", file: file, line: line)
            }
            let center = (a + b + c) / 3
            XCTAssertTrue(rayHits(floor, from: center + SIMD3(0, 1, 0), to: center - SIMD3(0, 1, 0)),
                "Grid triangle crosses an empty cutout", file: file, line: line)
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
