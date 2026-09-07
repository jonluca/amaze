import SwiftUI

struct PauseView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Your progress is saved", systemImage: "pause.circle")
                    if store.isTimeRush {
                        LabeledContent("Round \(store.run.level.number)", value: "Maze \(store.timeRushMazeNumber) of \(store.timeRushMazeCount)")
                            .accessibilityIdentifier("pausedTimeRushStage")
                    }
                    if store.clock != nil {
                        LabeledContent("Time remaining", value: store.timerText)
                            .accessibilityIdentifier("pausedTimeRemaining")
                    } else if let remaining = store.run.remainingMoves {
                        LabeledContent("Moves remaining", value: "\(remaining)")
                    }
                    Button("Resume game") { dismiss() }
                        .accessibilityIdentifier("resumeGame")
                }
                Section("How to play") {
                    Label("Swipe up, down, left or right to roll to the next wall.", systemImage: "hand.draw")
                    Label("Paint every open path to finish. Blocked swipes don’t count as moves.", systemImage: "drop")
                    Label("Classic has no clock or move limit.", systemImage: "infinity")
                    Label("Time Rush gives you one countdown to solve a series of mazes. The first valid swipe starts the clock; it carries over to each maze.", systemImage: "timer")
                }
                Section("Controls") {
                    Toggle("Direction buttons", isOn: Binding(
                        get: { store.progress.directionButtonsEnabled },
                        set: store.setDirectionButtons
                    ))
                    .accessibilityIdentifier("pausedDirectionButtonsToggle")
                    Text("Turn on named buttons to play with taps or arrow keys. You can still swipe anywhere during play.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Paused")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Resume") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
