#if canImport(UIKit) && canImport(SceneKit)
import SceneKit
import XCTest
@testable import PrismRoll

@MainActor
final class MazePaintPaletteTests: XCTestCase {
    func testEverySkinHasDistinctPaintThatChangesBetweenLevels() {
        for skin in BallSkin.catalog {
            var previous: String?
            for number in 1...24 {
                let paint = MazePaintPalette.hex(for: skin, levelNumber: number)
                XCTAssertNotEqual(paint, skin.hex, "The ball must not disappear into its paint")
                XCTAssertNotEqual(paint, previous, "Consecutive levels should vary the track for \(skin.name)")
                let difference = abs(hue(paint) - hue(skin.hex))
                XCTAssertGreaterThanOrEqual(min(difference, 1 - difference), 0.149,
                                            "\(skin.name) needs a clearly separate paint hue")
                previous = paint
            }
        }
    }

    func testReplayAndLateLevelsKeepDeterministicColorPairings() {
        for skin in BallSkin.catalog {
            for number in [1, 30, 100, 1_000_000, Int.max] {
                let first = MazePaintPalette.hex(for: skin, levelNumber: number)
                _ = MazePaintPalette.hex(for: skin, levelNumber: 3)
                XCTAssertEqual(first, MazePaintPalette.hex(for: skin, levelNumber: number))
            }
            XCTAssertEqual(MazePaintPalette.hex(for: skin, levelNumber: Int.min),
                           MazePaintPalette.hex(for: skin, levelNumber: 1))
        }
    }

    func testRendererVariesTrackAndEffectsWithoutRecoloringSelectedBall() async throws {
        let renderer = MazeSceneRenderer()
        defer { renderer.stop() }
        var ballTexture: UIImage?
        var lastPaint: UIColor?
        let skin = BallSkin.catalog[0]
        for number in [1, 2, 3] {
            let level = fixture(number: number)
            let ready = expectation(description: "Level \(number) materials")
            renderer.onResourcesReady = { ready.fulfill() }
            renderer.update(level: level, position: level.start, painted: [level.start],
                            skin: skin, isComplete: false, resetID: UUID())
            await fulfillment(of: [ready], timeout: 10)
            renderer.onResourcesReady = nil
            let board = try XCTUnwrap(renderer.scene.rootNode.childNode(withName: "maze-board", recursively: false))
            let tiles = board.childNodes.filter { $0.geometry is SCNPlane }
            XCTAssertEqual(tiles.count, level.openCells.count)
            let paint = try XCTUnwrap(tiles.first?.geometry?.firstMaterial?.diffuse.contents as? UIColor)
            XCTAssertNotEqual(paint, BallMaterialFactory.color(hex: skin.hex))
            if let lastPaint { XCTAssertNotEqual(paint, lastPaint) }
            lastPaint = paint
            for tile in tiles { XCTAssertEqual(tile.geometry?.firstMaterial?.diffuse.contents as? UIColor, paint) }
            let effect = try XCTUnwrap(renderer.preparationResources.compactMap { $0 as? SCNGeometry }.first)
            XCTAssertEqual(effect.firstMaterial?.diffuse.contents as? UIColor, paint,
                           "Splashes must use the painted track color")
            var ball: SCNNode?
            renderer.scene.rootNode.enumerateChildNodes { node, _ in
                if let sphere = node.geometry as? SCNSphere, abs(sphere.radius - 0.405) < 0.001 { ball = node }
            }
            let texture = try XCTUnwrap(ball?.geometry?.firstMaterial?.diffuse.contents as? UIImage)
            if let ballTexture { XCTAssertTrue(texture === ballTexture, "A new track color must preserve the ball skin") }
            ballTexture = texture
        }
    }

    private func fixture(number: Int) -> MazeLevel {
        let cells = Set((0..<5).map { GridCell(row: 0, column: $0) })
        return MazeLevel(number: number, mode: .endless, width: 5, height: 1,
                         openCells: cells, start: GridCell(row: 0, column: 0), solution: [.right], moveLimit: nil)
    }

    private func hue(_ hex: String) -> CGFloat {
        var value: CGFloat = 0
        BallMaterialFactory.color(hex: hex).getHue(&value, saturation: nil, brightness: nil, alpha: nil)
        return value
    }
}
#endif
