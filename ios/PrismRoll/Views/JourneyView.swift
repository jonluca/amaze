import SwiftUI

struct JourneyView: View {
    @EnvironmentObject private var store: GameStore
    @State private var pageStart: Int?
    let onPlay: () -> Void

    var body: some View {
        ScrollViewReader { scroll in
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
                    browseControls.id("journeyBrowse")
                    ForEach(visibleLevels, id: \.self) { number in
                        levelRow(number)
                    }
                } header: {
                    Label(pathTitle, systemImage: modeIcon)
                } footer: {
                    Text(store.mode == .timed
                         ? "Each round is a series of mazes on one timer. Replay any unlocked round. Completion coins are awarded once per round; unfinished rounds resume where you left off."
                         : "Replay any unlocked maze. Completion coins and bonus-board coins are awarded once; your progress is saved separately for each mode.")
                }
            }
            .listStyle(.insetGrouped)
            .onChange(of: pageStart) { _, _ in scroll.scrollTo("journeyBrowse", anchor: .top) }
            .onChange(of: store.mode) { _, _ in pageStart = nil }
        }
    }

    private var pathTitle: String {
        switch store.mode {
        case .endless: "Your Classic path"
        case .timed: "Your Time Rush rounds"
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
        let count = min(20, Int.max - currentPageStart + 1)
        return (0..<count).map { currentPageStart + $0 }
    }

    private var latestPageStart: Int { ((max(1, store.currentUnlockedLevel) - 1) / 20) * 20 + 1 }
    private var currentPageStart: Int { min(max(1, pageStart ?? latestPageStart), latestPageStart) }

    private var browseControls: some View {
        VStack(spacing: 12) {
            HStack {
                Text("\(store.mode == .timed ? "Rounds" : "Levels") \(currentPageStart)–\(visibleLevels.last ?? currentPageStart)")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .accessibilityIdentifier("journeyRange")
                Spacer()
                Menu("Jump to") {
                    Button(store.mode == .timed ? "First rounds" : "First levels") { pageStart = 1 }
                    Button(store.mode == .timed ? "Latest rounds" : "Latest levels") { pageStart = nil }
                }
                .accessibilityIdentifier("journeyJump")
            }
            HStack {
                Button { pageStart = max(1, currentPageStart - 20) } label: {
                    Label("Earlier", systemImage: "chevron.left")
                }
                .disabled(currentPageStart == 1)
                .accessibilityIdentifier("journeyEarlier")
                Spacer()
                Button { pageStart = currentPageStart + 20 } label: {
                    Label("Later", systemImage: "chevron.right")
                }
                .disabled(currentPageStart >= latestPageStart)
                .accessibilityIdentifier("journeyLater")
            }
            .buttonStyle(.borderless)
        }
    }

    private func levelRow(_ number: Int) -> some View {
        let unlocked = number <= store.currentUnlockedLevel
        let current = number == store.currentUnlockedLevel
        let resumable = number == store.run.level.number && !store.isDaily && !store.isDuel
            && !store.hasEnded && (store.run.moves > 0 || (store.isTimeRush && (store.timeRushMazeNumber > 1 || store.isAwaitingTimeRushMaze)))
        return VStack(alignment: .leading, spacing: 4) {
            Button {
            store.openLevel(number)
            onPlay()
        } label: {
            HStack {
                Label("\(store.mode == .timed ? "Round" : "Level") \(number)", systemImage: current || resumable ? "play.circle.fill" : unlocked ? "arrow.counterclockwise" : "lock")
                Spacer()
                if current || resumable {
                    Text(resumable ? "Continue" : "Play").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .disabled(!unlocked)
        .buttonStyle(.borderless)
        .accessibilityLabel("\(store.mode == .timed ? "Round" : "Level") \(number), \(unlocked ? "unlocked" : "locked")")
        .accessibilityIdentifier("journeyLevel_\(number)")
            if store.progress.canClaimAdBonus(number: number, mode: store.mode) {
                CompletionBonusButton(number: number, mode: store.mode)
            }
        }
    }
}
