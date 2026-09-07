import SwiftUI
import Combine

struct PlayView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var duel: DuelService
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let isActive: Bool
    let onReady: (Bool, UUID) -> Void

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 570
            let renderRunID = store.runID
            let renderInputID = store.inputID
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 0) {
                        board(runID: renderRunID, inputID: renderInputID)
                            .frame(height: max(160, geometry.size.height * 0.38))
                        ScrollView {
                            VStack(spacing: 20) {
                                modeControls
                                headline(compact: true)
                                progressBar
                                rewardControls
                                instructions
                            }
                            .padding(20)
                        }
                        .accessibilityIdentifier("accessiblePlayControls")
                    }
                } else {
                    VStack(spacing: compact ? 10 : 16) {
                        modeControls.padding(.horizontal, 20)
                        headline(compact: compact).padding(.horizontal, 20)
                        board(runID: renderRunID, inputID: renderInputID)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .frame(minHeight: 130)
                        progressBar.padding(.horizontal, 20)
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
        .background(Palette.background)
    }

    private func board(runID: UUID, inputID: UUID) -> some View {
        MazeSceneView(level: store.run.level, position: store.run.position, painted: store.run.painted,
                      skin: store.skin, isComplete: store.run.isComplete, theme: store.theme,
                      resetID: runID, isActive: isActive, moveEvents: store.moveEvents.eraseToAnyPublisher(),
                      onReady: { onReady($0, runID) }, onSwipe: { store.move($0, for: inputID) })
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

    private var instructions: some View {
        Label(hintText, systemImage: store.hint == nil ? "hand.draw" : "sparkles")
            .font(.caption)
            .foregroundStyle(store.hint == nil ? Palette.secondary : Palette.gold)
            .multilineTextAlignment(.center)
    }

    private var hasResult: Bool { store.hasEnded || (store.isDuel && duel.didWin != nil) }

    private var hintText: String {
        if let hint = store.hint { return "Swipe \(hint.rawValue)" }
        if store.clock?.hasStarted == false { return "Your first swipe starts the clock" }
        return "Swipe to roll. Paint every path."
    }

    private func headline(compact: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if store.isDuel {
                    Label("Live Duel", systemImage: "person.2")
                        .font(.caption).foregroundStyle(Palette.violet)
                } else if !store.run.level.coinCells.isEmpty {
                    Label("Coin Rush", systemImage: "circle.inset.filled")
                        .font(.caption).foregroundStyle(Palette.gold)
                }
                Text(store.isDuel ? "Race to paint" : store.isDaily ? "Today’s maze" : String(format: "Level %03d", store.run.level.number))
                    .font(compact ? .title2.bold() : .title.bold())
                    .accessibilityIdentifier("levelTitle")
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
                Button(action: store.replay) {
                    Label("Restart level", systemImage: "arrow.counterclockwise")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .accessibilityLabel("Restart level")
            }
        }
    }

    private var progressBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text("\(Int(store.fraction * 100))% painted").monospacedDigit()
                Spacer()
                if !store.run.level.coinCells.isEmpty && !store.isDuel {
                    Label("\(store.run.collectedCoinCells.count)/\(store.run.level.coinCells.count)", systemImage: "circle.inset.filled")
                        .foregroundStyle(Palette.gold)
                } else {
                    Text("\(store.run.moves) moves").accessibilityIdentifier("moveCount")
                }
            }
            ProgressView(value: store.fraction)
                .tint(Color(hex: store.skin.hex))
                .accessibilityLabel("Maze painted")
                .accessibilityValue("\(Int(store.fraction * 100)) percent")
        }
        .font(.caption)
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
