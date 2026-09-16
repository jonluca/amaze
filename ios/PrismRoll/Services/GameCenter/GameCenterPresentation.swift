import UIKit

struct GameCenterPresentation: Identifiable {
    enum Kind { case authentication, dashboard }

    let id = UUID()
    let kind: Kind
    let controller: UIViewController
}
