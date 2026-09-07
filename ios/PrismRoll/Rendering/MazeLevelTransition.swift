import UIKit

/// Owns the two-board slide without rebuilding the persistent SceneKit view.
@MainActor
final class MazeLevelTransition {
    private enum Phase {
        case idle
        case preparing(image: UIImageView, size: CGSize, aspectRatio: CGFloat)
        case revealing(image: UIImageView, size: CGSize, animator: UIViewPropertyAnimator,
                       token: UUID, completion: () -> Void)
    }

    private weak var view: UIView?
    private var phase = Phase.idle

    init(view: UIView) { self.view = view }

    var isTransitioning: Bool {
        if case .idle = phase { return false }
        return true
    }

    func begin(outgoingImage: UIImage) {
        cancel()
        guard let view, view.bounds.width > 0, view.bounds.height > 0 else { return }
        let outgoing = UIImageView(image: outgoingImage)
        outgoing.contentMode = .scaleAspectFit
        outgoing.isUserInteractionEnabled = false
        outgoing.isAccessibilityElement = false
        outgoing.accessibilityElementsHidden = true
        view.clipsToBounds = false
        view.addSubview(outgoing)
        let imageSize = outgoingImage.size
        let aspectRatio = imageSize.width > 0 && imageSize.height > 0
            ? imageSize.height / imageSize.width : view.bounds.height / view.bounds.width
        positionForEntry(outgoing, in: view, aspectRatio: aspectRatio)
        phase = .preparing(image: outgoing, size: view.bounds.size, aspectRatio: aspectRatio)
    }

    func reveal(reduceMotion: Bool, completion: @escaping () -> Void) {
        switch phase {
        case .idle:
            completion()
        case .revealing:
            // Multiple first-frame callbacks cannot replace a pending owner.
            return
        case let .preparing(image, size, _):
            guard !reduceMotion, UIView.areAnimationsEnabled else {
                cancel()
                completion()
                return
            }
            let token = UUID()
            let animator = UIViewPropertyAnimator(duration: 0.30, curve: .easeInOut)
            phase = .revealing(image: image, size: size, animator: animator,
                               token: token, completion: completion)
            animator.addAnimations { [weak view] in view?.transform = .identity }
            animator.addCompletion { [weak self] _ in
                guard let self, case let .revealing(_, _, _, currentToken, _) = self.phase,
                      token == currentToken else { return }
                self.finish()
            }
            animator.startAnimation()
        }
    }

    func layoutDidChange() {
        guard let view else { cancel(); return }
        switch phase {
        case .idle: return
        case let .preparing(image, size, aspectRatio):
            guard view.bounds.size != size else { return }
            guard view.bounds.width > 0, view.bounds.height > 0 else { cancel(); return }
            // Tutorial removal and other level-specific controls can resize the
            // board before its next frame. Keep the old image top-anchored at
            // its fitted height so a taller viewport cannot shift it downward.
            positionForEntry(image, in: view, aspectRatio: aspectRatio)
            phase = .preparing(image: image, size: view.bounds.size, aspectRatio: aspectRatio)
        case let .revealing(_, size, _, _, _):
            guard view.bounds.size != size else { return }
            // Once motion has started, settle instead of changing its trajectory.
            finish()
        }
    }

    func finish() {
        let completion: (() -> Void)?
        if case let .revealing(_, _, _, _, callback) = phase { completion = callback }
        else { completion = nil }
        cancel()
        completion?()
    }

    func cancel() {
        let previous = phase
        // Invalidate ownership before stopping UIKit or invoking client code.
        phase = .idle
        switch previous {
        case .idle: break
        case let .preparing(image, _, _): image.removeFromSuperview()
        case let .revealing(image, _, animator, _, _):
            if animator.state == .active { animator.stopAnimation(true) }
            image.removeFromSuperview()
        }
        UIView.performWithoutAnimation { view?.transform = .identity }
    }

    private func positionForEntry(_ outgoing: UIImageView, in view: UIView, aspectRatio: CGFloat) {
        // The inverse child translation keeps the old board in its original
        // screen position while the replacement renders below the viewport.
        UIView.performWithoutAnimation {
            view.transform = .identity
            outgoing.transform = .identity
            let height = min(view.bounds.height, view.bounds.width * aspectRatio)
            outgoing.frame = CGRect(origin: view.bounds.origin,
                                    size: CGSize(width: view.bounds.width, height: height))
            view.transform = CGAffineTransform(translationX: 0, y: view.bounds.height)
            outgoing.transform = CGAffineTransform(translationX: 0, y: -view.bounds.height)
        }
    }
}
