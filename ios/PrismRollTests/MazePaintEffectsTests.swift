#if canImport(UIKit) && canImport(SceneKit)
import SceneKit
import XCTest
@testable import PrismRoll

@MainActor
final class MazePaintEffectsTests: XCTestCase {
    func testPaintingBurstReusesPreparedGeometryAndBoundsLiveEffects() throws {
        let effects = MazePaintEffects()
        let level = MazeLevel.generate(number: 30, mode: .endless)
        let board = SCNNode()
        let resources = effects.preparationResources.compactMap { $0 as? SCNGeometry }
        let preparedGeometry = Set(resources.map(ObjectIdentifier.init))
        let preparedMaterials = Set(resources.flatMap(\.materials).map(ObjectIdentifier.init))
        var encounteredNodes: Set<ObjectIdentifier> = []
        let cells = level.openCells.sorted()
        for index in 0..<300 {
            effects.splash(at: cells[index % cells.count], level: level, root: board)
            XCTAssertLessThanOrEqual(board.childNodes.count, MazePaintEffects.splashCapacity)
            for root in board.childNodes {
                XCTAssertEqual(root.name, "paint-effect")
                encounteredNodes.insert(ObjectIdentifier(root))
                XCTAssertEqual(root.childNodes.count, 5, "Keep four droplets and a ripple per splash")
                for node in root.childNodes {
                    encounteredNodes.insert(ObjectIdentifier(node))
                    XCTAssertTrue(preparedGeometry.contains(ObjectIdentifier(try XCTUnwrap(node.geometry))),
                                  "Movement created geometry outside the prepared pool")
                    XCTAssertFalse(node.castsShadow, "Tiny effects should not add shadow passes")
                }
            }
        }
        XCTAssertEqual(encounteredNodes.count, MazePaintEffects.splashCapacity * 6,
                       "A burst should reuse the same effect nodes")
        XCTAssertEqual(resources.count, 8)
        XCTAssertEqual(preparedGeometry.count, 8)
        XCTAssertEqual(preparedMaterials.count, 4)
        XCTAssertEqual(Set(effects.preparationResources.compactMap { $0 as? SCNGeometry }.map(ObjectIdentifier.init)), preparedGeometry)
        print("PRISM_EFFECT_POOL splashes=300 meshNodes=74 geometries=\(preparedGeometry.count) materials=\(preparedMaterials.count) hotPathGeometryAllocations=0")
        effects.reset()
    }

    func testRepeatedCelebrationReusesEveryPieceAndPreparedMaterial() throws {
        let effects = MazePaintEffects()
        let level = MazeLevel.generate(number: 1, mode: .endless)
        let board = SCNNode()
        let ball = SCNNode()
        effects.celebrate(at: level.start, level: level, root: board, ball: ball)
        let celebration = try XCTUnwrap(board.childNode(withName: "celebration", recursively: false))
        let originalPieces = Set(celebration.childNodes.map(ObjectIdentifier.init))
        let resources = Set(effects.preparationResources.compactMap { $0 as? SCNGeometry }.map(ObjectIdentifier.init))
        XCTAssertEqual(originalPieces.count, 34)
        for _ in 0..<20 {
            effects.celebrate(at: level.start, level: level, root: board, ball: ball)
            XCTAssertEqual(board.childNodes.count, 1)
            XCTAssertTrue(board.childNodes[0] === celebration)
            XCTAssertEqual(Set(celebration.childNodes.map(ObjectIdentifier.init)), originalPieces)
            for piece in celebration.childNodes {
                XCTAssertTrue(resources.contains(ObjectIdentifier(try XCTUnwrap(piece.geometry))))
                XCTAssertFalse(piece.castsShadow)
            }
        }
        effects.reset()
        XCTAssertTrue(board.childNodes.isEmpty)
        XCTAssertNil(ball.action(forKey: "celebrate"))
    }

    func testResetCancelsDetachedActionsAndReusesPoolOnNewBoardWithNewTint() throws {
        let effects = MazePaintEffects(tint: .systemPink)
        let oldLevel = MazeLevel.generate(number: 1, mode: .endless)
        let oldBoard = SCNNode()
        let ball = SCNNode()
        effects.splash(at: oldLevel.start, level: oldLevel, root: oldBoard)
        let firstSplash = try XCTUnwrap(oldBoard.childNode(withName: "paint-effect", recursively: false))
        effects.celebrate(at: oldLevel.start, level: oldLevel, root: oldBoard, ball: ball)
        let previousRoots = oldBoard.childNodes
        XCTAssertNotNil(ball.action(forKey: "celebrate"))
        effects.reset()
        XCTAssertTrue(oldBoard.childNodes.isEmpty)
        XCTAssertNil(ball.action(forKey: "celebrate"))
        for root in previousRoots {
            XCTAssertNil(root.parent)
            XCTAssertFalse(root.hasActions)
            for node in root.childNodes { XCTAssertFalse(node.hasActions) }
        }

        let newLevel = MazeLevel.generate(number: 80, mode: .endless)
        let newBoard = SCNNode()
        effects.setTint(.systemCyan)
        effects.splash(at: newLevel.start, level: newLevel, root: newBoard)
        let reused = try XCTUnwrap(newBoard.childNode(withName: "paint-effect", recursively: false))
        XCTAssertTrue(reused === firstSplash)
        XCTAssertTrue(oldBoard.childNodes.isEmpty)
        let center = MazeBoardBuilder.position(of: newLevel.start, in: newLevel)
        XCTAssertEqual(reused.position.x, center.x, accuracy: 0.0001)
        XCTAssertEqual(reused.position.z, center.z, accuracy: 0.0001)
        for node in reused.childNodes {
            XCTAssertEqual(node.geometry?.firstMaterial?.diffuse.contents as? UIColor, .systemCyan)
            XCTAssertEqual(node.geometry?.firstMaterial?.emission.contents as? UIColor, .systemCyan)
        }
        effects.reset()
    }

    func testRendererPreparesInactiveEffectsBeforeTheirFirstUse() {
        let renderer = MazeSceneRenderer()
        XCTAssertTrue((renderer.preparationResources.first as? SCNScene) === renderer.scene)
        let geometries = renderer.preparationResources.compactMap { $0 as? SCNGeometry }
        XCTAssertEqual(geometries.count, 8, "Scene preparation must include unattached effect resources")
        XCTAssertFalse(renderer.scene.rootNode.childNodes.contains { $0.name == "paint-effect" || $0.name == "celebration" })
        renderer.stop()
    }
}
#endif
