#if canImport(UIKit)
import UIKit
import XCTest
@testable import PrismRoll

@MainActor
final class GameplayTouchTests: XCTestCase {
    func testDirectionEmitsWithClearAxisLeadBeforeLiftAndOnlyOncePerStroke() {
        for (point, expected) in [(CGPoint(x: 9, y: 1), MoveDirection.right),
                                  (CGPoint(x: -9, y: 1), .left),
                                  (CGPoint(x: 1, y: 9), .down),
                                  (CGPoint(x: 1, y: -9), .up)] {
            var stroke = SwipeStroke(origin: .zero)
            XCTAssertEqual(stroke.direction(at: point), expected)
            XCTAssertTrue(stroke.hasEmitted)
            XCTAssertNil(stroke.direction(at: CGPoint(x: point.x * 10, y: point.y * 10)))
            XCTAssertNil(stroke.direction(at: CGPoint(x: -point.x, y: -point.y)))
        }
    }

    func testTapJitterAndAmbiguousDiagonalDoNotMoveUntilDirectionIsClear() {
        var stroke = SwipeStroke(origin: CGPoint(x: 100, y: 200))
        for offset: CGFloat in [0, 2, 5, 6, 7.99] {
            XCTAssertNil(stroke.direction(at: CGPoint(x: 100 + offset, y: 200)))
        }
        XCTAssertNil(stroke.direction(at: CGPoint(x: 120, y: 220)))
        XCTAssertFalse(stroke.hasEmitted)
        XCTAssertNil(stroke.direction(at: CGPoint(x: 124, y: 220)))
        XCTAssertEqual(stroke.direction(at: CGPoint(x: 128, y: 220)), .right)
    }

    func testObserverDoesNotDelayCancelOrPreventNativeTapRecognizers() {
        let recognizer = GameplaySwipeGestureRecognizer()
        let tap = UITapGestureRecognizer()
        XCTAssertFalse(recognizer.cancelsTouchesInView)
        XCTAssertFalse(recognizer.delaysTouchesBegan)
        XCTAssertFalse(recognizer.delaysTouchesEnded)
        XCTAssertFalse(recognizer.canPrevent(tap))
        XCTAssertFalse(recognizer.canBePrevented(by: tap))
        XCTAssertTrue(recognizer.gestureRecognizer(recognizer, shouldRecognizeSimultaneouslyWith: tap))
    }

    func testTouchPolicyAcceptsEmptyGameplayButExcludesControlDescendantsAndScrolling() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let content = UIView(frame: window.bounds)
        window.addSubview(content)
        XCTAssertTrue(GameplayTouchPolicy.allowsSwipe(startingIn: content, window: window))
        for excluded in [UIButton(), UISegmentedControl(items: ["One", "Two"]), UISlider(),
                         UINavigationBar(), UITabBar(), UIScrollView(), UITextField()] as [UIView] {
            content.addSubview(excluded)
            let label = UILabel()
            excluded.addSubview(label)
            XCTAssertFalse(GameplayTouchPolicy.allowsSwipe(startingIn: excluded, window: window))
            XCTAssertFalse(GameplayTouchPolicy.allowsSwipe(startingIn: label, window: window))
        }
        let accessibleButton = UIView()
        accessibleButton.accessibilityTraits = .button
        content.addSubview(accessibleButton)
        XCTAssertFalse(GameplayTouchPolicy.allowsSwipe(startingIn: accessibleButton, window: window))
        XCTAssertFalse(GameplayTouchPolicy.allowsSwipe(startingIn: UIView(), window: window))
        XCTAssertFalse(GameplayTouchPolicy.allowsSwipe(startingIn: nil, window: window))
    }

    func testWindowAttachmentDoesNotDuplicateRecognizerAndDetachRemovesIt() {
        let first = UIWindow()
        let second = UIWindow()
        let host = GameplaySwipeHostView()
        first.addSubview(host)
        XCTAssertEqual(first.gestureRecognizers?.filter { $0 === host.swipeRecognizer }.count, 1)
        host.didMoveToWindow()
        XCTAssertEqual(first.gestureRecognizers?.filter { $0 === host.swipeRecognizer }.count, 1)
        XCTAssertFalse(host.isUserInteractionEnabled)
        second.addSubview(host)
        XCTAssertFalse(first.gestureRecognizers?.contains { $0 === host.swipeRecognizer } ?? false)
        XCTAssertEqual(second.gestureRecognizers?.filter { $0 === host.swipeRecognizer }.count, 1)
        host.detach()
        XCTAssertFalse(second.gestureRecognizers?.contains { $0 === host.swipeRecognizer } ?? false)
    }
}
#endif
