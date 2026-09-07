import UIKit

/// A window observer, not a hit-test overlay: taps reach their original targets.
@MainActor
final class GameplaySwipeGestureRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    var onSwipe: (MoveDirection, UUID) -> Void = { _, _ in }
    private var sessionID = UUID()
    private var strokeSessionID: UUID?
    private var sequence = SwipeSequence<ObjectIdentifier>()

    init() {
        super.init(target: nil, action: nil)
        delegate = self
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
    }

    func configure(enabled: Bool, sessionID: UUID, onSwipe: @escaping (MoveDirection, UUID) -> Void) {
        if self.sessionID != sessionID || !enabled {
            // Changing session cancels a finger already down during a reset/modal.
            isEnabled = false
            clearSequence()
            self.sessionID = sessionID
        }
        self.onSwipe = onSwipe
        isEnabled = enabled
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard isEnabled else { return }
        for touch in touches.sorted(by: { $0.timestamp < $1.timestamp }) {
            guard sequence.begin(ObjectIdentifier(touch), at: touch.location(in: view)) else {
                // An extra finger must not cancel a stroke already in progress.
                ignore(touch, for: event)
                continue
            }
            strokeSessionID = sessionID
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        consumeSamples(from: touches, event: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard touches.contains(where: { sequence.contains(ObjectIdentifier($0)) }) else { return }
        consumeSamples(from: touches, event: event)
        for touch in touches.sorted(by: { $0.timestamp < $1.timestamp }) {
            emit(sequence.end(ObjectIdentifier(touch), at: touch.location(in: view)))
        }
        guard isEnabled, strokeSessionID == sessionID, !sequence.hasActiveContacts else { return }
        state = sequence.hasEmitted ? .ended : .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        guard touches.contains(where: { sequence.contains(ObjectIdentifier($0)) }) else { return }
        for touch in touches { sequence.cancel(ObjectIdentifier(touch)) }
        guard !sequence.hasActiveContacts else { return }
        state = sequence.hasEmitted ? .cancelled : .failed
    }

    override func reset() {
        super.reset()
        clearSequence()
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let window = view as? UIWindow else { return false }
        return GameplayTouchPolicy.allowsSwipe(startingIn: touch.view, window: window)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }

    private func consumeSamples(from touches: Set<UITouch>, event: UIEvent) {
        let expectedSessionID = strokeSessionID
        var samples: [(contact: ObjectIdentifier, point: CGPoint, timestamp: TimeInterval)] = []
        for touch in touches {
            let contact = ObjectIdentifier(touch)
            guard sequence.needsDirection(for: contact) else { continue }
            // Use real recorded samples, never predicted positions that may reverse.
            for sample in event.coalescedTouches(for: touch) ?? [] {
                samples.append((contact, sample.location(in: view), sample.timestamp))
            }
            // Include lift-off even if UIKit omitted it from the coalesced samples.
            samples.append((contact, touch.location(in: view), touch.timestamp))
        }
        for sample in samples.sorted(by: { $0.timestamp < $1.timestamp }) {
            guard isEnabled, strokeSessionID == expectedSessionID, strokeSessionID == sessionID else { return }
            emit(sequence.direction(for: sample.contact, at: sample.point))
        }
    }

    private func emit(_ direction: MoveDirection?) {
        guard isEnabled, strokeSessionID == sessionID, let direction,
              let strokeSessionID else { return }
        state = state == .possible ? .began : .changed
        onSwipe(direction, strokeSessionID)
    }

    private func clearSequence() {
        sequence = SwipeSequence()
        strokeSessionID = nil
    }
}
