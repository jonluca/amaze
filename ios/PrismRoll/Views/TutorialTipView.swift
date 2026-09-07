import SwiftUI

struct TutorialTipView: View {
    let hasMoved: Bool
    let instruction: String?
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(hasMoved ? "Paint every path" : "Roll to the wall")
                    .font(.subheadline.weight(.semibold))
                Text(instruction ?? (hasMoved
                     ? "Fill every path to finish. Blocked swipes don’t use a move."
                     : "Swipe up, down, left or right. The ball stops at a wall."))
                    .font(.caption).foregroundStyle(Palette.secondary)
                    .accessibilityIdentifier("playInstructions")
            }
            Spacer(minLength: 0)
            Button("Hide tips", action: onDismiss)
                .font(.caption)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("hideTutorial")
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
    }
}
