import SceneKit

/// Each preparation gets an immutable callback token; an old frame can never
/// mark a replacement scene ready after a replay, theme change or teardown.
final class MazeFirstFrameObserver: NSObject, SCNSceneRendererDelegate {
    private let onFrame: @MainActor () -> Void

    init(onFrame: @escaping @MainActor () -> Void) { self.onFrame = onFrame }

    func renderer(_ renderer: any SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        DispatchQueue.main.async { [onFrame] in onFrame() }
    }
}
