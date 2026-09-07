import SwiftUI

extension View {
    /// Attach once to the gameplay shell. The native observer spans its window.
    @MainActor
    func gameplaySwipes(enabled: Bool, sessionID: UUID,
                        onSwipe: @escaping (MoveDirection, UUID) -> Void) -> some View {
        background(GameplaySwipeCapture(enabled: enabled, sessionID: sessionID, onSwipe: onSwipe))
    }
}
