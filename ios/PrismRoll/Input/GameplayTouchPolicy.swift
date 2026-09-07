import UIKit

@MainActor
enum GameplayTouchPolicy {
    static func allowsSwipe(startingIn view: UIView?, window: UIWindow) -> Bool {
        guard let view, view.window === window else { return false }
        // Keep dismissing sheets/ads protected until UIKit removes the presentation.
        guard window.rootViewController?.presentedViewController == nil else { return false }
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
