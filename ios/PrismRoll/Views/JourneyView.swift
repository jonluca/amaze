import SwiftUI

struct JourneyView: View {
    @EnvironmentObject private var store: GameStore
    let onPlay: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("NO FINISH LINE").font(.system(size: 9, weight: .heavy, design: .rounded))
                        .tracking(3).foregroundStyle(Palette.secondary)
                    Text("Keep your color moving.").font(.system(size: 29, weight: .bold, design: .rounded)).accessibilityIdentifier("journeyHeading")
                    Text("Three ways to play. A new maze around every corner.")
                        .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                }
                HStack(spacing: 12) {
                    metric("\(store.progress.completedLevels)", label: "LEVELS PAINTED", symbol: "checkmark.seal")
                    metric("\(store.progress.points)", label: "COIN BALANCE", symbol: "circle.fill")
                }
                ModePicker()
                HStack {
                    Text(pathTitle)
                        .font(.system(size: 10, weight: .heavy, design: .rounded)).tracking(1)
                    Spacer()
                    Image(systemName: modeIcon).foregroundStyle(Palette.violet)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    ForEach(visibleLevels, id: \.self) { number in
                        levelTile(number)
                    }
                }
                Text("Replay any unlocked maze. Completion coins and bonus-board coins are awarded once; your progress is saved separately for each mode.")
                    .font(.system(size: 11)).foregroundStyle(Palette.secondary).lineSpacing(3)
            }.padding(.horizontal, 26).padding(.top, 10).padding(.bottom, 15)
        }.scrollIndicators(.hidden)
    }

    private var pathTitle: String {
        switch store.mode {
        case .endless: "YOUR CLASSIC PATH"
        case .timed: "YOUR TIME RUSH RUNS"
        case .challenge: "YOUR LIMITED MOVE MAZES"
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

    private func metric(_ value: String, label: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol).font(.system(size: 22)).foregroundStyle(Palette.gold)
            Text(value).font(.system(size: 30, weight: .bold, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.55)
            Text(label).font(.system(size: 8, weight: .heavy, design: .rounded)).tracking(0.8).foregroundStyle(Palette.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(19)
            .background(Palette.paper, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Palette.line, lineWidth: 1))
    }

    private func levelTile(_ number: Int) -> some View {
        let unlocked = number <= store.currentUnlockedLevel
        let current = number == store.currentUnlockedLevel
        return Button {
            store.openLevel(number)
            onPlay()
        } label: {
            VStack(spacing: 7) {
                Image(systemName: current ? "play.fill" : unlocked ? "arrow.counterclockwise" : "lock.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text(number < 10 ? "0\(number)" : String(number))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.4).padding(.horizontal, 6)
            }
            .frame(maxWidth: .infinity).frame(height: 86)
            .foregroundStyle(current ? Palette.background : unlocked ? Palette.ink : Palette.secondary.opacity(0.6))
            .background(current ? Palette.violet : unlocked ? Palette.mint : Palette.paper.opacity(0.65), in: RoundedRectangle(cornerRadius: 21))
            .overlay(RoundedRectangle(cornerRadius: 21).stroke(current ? Palette.violet : Palette.line, lineWidth: 1))
        }
        .disabled(!unlocked).accessibilityLabel("Level \(number), \(unlocked ? "unlocked" : "locked")")
        .accessibilityIdentifier("journeyLevel_\(number)")
    }
}
