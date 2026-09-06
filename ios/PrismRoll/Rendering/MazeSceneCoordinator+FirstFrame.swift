import SceneKit

extension MazeSceneCoordinator: SCNSceneRendererDelegate {
    nonisolated func renderer(_ renderer: any SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        DispatchQueue.main.async { [weak self] in self?.receivedFirstFrame() }
    }
}
