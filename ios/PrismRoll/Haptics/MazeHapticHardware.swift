import Foundation

/// All methods are called on the worker's serial queue. Native callbacks may
/// arrive on any queue and are normalized by the worker before touching state.
protocol MazeHapticHardware: AnyObject {
    func setInterruptionHandler(_ handler: @escaping @Sendable () -> Void)
    func start(completion: @escaping @Sendable (Error?) -> Void)
    func preparePlayers() throws
    func startRolling() throws
    func stopRolling() throws
    func playCompletion() throws
    func stopPlayers() throws
    func shutdown()
}
