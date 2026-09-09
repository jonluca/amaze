#if canImport(UIKit) && canImport(SceneKit)
import SceneKit
import XCTest
@testable import PrismRoll

@MainActor
final class MazeCompletionCoinEffectsTests: XCTestCase {
    func testCompletionReusesPreparedCoinsAndResetClearsPreviousBoard() throws {
        let effects = MazeCompletionCoinEffects()
        let level = MazeLevel.generate(number: 1, mode: .endless)
        let board = SCNNode()
        let geometries = effects.preparationResources.compactMap { $0 as? SCNGeometry }
        let prepared = Set(geometries.map(ObjectIdentifier.init))
        XCTAssertEqual(prepared.count, 3)
        effects.celebrate(at: level.start, level: level, root: board, reduceMotion: false)
        let root = try XCTUnwrap(board.childNode(withName: "completion-coins", recursively: false))
        let originalCoins = Set(root.childNodes.map(ObjectIdentifier.init))
        XCTAssertEqual(originalCoins.count, MazeCompletionCoinEffects.capacity)
        for _ in 0..<30 {
            effects.celebrate(at: level.start, level: level, root: board, reduceMotion: false)
            effects.advance(by: 0.2)
            XCTAssertEqual(board.childNodes.count, 1)
            XCTAssertEqual(Set(root.childNodes.map(ObjectIdentifier.init)), originalCoins)
            root.enumerateChildNodes { node, _ in
                XCTAssertFalse(node.castsShadow)
                XCTAssertFalse(node.hasActions, "The display clock must own the entire effect")
                if let geometry = node.geometry {
                    XCTAssertTrue(prepared.contains(ObjectIdentifier(geometry)))
                }
            }
        }
        let nextBoard = SCNNode()
        effects.celebrate(at: level.start, level: level, root: nextBoard, reduceMotion: false)
        XCTAssertTrue(board.childNodes.isEmpty)
        XCTAssertTrue(nextBoard.childNodes.first === root)
        effects.reset()
        XCTAssertFalse(effects.hasParticles)
        XCTAssertTrue(nextBoard.childNodes.isEmpty)
        XCTAssertTrue(root.childNodes.allSatisfy(\.isHidden))
    }

    func testCoinsFanLiftSpinAndFadeBeforeCompletionAtEveryDisplayRate() throws {
        let effects = MazeCompletionCoinEffects()
        let level = MazeLevel.generate(number: 1, mode: .endless)
        let board = SCNNode()
        let centerCell = GridCell(row: level.height / 2, column: level.width / 2)
        effects.celebrate(at: centerCell, level: level, root: board, reduceMotion: false)
        let root = try XCTUnwrap(board.childNodes.first)
        effects.advance(by: 0.18)
        XCTAssertTrue(root.childNodes.allSatisfy { !$0.isHidden && $0.opacity > 0.9 })
        XCTAssertLessThan(try XCTUnwrap(root.childNodes.first).position.x, -0.5)
        XCTAssertGreaterThan(try XCTUnwrap(root.childNodes.last).position.x, 0.5)
        let center = root.childNodes[MazeCompletionCoinEffects.capacity / 2]
        XCTAssertGreaterThan(center.position.y, 1)
        XCTAssertGreaterThan(abs(center.eulerAngles.y), 1)
        let visibleSize = center.scale.x
        effects.advance(by: 0.32)
        XCTAssertLessThan(center.opacity, 0.3)
        XCTAssertLessThan(center.scale.x, visibleSize)

        for refreshRate in [30.0, 60, 80, 120] {
            effects.celebrate(at: level.start, level: level, root: board, reduceMotion: false)
            let frames = Int(ceil(MazeCompletionCoinEffects.duration * refreshRate))
            for _ in 0..<(frames - 1) { effects.advance(by: 1 / refreshRate) }
            XCTAssertTrue(effects.hasParticles)
            effects.advance(by: 1 / refreshRate)
            XCTAssertFalse(effects.hasParticles)
            XCTAssertTrue(board.childNodes.isEmpty)
        }
    }

    func testCornerBurstOpensInwardAndStaysLowerAtTopEdge() throws {
        let effects = MazeCompletionCoinEffects()
        let level = MazeLevel.generate(number: 1, mode: .endless)
        let board = SCNNode()
        let leftCorner = GridCell(row: 0, column: 0)
        effects.celebrate(at: leftCorner, level: level, root: board, reduceMotion: false)
        effects.advance(by: 0.28)
        let root = try XCTUnwrap(board.childNodes.first)
        let center = root.childNodes[MazeCompletionCoinEffects.capacity / 2]
        XCTAssertGreaterThan(center.position.x, 0.5)
        XCTAssertLessThan(center.position.y, 1)

        let rightCorner = GridCell(row: 0, column: level.width - 1)
        effects.celebrate(at: rightCorner, level: level, root: board, reduceMotion: false)
        effects.advance(by: 0.28)
        XCTAssertLessThan(center.position.x, -0.5)
        XCTAssertLessThan(center.position.y, 1)
    }

    func testReducedMotionShowsOneStationaryCoinAndInvalidIntervalsDoNotAdvance() throws {
        let effects = MazeCompletionCoinEffects()
        let level = MazeLevel.generate(number: 1, mode: .endless)
        let board = SCNNode()
        effects.celebrate(at: level.start, level: level, root: board, reduceMotion: true)
        let root = try XCTUnwrap(board.childNodes.first)
        let visible = root.childNodes.filter { !$0.isHidden }
        XCTAssertEqual(visible.count, 1)
        let coin = try XCTUnwrap(visible.first)
        let position = coin.simdPosition
        let orientation = coin.simdOrientation
        let scale = coin.simdScale
        let opacity = coin.opacity
        for interval in [0.0, -1, .nan, .infinity] { effects.advance(by: interval) }
        XCTAssertEqual(coin.opacity, opacity)
        effects.advance(by: 0.2)
        XCTAssertEqual(coin.simdPosition, position)
        XCTAssertEqual(coin.simdOrientation.vector, orientation.vector)
        XCTAssertEqual(coin.simdScale, scale)
        XCTAssertGreaterThan(coin.opacity, opacity)
        effects.advance(by: 100)
        XCTAssertFalse(effects.hasParticles)
        XCTAssertTrue(board.childNodes.isEmpty)
    }
}
#endif
