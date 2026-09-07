import Foundation

/// Tracks each finger independently, including overlapping short flicks.
struct SwipeSequence<ContactID: Hashable> {
    private var strokes: [ContactID: SwipeStroke] = [:]
    private(set) var hasEmitted = false

    var hasActiveContacts: Bool { !strokes.isEmpty }

    func contains(_ contact: ContactID) -> Bool { strokes[contact] != nil }

    func needsDirection(for contact: ContactID) -> Bool { strokes[contact]?.hasEmitted == false }

    @discardableResult
    mutating func begin(_ contact: ContactID, at point: CGPoint) -> Bool {
        guard strokes[contact] == nil else { return false }
        strokes[contact] = SwipeStroke(origin: point)
        return true
    }

    mutating func direction(for contact: ContactID, at point: CGPoint) -> MoveDirection? {
        guard let direction = strokes[contact]?.direction(at: point) else { return nil }
        hasEmitted = true
        return direction
    }

    mutating func end(_ contact: ContactID, at point: CGPoint) -> MoveDirection? {
        // Some short flicks have only a begin and an end sample.
        let direction = strokes[contact]?.finish(at: point)
        if direction != nil { hasEmitted = true }
        strokes[contact] = nil
        return direction
    }

    mutating func cancel(_ contact: ContactID) {
        strokes[contact] = nil
    }
}
