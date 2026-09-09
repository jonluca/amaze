import SwiftUI

struct PerfectMoveCount: View {
    let level: MazeLevel
    let runID: UUID
    let knownMinimum: Int?
    let bestCompletedMoves: Int?
    @State private var calculatedTarget: MazeMoveTarget?
    @State private var calculatedRunID: UUID?

    private var target: MazeMoveTarget? {
        if let knownMinimum { return .perfect(knownMinimum) }
        return calculatedRunID == runID ? calculatedTarget : nil
    }

    private var caption: String? {
        switch target {
        case .perfect(let moves): "Perfect: \(moves) \(moves == 1 ? "move" : "moves")"
        case .bestKnown(let moves): "Best known: \(moves) \(moves == 1 ? "move" : "moves")"
        case nil: nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let caption {
                Label(caption, systemImage: knownPerfect ? "crown.fill" : "flag.checkered")
                    .foregroundStyle(Palette.gold)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(caption)
                    .accessibilityHint(knownPerfect ? "Fewest moves from the start of this level" : "An achievable solution; fewer moves may be possible")
                    .accessibilityIdentifier("perfectMoveCount")
            } else {
                // Reserve the caption row so finishing the background search
                // cannot resize the maze during the player's opening swipe.
                Text(" ").accessibilityHidden(true)
            }
        }
        .task(id: runID) {
            guard knownMinimum == nil, calculatedRunID != runID else { return }
            let requestedRunID = runID
            let level = level
            let bestCompletedMoves = bestCompletedMoves
            // Searching from the immutable starting board keeps the target fixed
            // during play and never puts solver work on the rendering thread.
            let minimum = await MazeMinimumMoveCache.shared.minimumMoves(for: level)
            guard !Task.isCancelled else { return }
            calculatedTarget = minimum.map(MazeMoveTarget.perfect)
                ?? MazeMoveTarget.knownSolution(for: level, completedBest: bestCompletedMoves)
            calculatedRunID = requestedRunID
        }
    }

    private var knownPerfect: Bool {
        if case .perfect = target { return true }
        return false
    }
}
