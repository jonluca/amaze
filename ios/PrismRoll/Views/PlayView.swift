import SwiftUI
import Combine

struct PlayView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var duel: DuelService
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var settledRunID: UUID?
    @State private var tutorialRunID: UUID?
    let isActive: Bool
    let onRestart: () -> Void
    let onCompletionReady: (UUID) -> Void
    let onReady: (Bool, UUID) -> Void

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 570
            let renderRunID = store.runID
            let renderInputID = store.inputID
            Group {
                if dynamicTypeSize.isAccessibilitySize || (compact && (dynamicTypeSize >= .xxLarge || store.progress.directionButtonsEnabled)) {
                    VStack(spacing: 0) {
                        board(runID: renderRunID, inputID: renderInputID)
                            .frame(height: max(160, geometry.size.height * 0.38))
                        ScrollView {
                            VStack(spacing: 20) {
                                modeControls
                                headline(compact: true)
                                directionControls
                                rewardControls
                                instructions
                            }
                            .padding(20)
                        }
                        .background(Palette.background)
                        .accessibilityIdentifier("accessiblePlayControls")
                    }
                } else {
                    VStack(spacing: compact ? 10 : 16) {
                        modeControls.padding(.horizontal, 20)
                        headline(compact: compact).padding(.horizontal, 20)
                        board(runID: renderRunID, inputID: renderInputID)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .frame(minHeight: 130)
                        directionControls.padding(.horizontal, 20)
                        rewardControls.padding(.horizontal, 20)
                        instructions.padding(.horizontal, 20)
                    }
                    .padding(.vertical, compact ? 8 : 12)
                }
            }
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(!hasResult)
            .accessibilityHidden(hasResult)
            .overlay {
                if hasResult {
                    ZStack {
                        Palette.background.opacity(0.8)
                        ScrollView {
                            CompletionView().padding(20)
                                .frame(maxWidth: .infinity)
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        .defaultScrollAnchor(.center)
                    }
                }
            }
        }
        .background { MazeBackdrop(theme: store.theme).ignoresSafeArea() }
        .tint(Palette.ink)
        .onAppear { tutorialRunID = store.showsTutorial ? store.runID : nil }
        .onChange(of: store.runID) { _, runID in
            tutorialRunID = store.showsTutorial ? runID : nil
        }
        .onChange(of: store.hasEnded) { _, ended in
            if !ended { settledRunID = nil }
        }
    }

    private func board(runID: UUID, inputID: UUID) -> some View {
        MazeSceneView(level: store.run.level, position: store.run.position, painted: store.run.painted,
                      skin: store.skin, isComplete: store.run.isComplete, isFailed: store.isFailed,
                      moveCount: store.run.moves, theme: store.theme,
                      resetID: runID, isActive: isActive, hapticsEnabled: store.progress.hapticsEnabled,
                      moveEvents: store.moveEvents.eraseToAnyPublisher(),
                      levelTransitions: store.levelTransitionEvents.eraseToAnyPublisher(),
                      onReady: { onReady($0, runID) },
                      onResultReady: {
                          guard store.runID == runID else { return }
                          settledRunID = runID
                          if store.run.isComplete && !store.isDuel { onCompletionReady(runID) }
                      },
                      onSwipe: { store.move($0, for: inputID) })
            .accessibilityIdentifier("mazeBoard")
    }

    @ViewBuilder
    private var modeControls: some View {
        if store.isDaily {
            HStack {
                Label("Daily challenge", systemImage: "calendar")
                Spacer()
                Button("Back to play", action: store.endSpecialSession)
            }
            .font(.subheadline)
        } else if !store.isDuel {
            ModePicker()
        }
    }

    @ViewBuilder
    private var rewardControls: some View {
        if store.isDuel {
            opponentBar
        } else if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 12) { rewardButtons }
        } else {
            HStack(spacing: 12) { rewardButtons }
        }
    }

    @ViewBuilder
    private var rewardButtons: some View {
        RewardButton(kind: .hint, title: "Hint", icon: "lightbulb")
        if store.clock != nil {
            RewardButton(kind: .extraTime, title: "+30 seconds", icon: "timer")
        } else if store.run.remainingMoves != nil {
            RewardButton(kind: .extraMoves, title: "+3 moves", icon: "scope")
        } else {
            RewardButton(kind: .skip, title: "Skip level", icon: "forward.end")
        }
    }

    @ViewBuilder
    private var instructions: some View {
        if tutorialRunID == store.runID && !store.progress.tutorialDismissed {
            TutorialTipView(hasMoved: store.run.moves > 0,
                            instruction: store.hint != nil || store.blockedDirection != nil ? hintText : nil,
                            onDismiss: store.dismissTutorial)
        } else {
            Label(hintText, systemImage: store.hint != nil ? "sparkles" : store.blockedDirection != nil ? "arrow.triangle.turn.up.right.diamond" : "hand.draw")
            .font(.caption)
            .foregroundStyle(store.hint == nil ? Palette.ink.opacity(0.8) : Palette.gold)
            .multilineTextAlignment(.center)
            .accessibilityIdentifier("playInstructions")
        }
    }

    @ViewBuilder
    private var directionControls: some View {
        if store.progress.directionButtonsEnabled {
            DirectionControls(enabled: isActive && store.acceptsGameplayInput && !hasResult,
                              sessionID: store.inputID, onMove: store.move)
        }
    }

    private var hasResult: Bool {
        ((store.isFailed || (store.isDuel && store.run.isComplete)) && settledRunID == store.runID)
            || (store.isDuel && duel.didWin != nil && !store.run.isComplete)
    }

    private var hintText: String {
        if let hint = store.hint { return "Swipe \(hint.rawValue)" }
        if store.blockedDirection != nil { return "Wall ahead. Try another direction." }
        if store.isTimeRush {
            if store.clock?.hasStarted == false {
                return "Paint all \(store.timeRushMazeCount) mazes on one timer. Your first swipe starts the clock."
            }
            return "Paint every path. The next maze starts automatically."
        }
        if store.clock?.hasStarted == false { return "Your first swipe starts the clock" }
        if store.run.moves == 0 { return "Swipe anywhere to roll to a wall. Paint every path." }
        return "Swipe to roll. Paint every path."
    }

    private func headline(compact: Bool) -> some View {
        let layout = dynamicTypeSize >= .xxLarge ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            VStack(alignment: .leading, spacing: 4) {
                if store.isDuel {
                    Label("Live Duel", systemImage: "person.2")
                        .font(.caption).foregroundStyle(Palette.violet)
                } else if store.isTimeRush {
                    Text("Maze \(store.timeRushMazeNumber) of \(store.timeRushMazeCount)")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.cyan)
                        .accessibilityIdentifier("timeRushStage")
                } else if !store.run.level.coinCells.isEmpty {
                    Label("Coin Rush", systemImage: "circle.inset.filled")
                        .font(.caption).foregroundStyle(Palette.gold)
                }
                Text(store.isDuel ? "Race to paint" : store.isDaily ? "Today’s maze" : String(format: store.isTimeRush ? "Round %03d" : "Level %03d", store.run.level.number))
                    .font(compact ? .title2.bold() : .title.bold())
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .accessibilityIdentifier("levelTitle")
                runSummary
            }
            Spacer(minLength: 0)
            if store.clock != nil {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(store.timerText)
                        .font(.title2.weight(.semibold)).monospacedDigit()
                        .accessibilityIdentifier("timeRemaining")
                    Text(store.clock?.hasStarted == true ? store.clockRunning ? "Seconds left" : "Paused" : "Ready")
                        .font(.caption)
                }
                .foregroundStyle((store.clock?.remainingSeconds ?? 0) <= 10 ? Palette.accent : Palette.cyan)
            } else if let remaining = store.run.remainingMoves {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(remaining)").font(.title2.weight(.semibold)).monospacedDigit()
                    Text("Moves left").font(.caption)
                }
                .foregroundStyle(remaining < 4 ? Palette.accent : Palette.cyan)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(remaining) moves left")
                .accessibilityIdentifier("movesRemaining")
            }
            if !store.isDuel {
                Button(action: onRestart) {
                    Label(store.isTimeRush ? "Restart round" : "Restart level", systemImage: "arrow.counterclockwise")
                        .frame(minWidth: 24, minHeight: 32)
                }
                .accessibilityLabel(store.isTimeRush ? "Restart round" : "Restart level")
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
            }
        }
    }

    private var runSummary: some View {
        Group {
            if !store.run.level.coinCells.isEmpty && !store.isDuel {
                Label("\(store.run.collectedCoinCells.count)/\(store.run.level.coinCells.count)", systemImage: "circle.inset.filled")
                    .foregroundStyle(Palette.gold)
            } else {
                Text(store.run.moves == 1 ? "1 move" : "\(store.run.moves) moves")
                    .accessibilityIdentifier("moveCount")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var opponentBar: some View {
        HStack {
            ProgressView(value: duel.opponentProgress) {
                Label(duel.opponentName, systemImage: "person.fill").lineLimit(1)
            } currentValueLabel: {
                Text("\(Int(duel.opponentProgress * 100))%")
            }
            Button("Leave") { duel.cancel(); store.endSpecialSession() }
                .buttonStyle(.bordered)
        }
        .font(.caption)
        .tint(Palette.cyan)
    }
}
