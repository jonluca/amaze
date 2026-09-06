import SwiftUI

struct ModePicker: View {
    @EnvironmentObject private var store: GameStore
    var body: some View {
        HStack(spacing: 5) {
            modeButton(.endless, icon: "infinity", title: "Classic")
            modeButton(.timed, icon: "timer", title: "Time Rush")
            modeButton(.challenge, icon: "scope", title: "Limited Moves")
        }.padding(5).background(Palette.paper, in: RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(Palette.line.opacity(0.8), lineWidth: 1))
    }
    private func modeButton(_ mode: GameMode, icon: String, title: String) -> some View {
        Button { store.switchMode(mode) } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 16, weight: .semibold))
                Text(title).font(.system(size: 10, weight: .bold, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.8)
            }.frame(maxWidth: .infinity).padding(.vertical, 11)
                .foregroundStyle(store.mode == mode && !store.isDaily ? Palette.ink : Palette.secondary)
                .background(store.mode == mode && !store.isDaily ? Palette.violet.opacity(0.20) : .clear, in: RoundedRectangle(cornerRadius: 13))
        }.accessibilityIdentifier("mode_\(mode.rawValue)")
            .accessibilityAddTraits(store.mode == mode ? .isSelected : [])
    }
}
