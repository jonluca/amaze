import SwiftUI

struct JourneyView: View {
    @EnvironmentObject private var store: GameStore
    let onPlay: () -> Void

    var body: some View {
        List {
            Section {
                Text("Keep your color moving.")
                    .font(.headline).accessibilityIdentifier("journeyHeading")
                LabeledContent("Levels painted", value: store.progress.completedLevels.formatted())
                LabeledContent("Coin balance", value: store.progress.points.formatted())
            }
            Section("Game mode") {
                ModePicker()
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
            }
            Section {
                ForEach(visibleLevels, id: \.self) { number in
                    levelRow(number)
                }
            } header: {
                Label(pathTitle, systemImage: modeIcon)
            } footer: {
                Text("Replay any unlocked maze. Completion coins and bonus-board coins are awarded once; your progress is saved separately for each mode.")
            }
        }
        .listStyle(.insetGrouped)
    }

    private var pathTitle: String {
        switch store.mode {
        case .endless: "Your Classic path"
        case .timed: "Your Time Rush runs"
        case .challenge: "Your Limited Move mazes"
        }
    }

    private var modeIcon: String {
        switch store.mode {
        case .endless: "infinity"
        case .timed: "timer"
        case .challenge: "scope"
        }
    }

    private var visibleLevels: [Int] {
        let frontier = max(1, store.currentUnlockedLevel)
        let start = max(1, frontier - 5)
        let count = min(18, Int.max - start + 1)
        return (0..<count).map { start + $0 }
    }

    private func levelRow(_ number: Int) -> some View {
        let unlocked = number <= store.currentUnlockedLevel
        let current = number == store.currentUnlockedLevel
        return Button {
            store.openLevel(number)
            onPlay()
        } label: {
            HStack {
                Label("Level \(number)", systemImage: current ? "play.circle.fill" : unlocked ? "arrow.counterclockwise" : "lock")
                Spacer()
                if current {
                    Text("Continue").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .disabled(!unlocked)
        .accessibilityLabel("Level \(number), \(unlocked ? "unlocked" : "locked")")
        .accessibilityIdentifier("journeyLevel_\(number)")
    }
}
