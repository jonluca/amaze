import SwiftUI
import UIKit

struct ChallengeShareSheet: UIViewControllerRepresentable {
    let challenge: SharedChallenge

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let text = challenge.senderMoves.map { "I painted \(challenge.title) in \($0) moves in Prism Roll. Can you match my score?" }
            ?? "Try \(challenge.title) in Prism Roll. Paint every path!"
        let renderer = ImageRenderer(content: ChallengeShareCard(challenge: challenge))
        renderer.scale = 1
        var items: [Any] = [text, challenge.url]
        if let image = renderer.uiImage { items.insert(image, at: 1) }
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            guard completed else { return }
            DispatchQueue.main.async {
                AnalyticsService.shared.record("share", parameters: ["content_type": "maze_challenge", "method": "system_sheet"])
            }
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
