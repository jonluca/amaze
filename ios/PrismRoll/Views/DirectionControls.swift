import SwiftUI

struct DirectionControls: View {
    let enabled: Bool
    let sessionID: UUID
    let onMove: (MoveDirection, UUID) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                directionButton(.up)
                directionButton(.down)
                directionButton(.left)
                directionButton(.right)
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    directionButton(.up)
                    directionButton(.down)
                }
                HStack(spacing: 12) {
                    directionButton(.left)
                    directionButton(.right)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Direction controls")
        // A new input session also retires any button press still in flight.
        .id(sessionID)
    }

    private func directionButton(_ direction: MoveDirection) -> some View {
        let title = direction.rawValue.capitalized
        return Button {
            guard enabled else { return }
            onMove(direction, sessionID)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "arrow.\(direction.rawValue)").font(.body.weight(.semibold))
                Text(title).font(.caption.weight(.semibold))
            }
            .frame(minWidth: 52, minHeight: 52)
        }
        .buttonStyle(.bordered)
        .buttonRepeatBehavior(.disabled)
        .disabled(!enabled)
        .keyboardShortcut(key(for: direction), modifiers: [])
        .accessibilityLabel("Roll \(direction.rawValue)")
        .accessibilityInputLabels([Text(title), Text("Roll \(direction.rawValue)")])
        .accessibilityHint("Roll until a wall stops the ball.")
        .accessibilityIdentifier("direction_\(direction.rawValue)")
    }

    private func key(for direction: MoveDirection) -> KeyEquivalent {
        switch direction {
        case .up: .upArrow
        case .down: .downArrow
        case .left: .leftArrow
        case .right: .rightArrow
        }
    }
}
