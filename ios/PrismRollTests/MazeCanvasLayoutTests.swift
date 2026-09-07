#if canImport(UIKit) && canImport(SceneKit)
import UIKit
import XCTest
@testable import PrismRoll

@MainActor
final class MazeCanvasLayoutTests: XCTestCase {
    func testEntryKeepsViewportFixedAndClipsTranslatedScene() throws {
        let canvas = MazeCanvasView(frame: CGRect(x: 20, y: 80, width: 320, height: 400))
        canvas.layoutIfNeeded()
        let viewportFrame = canvas.frame
        canvas.beginLevelTransition(outgoingImage: UIImage())
        let outgoing = try XCTUnwrap(canvas.sceneView.subviews.compactMap { $0 as? UIImageView }.first)

        XCTAssertEqual(canvas.frame, viewportFrame)
        XCTAssertTrue(canvas.transform.isIdentity)
        XCTAssertTrue(canvas.clipsToBounds)
        XCTAssertEqual(canvas.sceneView.transform.ty, 400)
        XCTAssertEqual(outgoing.convert(outgoing.bounds, to: canvas), canvas.bounds)
        XCTAssertFalse(canvas.sceneView.isUserInteractionEnabled)
        XCTAssertTrue(canvas.sceneView.accessibilityElementsHidden)

        canvas.cancelLevelTransition()
    }

    func testLayoutPreservesPendingSnapshotAndChildTranslationUntilFirstFrame() throws {
        let canvas = MazeCanvasView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        canvas.layoutIfNeeded()
        canvas.beginLevelTransition(outgoingImage: UIImage())
        canvas.setPreparing(true)
        let outgoing = try XCTUnwrap(canvas.sceneView.subviews.compactMap { $0 as? UIImageView }.first)
        var completions = 0

        // Ending the tutorial grows the board before the new maze is prepared.
        canvas.bounds.size = CGSize(width: 320, height: 470)
        canvas.setNeedsLayout()
        canvas.layoutIfNeeded()

        XCTAssertTrue(canvas.transform.isIdentity)
        XCTAssertEqual(canvas.sceneView.bounds.size, canvas.bounds.size)
        XCTAssertEqual(canvas.sceneView.center, CGPoint(x: 160, y: 235))
        XCTAssertEqual(canvas.sceneView.transform.ty, 470)
        XCTAssertTrue(outgoing.superview === canvas.sceneView)
        XCTAssertEqual(outgoing.convert(outgoing.bounds, to: canvas), CGRect(x: 0, y: 0, width: 320, height: 400),
                       "A taller viewport must not recenter the completed board before it exits")
        XCTAssertFalse(canvas.subviews.contains { $0 is UIStackView }, "Preparation must retain the completed board without a spinner")

        canvas.setPreparing(false)
        canvas.revealLevelTransition(reduceMotion: false) { completions += 1 }
        XCTAssertEqual(completions, 0)
        canvas.finishLevelTransition()
        XCTAssertEqual(completions, 1)
        XCTAssertTrue(canvas.sceneView.transform.isIdentity)
        XCTAssertNil(outgoing.superview)
        XCTAssertTrue(canvas.transform.isIdentity)
    }

    func testInitialPreparationUsesViewportSpinnerAndTeardownDiscardsEntryCallback() {
        let canvas = MazeCanvasView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        canvas.layoutIfNeeded()
        canvas.setPreparing(true)
        XCTAssertTrue(canvas.subviews.contains { $0 is UIStackView })
        XCTAssertTrue(canvas.sceneView.transform.isIdentity)
        canvas.setPreparing(false)
        canvas.beginLevelTransition(outgoingImage: UIImage())
        var completions = 0
        canvas.revealLevelTransition(reduceMotion: false) { completions += 1 }
        canvas.cancelLevelTransition()
        canvas.finishLevelTransition()

        XCTAssertEqual(completions, 0)
        XCTAssertTrue(canvas.transform.isIdentity)
        XCTAssertTrue(canvas.sceneView.transform.isIdentity)
        XCTAssertFalse(canvas.sceneView.subviews.contains { $0 is UIImageView })
        XCTAssertFalse(canvas.subviews.contains { $0 is UIStackView })
    }
}
#endif
