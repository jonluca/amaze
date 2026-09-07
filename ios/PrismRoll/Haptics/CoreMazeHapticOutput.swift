import Foundation

@MainActor
final class CoreMazeHapticOutput: MazeHapticOutput {
    private let worker = MazeHapticEngineWorker()
    var onInterruption: (() -> Void)? {
        didSet {
            worker.setInterruptionHandler { [weak self] in
                DispatchQueue.main.async { self?.onInterruption?() }
            }
        }
    }

    func prepare() { worker.prepare() }
    func setRolling(_ rolling: Bool) { worker.setRolling(rolling) }
    func playCompletion() { worker.playCompletion() }
    func stop() { worker.stop() }

    deinit { worker.shutdown() }
}
