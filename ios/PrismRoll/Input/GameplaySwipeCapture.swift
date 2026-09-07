import SwiftUI

@MainActor
struct GameplaySwipeCapture: UIViewRepresentable {
    let enabled: Bool
    let sessionID: UUID
    let onSwipe: (MoveDirection, UUID) -> Void

    func makeUIView(context: Context) -> GameplaySwipeHostView {
        let view = GameplaySwipeHostView()
        updateUIView(view, context: context)
        return view
    }

    func updateUIView(_ view: GameplaySwipeHostView, context: Context) {
        view.swipeRecognizer.configure(enabled: enabled, sessionID: sessionID, onSwipe: onSwipe)
    }

    static func dismantleUIView(_ view: GameplaySwipeHostView, coordinator: ()) { view.detach() }
}
