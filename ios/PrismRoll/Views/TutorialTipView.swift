import SwiftUI

struct TutorialTipView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let hasMoved: Bool
    let instruction: String?
    let onDismiss: () -> Void

    var body: some View {
        let layout = dynamicTypeSize >= .xxLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
        layout {
            VStack(alignment: .leading, spacing: 4) {
                Text(hasMoved ? "Paint every path" : "Roll to the wall")
                    .font(.subheadline.weight(.semibold))
                Text(instruction ?? (hasMoved
                     ? "Fill every path to finish. Blocked swipes don’t use a move."
                     : "Swipe up, down, left or right. The ball stops at a wall."))
                    .font(.caption).foregroundStyle(Palette.ink.opacity(0.8))
                    .accessibilityIdentifier("playInstructions")
            }
            .fixedSize(horizontal: false, vertical: true)
            if dynamicTypeSize < .xxLarge { Spacer(minLength: 0) }
            Button("Hide tips", action: onDismiss)
                .font(.caption)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("hideTutorial")
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
    }
}
