import UIKit

/// A window observer, not a hit-test overlay: taps reach their original targets.
@MainActor
final class GameplaySwipeGestureRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    var onSwipe: (MoveDirection, UUID) -> Void = { _, _ in }
    private var sessionID = UUID()
    private var strokeSessionID: UUID?
    private var stroke: SwipeStroke?
    private weak var trackedTouch: UITouch?

    init() {
        super.init(target: nil, action: nil)
        delegate = self
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
    }

    func configure(enabled: Bool, sessionID: UUID, onSwipe: @escaping (MoveDirection, UUID) -> Void) {
        if self.sessionID != sessionID {
            // Changing session cancels a finger already down during a reset/modal.
            isEnabled = false
            self.sessionID = sessionID
        }
        self.onSwipe = onSwipe
        isEnabled = enabled
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard trackedTouch == nil, touches.count == 1, let touch = touches.first else {
            state = stroke?.hasEmitted == true ? .cancelled : .failed
            return
        }
        trackedTouch = touch
        strokeSessionID = sessionID
        stroke = SwipeStroke(origin: touch.location(in: view))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = trackedTouch, touches.contains(touch) else { return }
        consume(touch.location(in: view))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = trackedTouch, touches.contains(touch) else { return }
        // A very short flick may arrive as an end point with no intervening sample.
        consume(touch.location(in: view))
        state = stroke?.hasEmitted == true ? .ended : .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = stroke?.hasEmitted == true ? .cancelled : .failed
    }

    override func reset() {
        super.reset()
        trackedTouch = nil
        stroke = nil
        strokeSessionID = nil
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let window = view as? UIWindow else { return false }
        return GameplayTouchPolicy.allowsSwipe(startingIn: touch.view, window: window)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }

    private func consume(_ point: CGPoint) {
        guard isEnabled, strokeSessionID == sessionID, let direction = stroke?.direction(at: point),
              let strokeSessionID else { return }
        state = .began
        onSwipe(direction, strokeSessionID)
    }
}
