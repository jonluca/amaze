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

    mutating func consume(_ samples: [SwipeSample<ContactID>], ending: Bool = false) -> [MoveDirection] {
        var recognized: [(direction: MoveDirection, timestamp: TimeInterval)] = []
        for (contact, history) in Dictionary(grouping: samples, by: \.contact) {
            guard var stroke = strokes[contact] else { continue }
            let original = stroke
            let ordered = history.sorted { $0.timestamp < $1.timestamp }
            var recognition: (direction: MoveDirection, timestamp: TimeInterval)?
            // At lift-off the complete displacement is available. Do not let
            // an earlier coalesced wobble override that final direction.
            if ending, let latest = ordered.last, let direction = stroke.finish(at: latest.point) {
                recognition = (direction, latest.timestamp)
            } else {
                // These samples arrived together: prefer the newest clear
                // direction rather than committing to obsolete initial drift.
                // Older real samples still preserve a flick that returned to
                // its start before UIKit delivered the event.
                for sample in ordered.reversed() {
                    let direction = ending ? stroke.finish(at: sample.point) : stroke.direction(at: sample.point)
                    if let direction {
                        recognition = (direction, sample.timestamp)
                        break
                    }
                }
            }
            if let recognition {
                // Updating the chosen direction must not reorder two clear
                // swipes merely because one finger sent an extra sample.
                // Date it to the first confident evidence for that direction.
                let firstSupportingSample = ordered.first { sample in
                    var probe = original
                    return probe.direction(at: sample.point) == recognition.direction
                }
                recognized.append((recognition.direction, firstSupportingSample?.timestamp ?? recognition.timestamp))
            }
            strokes[contact] = ending ? nil : stroke
        }
        if !recognized.isEmpty { hasEmitted = true }
        return recognized.sorted { $0.timestamp < $1.timestamp }.map(\.direction)
    }

    mutating func cancel(_ contact: ContactID) {
        strokes[contact] = nil
    }
}
