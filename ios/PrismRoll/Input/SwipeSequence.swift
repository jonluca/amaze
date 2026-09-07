import Foundation

/// Allows the next stroke to begin before an already recognized finger lifts.
struct SwipeSequence<ContactID: Hashable> {
    private var strokes: [ContactID: SwipeStroke] = [:]
    private(set) var hasEmitted = false

    var hasActiveContacts: Bool { !strokes.isEmpty }

    func contains(_ contact: ContactID) -> Bool { strokes[contact] != nil }

    func needsDirection(for contact: ContactID) -> Bool { strokes[contact]?.hasEmitted == false }

    @discardableResult
    mutating func begin(_ contact: ContactID, at point: CGPoint) -> Bool {
        guard strokes[contact] == nil, strokes.values.allSatisfy(\.hasEmitted) else { return false }
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
        let direction = direction(for: contact, at: point)
        strokes[contact] = nil
        return direction
    }

    mutating func cancel(_ contact: ContactID) {
        strokes[contact] = nil
    }
}
