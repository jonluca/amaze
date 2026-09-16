import SwiftUI

/// The share artwork renders the actual linked board, with its real starting square.
struct ChallengeShareCard: View {
    let challenge: SharedChallenge

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            HStack {
                Text("PRISM ROLL").font(.system(size: 30, weight: .bold, design: .rounded)).tracking(5)
                Spacer()
                Image(systemName: "sparkles").font(.system(size: 32)).foregroundStyle(Color.cyan)
            }
            Text(challenge.title).font(.system(size: 54, weight: .bold, design: .rounded))
                .lineLimit(2).minimumScaleFactor(0.65)
            ChallengeBoardPreview(level: challenge.level)
                .padding(34)
                .frame(height: 690)
                .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 36))
            VStack(alignment: .leading, spacing: 12) {
                Text(challenge.senderMoves.map { "I painted it in \($0) moves." } ?? "One maze. Every path.")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                Text(challenge.senderMoves == nil ? "Paint every square. Find your flow." : "Can you match my score?")
                    .font(.system(size: 29)).foregroundStyle(.white.opacity(0.75))
            }
            HStack {
                Text("PLAY THE SAME PUZZLE").font(.system(size: 21, weight: .semibold)).tracking(2)
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 28, weight: .semibold))
            }
            .foregroundStyle(Color.cyan)
        }
        .padding(64)
        .frame(width: 1_024, height: 1_280)
        .foregroundStyle(.white)
        .background(LinearGradient(colors: [Color(red: 0.065, green: 0.075, blue: 0.16),
                                            Color(red: 0.16, green: 0.075, blue: 0.23)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
        .environment(\.colorScheme, .dark)
        .environment(\.dynamicTypeSize, .large)
    }
}
