import Foundation

/// One real touch observation; timestamps preserve ordering between fingers.
struct SwipeSample<ContactID: Hashable> {
    let contact: ContactID
    let point: CGPoint
    let timestamp: TimeInterval
}
