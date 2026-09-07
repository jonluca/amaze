#if canImport(UIKit)
import UIKit
import XCTest
@testable import PrismRoll

@MainActor
final class MazeLevelTransitionTests: XCTestCase {
    func testOutgoingBoardStaysVisibleWhileReplacementStartsBelowViewport() throws {
        let parent = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        let view = UIView(frame: parent.bounds)
        parent.addSubview(view)
        let transition = MazeLevelTransition(view: view)
        transition.begin(outgoingImage: UIImage())

        let outgoing = try XCTUnwrap(view.subviews.first as? UIImageView)
        XCTAssertEqual(view.convert(view.bounds, to: parent).minY, 400)
        XCTAssertEqual(outgoing.convert(outgoing.bounds, to: parent), parent.bounds)
        XCTAssertFalse(outgoing.isUserInteractionEnabled)
        XCTAssertTrue(outgoing.accessibilityElementsHidden)
        XCTAssertTrue(transition.isTransitioning)

        transition.cancel()
        XCTAssertTrue(view.transform.isIdentity)
        XCTAssertTrue(view.subviews.isEmpty)
    }

    func testReduceMotionRevealsDirectlyAndCompletesExactlyOnce() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        let transition = MazeLevelTransition(view: view)
        var completions = 0
        transition.begin(outgoingImage: UIImage())
        transition.reveal(reduceMotion: true) { completions += 1 }
        transition.finish()
        transition.cancel()

        XCTAssertEqual(completions, 1)
        XCTAssertFalse(transition.isTransitioning)
        XCTAssertTrue(view.transform.isIdentity)
        XCTAssertTrue(view.subviews.isEmpty)
    }

    func testCancellationDoesNotPublishReadinessForDiscardedReveal() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        let transition = MazeLevelTransition(view: view)
        var completions = 0
        transition.begin(outgoingImage: UIImage())
        transition.reveal(reduceMotion: false) { completions += 1 }
        transition.cancel()
        transition.finish()

        XCTAssertEqual(completions, 0)
        XCTAssertFalse(transition.isTransitioning)
        XCTAssertTrue(view.transform.isIdentity)
        XCTAssertTrue(view.subviews.isEmpty)
    }

    func testReplacementDiscardsOldCompletionAndFinishesNewOwnerOnce() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        let transition = MazeLevelTransition(view: view)
        var discardedCompletions = 0
        var currentCompletions = 0
        transition.begin(outgoingImage: UIImage())
        transition.reveal(reduceMotion: false) { discardedCompletions += 1 }
        transition.begin(outgoingImage: UIImage())
        transition.reveal(reduceMotion: false) { currentCompletions += 1 }
        transition.finish()
        transition.finish()

        XCTAssertEqual(discardedCompletions, 0)
        XCTAssertEqual(currentCompletions, 1)
        XCTAssertTrue(view.transform.isIdentity)
        XCTAssertTrue(view.subviews.isEmpty)
    }

    func testResizeDuringRevealSettlesAndPublishesCurrentReadinessOnce() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        let transition = MazeLevelTransition(view: view)
        var completions = 0
        transition.begin(outgoingImage: UIImage())
        transition.reveal(reduceMotion: false) { completions += 1 }
        view.bounds.size = CGSize(width: 400, height: 320)
        transition.layoutDidChange()
        transition.layoutDidChange()
        transition.finish()

        XCTAssertEqual(completions, 1)
        XCTAssertTrue(view.transform.isIdentity)
        XCTAssertTrue(view.subviews.isEmpty)
    }

    func testResizeDuringPreparationPreservesSlideAndWaitsForReplacementFrame() throws {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        let transition = MazeLevelTransition(view: view)
        var completions = 0
        transition.begin(outgoingImage: UIImage())
        view.bounds.size = CGSize(width: 400, height: 320)
        transition.layoutDidChange()
        XCTAssertEqual(completions, 0)
        XCTAssertTrue(transition.isTransitioning)
        XCTAssertEqual(view.transform.ty, 320)
        let outgoing = try XCTUnwrap(view.subviews.first as? UIImageView)
        XCTAssertEqual(outgoing.bounds.size, view.bounds.size)
        XCTAssertEqual(outgoing.transform.ty, -320)
        XCTAssertEqual(outgoing.contentMode, .scaleAspectFit)

        transition.reveal(reduceMotion: false) { completions += 1 }
        XCTAssertEqual(completions, 0, "A prepared frame still waits for the vertical reveal")
        transition.finish()
        XCTAssertEqual(completions, 1)
        XCTAssertTrue(view.transform.isIdentity)
        XCTAssertTrue(view.subviews.isEmpty)
    }

    func testPreparationHeightGrowthKeepsOldBoardTopAnchoredAndHonorsReduceMotion() throws {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        let transition = MazeLevelTransition(view: view)
        var completions = 0
        transition.begin(outgoingImage: UIImage())
        view.bounds.size = CGSize(width: 320, height: 470)
        transition.layoutDidChange()
        let outgoing = try XCTUnwrap(view.subviews.first as? UIImageView)
        XCTAssertEqual(outgoing.bounds.size, CGSize(width: 320, height: 400))
        XCTAssertEqual(outgoing.frame.minY + view.transform.ty, 0)
        XCTAssertEqual(outgoing.transform.ty, -470)
        transition.reveal(reduceMotion: true) { completions += 1 }
        transition.finish()

        XCTAssertEqual(completions, 1)
        XCTAssertFalse(transition.isTransitioning)
        XCTAssertTrue(view.transform.isIdentity)
        XCTAssertTrue(view.subviews.isEmpty)
    }

    func testPreparationWidthChangePreservesSnapshotAspectAndFitsShorterViewport() throws {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        let transition = MazeLevelTransition(view: view)
        transition.begin(outgoingImage: UIImage())
        let outgoing = try XCTUnwrap(view.subviews.first as? UIImageView)

        view.bounds.size = CGSize(width: 480, height: 700)
        transition.layoutDidChange()
        XCTAssertEqual(outgoing.bounds.size, CGSize(width: 480, height: 600))
        XCTAssertEqual(outgoing.frame.minY + view.transform.ty, 0)
        view.bounds.size = CGSize(width: 480, height: 300)
        transition.layoutDidChange()
        XCTAssertEqual(outgoing.bounds.height, 300)
        XCTAssertEqual(outgoing.frame.minY + view.transform.ty, 0)
        // A later height increase must recover the original aspect ratio,
        // not stretch the previously constrained 300-point snapshot viewport.
        view.bounds.size = CGSize(width: 480, height: 700)
        transition.layoutDidChange()
        XCTAssertEqual(outgoing.bounds.height, 600)
        transition.cancel()
    }

    func testCompletionCanStartAnotherTransitionWithoutOldCleanupRemovingIt() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        let transition = MazeLevelTransition(view: view)
        transition.begin(outgoingImage: UIImage())
        transition.reveal(reduceMotion: false) { transition.begin(outgoingImage: UIImage()) }
        transition.finish()

        XCTAssertTrue(transition.isTransitioning)
        XCTAssertEqual(view.subviews.count, 1)
        XCTAssertEqual(view.transform.ty, 400)
        transition.cancel()
    }
}
#endif
