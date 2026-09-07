import UIKit

@MainActor
final class GameplaySwipeHostView: UIView {
    let swipeRecognizer = GameplaySwipeGestureRecognizer()
    private weak var attachedWindow: UIWindow?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { nil }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard attachedWindow !== window else { return }
        attachedWindow?.removeGestureRecognizer(swipeRecognizer)
        attachedWindow = window
        window?.addGestureRecognizer(swipeRecognizer)
    }

    func detach() {
        attachedWindow?.removeGestureRecognizer(swipeRecognizer)
        attachedWindow = nil
        swipeRecognizer.isEnabled = false
        swipeRecognizer.onSwipe = { _, _ in }
    }
}
