import AudioToolbox
import SwiftUI

struct SharedChallengeView: View {
    @StateObject private var session: SharedChallengeSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var ready = false
    @State private var settled = false
    @State private var shareOpen = false
    let skin: BallSkin
    let theme: BoardTheme
    let hapticsEnabled: Bool
    let soundEnabled: Bool
    let directionButtonsEnabled: Bool

    init(challenge: SharedChallenge, skin: BallSkin, theme: BoardTheme,
         hapticsEnabled: Bool, soundEnabled: Bool, directionButtonsEnabled: Bool) {
        _session = StateObject(wrappedValue: SharedChallengeSession(challenge: challenge))
        self.skin = skin
        self.theme = theme
        self.hapticsEnabled = hapticsEnabled
        self.soundEnabled = soundEnabled
        self.directionButtonsEnabled = directionButtonsEnabled
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 12) {
                    VStack(spacing: 5) {
                        Text(session.challenge.title).font(.headline).multilineTextAlignment(.center)
                        if let target = session.challenge.senderMoves {
                            Text("Friend's score: \(target) moves").foregroundStyle(.secondary)
                        }
                        Text("\(session.run.moves) moves").monospacedDigit()
                            .accessibilityIdentifier("sharedChallengeMoves")
                    }
                    .padding(.horizontal)
                    board
                        .frame(minHeight: 150, maxHeight: .infinity)
                    ScrollView {
                        controls.padding(.horizontal, 20)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(maxHeight: dynamicTypeSize.isAccessibilitySize ? geometry.size.height * 0.43 : 220)
                }
                .padding(.vertical, 12)
            }
            .background { MazeBackdrop(theme: theme).ignoresSafeArea() }
            .navigationTitle("Friend challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("closeSharedChallenge")
                }
            }
            .gameplaySwipes(enabled: acceptsInput, sessionID: session.runID, onSwipe: move)
            .onChange(of: session.runID) { _, _ in ready = false; settled = false }
        }
        .tint(Palette.cyan)
        .preferredColorScheme(.dark)
    }

    private var acceptsInput: Bool { ready && scenePhase == .active && !shareOpen && !session.run.isComplete }

    private var board: some View {
        let runID = session.runID
        return MazeSceneView(level: session.run.level, position: session.run.position, painted: session.run.painted,
                             skin: skin, isComplete: session.run.isComplete, moveCount: session.run.moves,
                             theme: theme, resetID: runID, isActive: scenePhase == .active && !shareOpen,
                             hapticsEnabled: hapticsEnabled, moveEvents: session.moveEvents.eraseToAnyPublisher(),
                             onReady: { if runID == session.runID { ready = $0 } },
                             onResultReady: { if runID == session.runID { settled = true } },
                             onSwipe: { move($0, runID) })
            .accessibilityIdentifier("sharedChallengeBoard")
    }

    private var controls: some View {
        VStack(spacing: 12) {
            if session.run.isComplete && settled {
                Label("Maze painted!", systemImage: "checkmark.seal.fill")
                    .font(.title2.bold()).foregroundStyle(Palette.cyan)
                    .accessibilityIdentifier("sharedChallengeComplete")
                if let target = session.challenge.senderMoves {
                    Text(session.run.moves < target ? "You found a shorter route." : session.run.moves == target
                         ? "You matched your friend's score." : "Try again to find a shorter route.")
                        .multilineTextAlignment(.center)
                }
                ChallengeShareButton(onPresentationChanged: { shareOpen = $0 }) {
                    try ChallengeLink.make(level: session.run.level, title: session.challenge.title, moves: session.run.moves)
                }
            } else {
                Text("Swipe to roll to a wall. Paint every path.").font(.subheadline)
                    .multilineTextAlignment(.center)
                if directionButtonsEnabled {
                    DirectionControls(enabled: acceptsInput, sessionID: session.runID, onMove: move)
                }
            }
            Button(session.run.isComplete ? "Play again" : "Restart maze") { session.restart() }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("restartSharedChallenge")
        }
    }

    private func move(_ direction: MoveDirection, _ runID: UUID) {
        guard acceptsInput else { return }
        let previousMoves = session.run.moves
        session.move(direction, for: runID)
        if soundEnabled && session.run.moves > previousMoves { AudioServicesPlaySystemSound(1104) }
    }
}
