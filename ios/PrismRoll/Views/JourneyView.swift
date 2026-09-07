import SwiftUI

struct JourneyView: View {
    @EnvironmentObject private var store: GameStore
    @State private var pageStart: Int?
    @State private var jumpOpen = false
    @State private var jumpNumber = ""
    let onPlay: () -> Void

    var body: some View {
        ScrollViewReader { scroll in
            List {
                Section {
                    Text("Every level. Your personal best.")
                        .font(.headline).accessibilityIdentifier("journeyHeading")
                    LabeledContent(store.mode == .timed ? "Rounds solved" : "Levels solved",
                                   value: store.progress.completedLevelCount(in: store.mode).formatted())
                    HStack(spacing: 20) {
                        Label("Solved", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Palette.cyan)
                        Label("Optimal", systemImage: "crown.fill")
                            .foregroundStyle(Palette.gold)
                    }
                    .font(.subheadline)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Checkmark: solved. Crown: solved in the fewest possible moves.")
                    .accessibilityIdentifier("journeyLegend")
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
                         ? "A crown means you have solved all five mazes optimally and completed the round. Replay any unlocked round; unfinished rounds resume where you left off. Completion coins are awarded once per round."
                         : "A crown marks the fewest possible moves. Replay any unlocked level to improve your best. Completion and bonus-board coins are awarded once; progress is saved separately for each mode.")
                }
            }
            .listStyle(.insetGrouped)
            .onChange(of: pageStart) { _, _ in scroll.scrollTo("journeyBrowse", anchor: .top) }
            .onChange(of: store.mode) { _, _ in pageStart = nil }
        }
        .alert(store.mode == .timed ? "Go to round" : "Go to level", isPresented: $jumpOpen) {
            TextField(store.mode == .timed ? "Round number" : "Level number", text: $jumpNumber)
                .keyboardType(.numberPad)
                .accessibilityIdentifier("journeyJumpNumber")
            Button("Go") {
                guard let number = enteredLevelNumber else { return }
                pageStart = number
            }
            .disabled(enteredLevelNumber == nil)
            .accessibilityIdentifier("journeyJumpGo")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter any positive number. Solve earlier \(store.mode == .timed ? "rounds" : "levels") to unlock later ones.")
        }
    }

    private var pathTitle: String {
        switch store.mode {
        case .endless: "Classic levels"
        case .timed: "Time Rush rounds"
        case .challenge: "Limited Move levels"
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
    private var currentPageStart: Int { max(1, pageStart ?? latestPageStart) }
    private var enteredLevelNumber: Int? {
        guard let number = Int(jumpNumber.trimmingCharacters(in: .whitespacesAndNewlines)), number > 0 else { return nil }
        return number
    }

    private var browseControls: some View {
        VStack(spacing: 12) {
            HStack {
                Text("\(store.mode == .timed ? "Rounds" : "Levels") \(currentPageStart)–\(visibleLevels.last ?? currentPageStart)")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .accessibilityIdentifier("journeyRange")
                Spacer()
                Menu("Jump to") {
                    Button(store.mode == .timed ? "First rounds" : "First levels") { pageStart = 1 }
                    Button(store.mode == .timed ? "Current round" : "Current level") { pageStart = nil }
                    Button(store.mode == .timed ? "Go to round…" : "Go to level…") {
                        jumpNumber = ""
                        jumpOpen = true
                    }
                    .accessibilityIdentifier("journeyJumpToNumber")
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
                Button {
                    guard currentPageStart <= Int.max - 20 else { return }
                    pageStart = currentPageStart + 20
                } label: {
                    Label("Later", systemImage: "chevron.right")
                }
                .disabled(currentPageStart > Int.max - 20)
                .accessibilityIdentifier("journeyLater")
            }
            .buttonStyle(.borderless)
        }
    }

    private func levelRow(_ number: Int) -> some View {
        let unlocked = number <= store.currentUnlockedLevel
        let current = number == store.currentUnlockedLevel
        let solved = store.progress.hasCompleted(number: number, mode: store.mode)
        let optimal = store.progress.hasOptimalCompletion(number: number, mode: store.mode)
        let bestMoves = store.progress.bestMoves(number: number, mode: store.mode)
        let title = "\(store.mode == .timed ? "Round" : "Level") \(number)"
        let resumable = number == store.run.level.number && !store.isDaily && !store.isDuel
            && !store.hasEnded && (store.run.moves > 0 || (store.isTimeRush && (store.timeRushMazeNumber > 1 || store.isAwaitingTimeRushMaze)))
        return VStack(alignment: .leading, spacing: 4) {
            Button {
                store.openLevel(number)
                onPlay()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: solved ? "checkmark.circle.fill" : unlocked ? "play.circle.fill" : "lock")
                        .foregroundStyle(solved ? Palette.cyan : unlocked ? Palette.violet : .secondary)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                        if let bestMoves {
                            Text("Best: \(bestMoves) \(bestMoves == 1 ? "move" : "moves")")
                                .font(.caption).foregroundStyle(.secondary)
                        } else if solved {
                            Text("Solved").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if optimal {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(Palette.gold)
                    }
                    if current || resumable {
                        Text(resumable ? "Continue" : "Play").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(!unlocked)
            .buttonStyle(.borderless)
            .accessibilityLabel("\(title), \(unlocked ? "unlocked" : "locked"), \(optimal ? "solved optimally" : solved ? "solved" : "not solved")\(bestMoves.map { ", best \($0) \($0 == 1 ? "move" : "moves")" } ?? "")")
            .accessibilityHint(unlocked ? resumable ? "Continue your saved run" : solved ? "Replay to improve your best" : "Play this \(store.mode == .timed ? "round" : "level")" : "Solve earlier \(store.mode == .timed ? "rounds" : "levels") to unlock")
            .accessibilityIdentifier("journeyLevel_\(number)")
            if store.progress.canClaimAdBonus(number: number, mode: store.mode) {
                CompletionBonusButton(number: number, mode: store.mode)
            }
        }
    }
}
