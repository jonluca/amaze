import SwiftUI

struct ModePicker: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        Picker("Game mode", selection: Binding(get: { store.mode }, set: store.switchMode)) {
            Text("Classic").tag(GameMode.endless).accessibilityIdentifier("mode_endless")
            Text("Time Rush").tag(GameMode.timed).accessibilityIdentifier("mode_timed")
            Text("Limited Moves").tag(GameMode.challenge).accessibilityIdentifier("mode_challenge")
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("modePicker")
    }
}
