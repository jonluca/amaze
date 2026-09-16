import SwiftUI

struct ChallengeShareButton: View {
    var title = "Challenge a friend"
    var onPresentationChanged: (Bool) -> Void = { _ in }
    let makeChallenge: () throws -> SharedChallenge
    @State private var challenge: SharedChallenge?
    @State private var failed = false

    var body: some View {
        Button {
            do {
                challenge = try makeChallenge()
                onPresentationChanged(true)
                AnalyticsService.shared.record("challenge_share_opened", parameters: [:])
            } catch {
                failed = true
            }
        } label: {
            Label(title, systemImage: "square.and.arrow.up")
                .foregroundStyle(Palette.cyan)
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("shareChallenge")
        .sheet(item: $challenge, onDismiss: { onPresentationChanged(false) }) { challenge in
            ChallengeShareSheet(challenge: challenge)
                .presentationDetents([.medium, .large])
        }
        .alert("Unable to share this maze", isPresented: $failed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Try a different completed level or today's daily maze.")
        }
    }
}
