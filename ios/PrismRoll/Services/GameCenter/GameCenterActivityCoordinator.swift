import Combine
@preconcurrency import GameKit

/// Keeps Games app launches queued until the app can safely change its play context.
@MainActor
final class GameCenterActivityCoordinator: NSObject, ObservableObject {
    @Published private(set) var pendingDestination: GameCenterActivityDestination?
    private var registered = false
    private var pendingActivity: AnyObject?
    private var activeActivity: AnyObject?
    private var activeDestination: GameCenterActivityDestination?

    func start() {
        guard #available(iOS 26.0, *), GameCenterRuntime.current == .live, !registered else { return }
        // Register before authentication so a cold Games app launch has a listener.
        GKLocalPlayer.local.register(self)
        registered = true
    }

    func setAuthenticated(_ authenticated: Bool) {
        guard #available(iOS 26.0, *) else { return }
        if authenticated {
            start()
        } else {
            pendingDestination = nil
            pendingActivity = nil
            finish()
        }
    }

    @available(iOS 26.0, *)
    func receive(_ activity: GKGameActivity) -> Bool {
        guard registered, GKLocalPlayer.local.isAuthenticated,
              let destination = GameCenterActivityDestination(identifier: activity.activityDefinition.identifier) else {
            return false
        }
        if let replaced = pendingActivity as? GKGameActivity { replaced.end() }
        pendingActivity = activity
        pendingDestination = destination
        return true
    }

    func didLaunchPendingActivity() {
        guard #available(iOS 26.0, *), let pending = pendingActivity as? GKGameActivity else { return }
        finish()
        activeDestination = pendingDestination
        activeActivity = pending
        pendingActivity = nil
        pendingDestination = nil
        pending.start()
    }

    func setPlaying(_ playing: Bool) {
        guard #available(iOS 26.0, *), let activity = activeActivity as? GKGameActivity else { return }
        if playing { activity.resume() } else { activity.pause() }
    }

    func setContext(mode: GameMode, isDaily: Bool, isDuel: Bool) {
        guard let destination = activeDestination else { return }
        let matches: Bool
        switch destination {
        case .classic: matches = mode == .endless && !isDaily && !isDuel
        case .timeRush: matches = mode == .timed && !isDaily && !isDuel
        case .daily: matches = isDaily && !isDuel
        }
        if !matches { finish() }
    }

    func finish() {
        if #available(iOS 26.0, *), let activity = activeActivity as? GKGameActivity { activity.end() }
        activeActivity = nil
        activeDestination = nil
    }
}
