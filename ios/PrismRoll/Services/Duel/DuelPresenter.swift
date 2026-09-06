import UIKit

@MainActor
enum DuelPresenter {
    static var activeController: UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let root = scenes.first(where: { $0.activationState == .foregroundActive })?
            .windows.first(where: \.isKeyWindow)?.rootViewController else { return nil }
        var top = root
        while let presented = top.presentedViewController, !presented.isBeingDismissed { top = presented }
        return top
    }
}
