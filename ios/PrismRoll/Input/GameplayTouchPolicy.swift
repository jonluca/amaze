import UIKit

@MainActor
enum GameplayTouchPolicy {
    static func allowsSwipe(startingIn view: UIView?, window: UIWindow, gameplayHost: UIView? = nil) -> Bool {
        guard let view, view.window === window else { return false }
        // A presented gameplay screen owns its own observer. Observers behind a
        // sheet, or behind a share/ad sheet above that gameplay, remain blocked.
        if var presented = window.rootViewController?.presentedViewController {
            while let next = presented.presentedViewController { presented = next }
            guard let gameplayHost, let presentationView = presented.viewIfLoaded,
                  gameplayHost.isDescendant(of: presentationView), view.isDescendant(of: presentationView) else { return false }
        }
        var current: UIView? = view
        while let candidate = current {
            // Observe gameplay space only. Native buttons, navigation, scrolling,
            // text entry and accessibility controls retain their own gestures.
            if candidate is UIControl || candidate is UINavigationBar || candidate is UITabBar ||
                candidate is UIScrollView || candidate is UITextInput ||
                candidate.accessibilityTraits.contains(.button) ||
                candidate.accessibilityTraits.contains(.link) ||
                candidate.accessibilityTraits.contains(.adjustable) { return false }
            if candidate === window { return true }
            current = candidate.superview
        }
        return false
    }
}
