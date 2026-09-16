import SwiftUI

struct GameCenterControllerView: UIViewControllerRepresentable {
    let presentation: GameCenterPresentation

    func makeUIViewController(context: Context) -> UIViewController { presentation.controller }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
