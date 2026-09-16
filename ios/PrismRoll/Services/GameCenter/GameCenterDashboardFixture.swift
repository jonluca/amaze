#if DEBUG
import SwiftUI

/// A deterministic test-only dashboard; this never authenticates or reports.
struct GameCenterDashboardFixture: View {
    let destination: GameCenterDashboardDestination
    let dismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "gamecontroller.fill").font(.largeTitle)
                Text("Prism Player").font(.headline)
                Text("Game Center test dashboard")
            }
            .accessibilityIdentifier("gameCenterDashboard")
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: dismiss).accessibilityIdentifier("gameCenterDashboardDone")
                }
            }
        }
    }

    private var title: String {
        switch destination {
        case .achievements: "Achievements"
        case .leaderboards: "Leaderboards"
        case .leaderboard(let board): board.title
        }
    }
}
#endif
