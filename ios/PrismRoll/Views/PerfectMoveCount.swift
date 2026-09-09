import SwiftUI

struct PerfectMoveCount: View {
    let level: MazeLevel
    let runID: UUID
    let knownMinimum: Int?
    @State private var calculatedMinimum: Int?
    @State private var completedRequest: Request?
    @State private var attempt = 0

    private struct Request: Hashable {
        let runID: UUID
        let attempt: Int
    }

    private var request: Request { Request(runID: runID, attempt: attempt) }
    private var minimum: Int? {
        knownMinimum ?? (completedRequest == request ? calculatedMinimum : nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let minimum {
                let caption = "Perfect: \(minimum) \(minimum == 1 ? "move" : "moves")"
                Label(caption, systemImage: "crown.fill")
                    .foregroundStyle(Palette.gold)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(caption)
                    .accessibilityHint("Fewest moves from the start of this level")
                    .accessibilityIdentifier("perfectMoveCount")
            } else if completedRequest == request {
                Button { attempt += 1 } label: {
                    Label("Retry perfect count", systemImage: "arrow.clockwise")
                }
                .accessibilityHint("Calculate the minimum number of moves for this level")
                .accessibilityIdentifier("retryPerfectMoveCount")
            } else {
                // Keep the row visible while native optimization proves the
                // answer. Playing the maze never waits for this calculation.
                Label("Calculating perfect…", systemImage: "hourglass")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("perfectMoveCountLoading")
            }
        }
        .task(id: request) {
            guard knownMinimum == nil, completedRequest != request else { return }
            let requested = request
            let minimum = await MazeMinimumMoveCache.shared.minimumMoves(for: level)
            guard !Task.isCancelled else { return }
            calculatedMinimum = minimum
            completedRequest = requested
        }
    }
}
