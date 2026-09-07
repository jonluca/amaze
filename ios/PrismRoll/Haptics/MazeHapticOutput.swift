import Foundation

@MainActor
protocol MazeHapticOutput: AnyObject {
    var onInterruption: (() -> Void)? { get set }
    func prepare()
    func setRolling(_ rolling: Bool)
    func playCompletion()
    func stop()
}
