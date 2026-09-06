import SwiftUI

struct PlayView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var ads: AdService
    @EnvironmentObject private var duel: DuelService

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 570
            VStack(spacing: compact ? 9 : 14) {
                if !store.isDuel { ModePicker().padding(.horizontal, 22) }
                headline(compact: compact).padding(.horizontal, 27)
                MazeSceneView(level: store.run.level, position: store.run.position, painted: store.run.painted,
                              skin: store.skin, isComplete: store.run.isComplete, theme: store.theme,
                              resetID: store.runID, onSwipe: store.move)
                    .accessibilityIdentifier("mazeBoard")
                    .frame(maxWidth: .infinity, maxHeight: .infinity).frame(minHeight: 130)
                progressBar.padding(.horizontal, 27)
                if store.isDuel { opponentBar.padding(.horizontal, 27) }
                else {
                    HStack(spacing: 10) {
                        RewardButton(kind: .hint, title: "Hint", icon: "lightbulb.fill")
                        if store.clock != nil { RewardButton(kind: .extraTime, title: "+30 seconds", icon: "timer") }
                        else if store.run.remainingMoves != nil { RewardButton(kind: .extraMoves, title: "+3 moves", icon: "scope") }
                        else { RewardButton(kind: .skip, title: "Skip level", icon: "forward.end.fill") }
                    }.padding(.horizontal, 24)
                }
                HStack(spacing: 6) {
                    Image(systemName: store.hint == nil ? "hand.draw" : "sparkles")
                    Text(hintText)
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(store.hint == nil ? Palette.secondary : Palette.gold)
                .padding(.bottom, 4)
            }
            .allowsHitTesting(!store.hasEnded && !(store.isDuel && duel.didWin != nil))
            .accessibilityHidden(store.hasEnded || (store.isDuel && duel.didWin != nil))
            .overlay {
                if store.hasEnded || (store.isDuel && duel.didWin != nil) {
                    ZStack {
                        Palette.background.opacity(0.83)
                        CompletionView().padding(.horizontal, 23)
                    }
                }
            }
        }
    }
    private var hintText: String {
        if let hint = store.hint { return "Swipe \(hint.rawValue)" }
        if store.clock?.hasStarted == false { return "Your first swipe starts the clock" }
        return "Swipe to roll. Paint every path."
    }
    private func headline(compact: Bool) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text(store.isDuel ? "LIVE DUEL" : store.isDaily ? "DAILY CHALLENGE" : !store.run.level.coinCells.isEmpty ? "COIN RUSH · BONUS LEVEL" : store.mode == .endless ? "NO LIMITS. JUST FLOW." : store.mode == .timed ? "BEAT THE CLOCK" : "MAKE EVERY MOVE COUNT")
                    .font(.system(size: 8, weight: .heavy, design: .rounded)).tracking(1.7)
                    .foregroundStyle(!store.run.level.coinCells.isEmpty && !store.isDuel ? Palette.gold : Palette.violet)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(store.isDuel ? "Race to paint" : store.isDaily ? "Today’s maze" : String(format: "Level %03d", store.run.level.number))
                    .font(.system(size: compact ? 28 : 34, weight: .bold, design: .rounded))
                    .accessibilityIdentifier("levelTitle")
            }
            Spacer(minLength: 8)
            if store.clock != nil {
                VStack(spacing: 3) {
                    Text(store.timerText).font(.system(size: compact ? 22 : 27, weight: .bold, design: .rounded)).monospacedDigit()
                        .accessibilityIdentifier("timeRemaining")
                    Text(store.clock?.hasStarted == true ? store.clockRunning ? "SECONDS LEFT" : "PAUSED" : "READY")
                        .font(.system(size: 7, weight: .heavy)).tracking(1)
                }
                .foregroundStyle((store.clock?.remainingSeconds ?? 0) <= 10 ? Palette.accent : Palette.cyan)
                .padding(.horizontal, 13).padding(.vertical, 9)
                .background(Palette.cyan.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            } else if let remaining = store.run.remainingMoves {
                VStack(spacing: 3) {
                    Text("\(remaining)").font(.system(size: 26, weight: .bold, design: .rounded)).monospacedDigit()
                    Text("MOVES LEFT").font(.system(size: 7, weight: .heavy)).tracking(1)
                }.foregroundStyle(remaining < 4 ? Palette.accent : Palette.cyan)
                    .accessibilityElement(children: .ignore).accessibilityLabel("\(remaining) moves left")
                    .accessibilityIdentifier("movesRemaining")
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Palette.cyan.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            }
            if !store.isDuel {
                Button(action: store.replay) {
                    Image(systemName: "arrow.counterclockwise").font(.system(size: 16, weight: .semibold))
                        .frame(width: 34, height: 44).foregroundStyle(Palette.secondary)
                }.accessibilityLabel("Restart level")
            }
        }
    }
    private var progressBar: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(Int(store.fraction * 100))%").font(.system(size: 20, weight: .bold, design: .rounded)).monospacedDigit()
                    Text("PAINTED").font(.system(size: 8, weight: .heavy)).tracking(1).foregroundStyle(Palette.secondary)
                }
                Spacer()
                if !store.run.level.coinCells.isEmpty && !store.isDuel {
                    Label("\(store.run.collectedCoinCells.count)/\(store.run.level.coinCells.count)", systemImage: "circle.inset.filled")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.gold)
                } else {
                    Text("\(store.run.moves) moves").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.secondary)
                        .accessibilityIdentifier("moveCount")
                }
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.line)
                    Capsule().fill(LinearGradient(colors: [Color(hex: store.skin.hex), Color(hex: store.skin.accentHex)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(5, geometry.size.width * store.fraction))
                        .shadow(color: Color(hex: store.skin.hex).opacity(0.35), radius: 6)
                }
            }.frame(height: 5).animation(.easeOut(duration: 0.25), value: store.fraction)
        }
    }
    private var opponentBar: some View {
        HStack {
            Label(duel.opponentName, systemImage: "person.fill").lineLimit(1)
            Spacer()
            Text("\(Int(duel.opponentProgress * 100))%")
            Button("Leave") { duel.cancel(); store.endSpecialSession() }
        }.font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.cyan)
    }
}
