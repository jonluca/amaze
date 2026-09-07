import Combine
import SceneKit
import UIKit

@MainActor
final class MazeSceneCoordinator: NSObject {
    let renderer = MazeSceneRenderer()
    var onSwipe: (MoveDirection) -> Void
    var onReady: (Bool) -> Void = { _ in }
    var onResultReady: () -> Void = {}
    private(set) var isReady = false
    private weak var canvasView: MazeCanvasView?
    private var moveSubscription: AnyCancellable?
    private var subscribedRunID: UUID?
    private var preparationRevision: Int?
    private var firstFrameObserver: MazeFirstFrameObserver?
    private var displayLink: CADisplayLink?
    private var frameClock = MazeFrameClock()
    private var isStopped = false
    private var isActive = true
    private var publishedReady: Bool?
    private var publishedRunID: UUID?
    private var publishedRevision: Int?
    private var resultRunID: UUID?
    private var resultRevision: Int?
    private var resultMoveCount: Int?

    init(onSwipe: @escaping (MoveDirection) -> Void) { self.onSwipe = onSwipe }

    func configure(_ view: MazeCanvasView) {
        canvasView = view
        view.setPreparing(true)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = .multisampling4X
        SceneFrameRatePolicy.apply(to: view)
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.isPlaying = false
        view.onLayout = { [weak self] size in
            self?.renderer.resize(to: size)
            self?.prepareSceneIfReady()
        }
        view.onVisibilityChange = { [weak self] visible in
            guard let self else { return }
            self.frameClock.reset()
            if let view = self.canvasView { SceneFrameRatePolicy.apply(to: view, displayLink: self.displayLink) }
            self.displayLink?.isPaused = !visible || !self.isReady || !self.isActive
            self.canvasView?.isPlaying = visible && self.isReady && self.isActive
        }
        renderer.onPreparationNeeded = { [weak self] in self?.beginPreparation() }
        renderer.onResourcesReady = { [weak self] in self?.prepareSceneIfReady() }
        let link = CADisplayLink(target: self, selector: #selector(advanceFrame(_:)))
        SceneFrameRatePolicy.apply(to: view, displayLink: link)
        link.isPaused = true
        link.add(to: .main, forMode: .common)
        displayLink = link
        // Gestures belong to the full gameplay window. The board retains its
        // VoiceOver actions and uses the same readiness gate as that bridge.
        view.isAccessibilityElement = true
        view.accessibilityLabel = "3D painting maze"
        view.accessibilityTraits = [.allowsDirectInteraction]
        view.accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: "Roll up", target: self, selector: #selector(rollUp)),
            UIAccessibilityCustomAction(name: "Roll down", target: self, selector: #selector(rollDown)),
            UIAccessibilityCustomAction(name: "Roll left", target: self, selector: #selector(rollLeft)),
            UIAccessibilityCustomAction(name: "Roll right", target: self, selector: #selector(rollRight))
        ]
    }

    func bind(_ events: AnyPublisher<GameMoveEvent, Never>?, runID: UUID?) {
        renderer.consumesMoveEvents = events != nil
        guard subscribedRunID != runID || (moveSubscription == nil) != (events == nil) else { return }
        moveSubscription?.cancel()
        subscribedRunID = runID
        moveSubscription = events?.sink { [weak self] event in
            self?.renderer.receive(event)
            self?.publishResultIfReady()
        }
    }

    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        frameClock.reset()
        displayLink?.isPaused = !active || !isReady || canvasView?.window == nil
        canvasView?.isPlaying = active && canvasView?.scene != nil
        publishResultIfReady()
    }

    func publishResultIfReady() {
        if !renderer.hasResult {
            resultRunID = nil
            resultRevision = nil
            resultMoveCount = nil
            return
        }
        guard !isStopped, isActive, isReady, renderer.resultReady, !hasPublishedResult else { return }
        let runID = subscribedRunID
        let revision = renderer.contentRevision
        let moveCount = renderer.acceptedMoveCount
        let callback = onResultReady
        // A finished game can still have accepted visual turns to play. Notify
        // SwiftUI only after those turns settle, outside its update transaction.
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isStopped, self.isActive, self.isReady,
                  self.subscribedRunID == runID, self.renderer.contentRevision == revision,
                  self.renderer.acceptedMoveCount == moveCount,
                  self.renderer.resultReady, !self.hasPublishedResult else { return }
            self.resultRunID = runID
            self.resultRevision = revision
            self.resultMoveCount = moveCount
            callback()
        }
    }

    private var hasPublishedResult: Bool {
        guard resultMoveCount == renderer.acceptedMoveCount else { return false }
        if let subscribedRunID { return resultRunID == subscribedRunID }
        return resultRevision == renderer.contentRevision
    }

    func publishReadiness() {
        guard publishedReady != isReady || publishedRunID != subscribedRunID || publishedRevision != renderer.contentRevision else { return }
        let ready = isReady
        let runID = subscribedRunID
        let revision = renderer.contentRevision
        let callback = onReady
        publishedReady = ready
        publishedRunID = runID
        publishedRevision = revision
        // UIViewRepresentable updates may be inside a SwiftUI transaction.
        // Deliver this UIKit lifecycle event after that transaction completes.
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isStopped, self.renderer.contentRevision == revision,
                  self.subscribedRunID == runID, self.isReady == ready else { return }
            callback(ready)
        }
    }

    func stop() {
        isStopped = true
        isReady = false
        let callback = onReady
        DispatchQueue.main.async { callback(false) }
        moveSubscription?.cancel()
        displayLink?.invalidate()
        displayLink = nil
        firstFrameObserver = nil
        renderer.onPreparationNeeded = nil
        renderer.onResourcesReady = nil
        renderer.stop()
    }

    private func beginPreparation() {
        isReady = false
        publishReadiness()
        preparationRevision = nil
        firstFrameObserver = nil
        frameClock.reset()
        displayLink?.isPaused = true
        canvasView?.delegate = nil
        canvasView?.isPlaying = false
        canvasView?.scene = nil
        canvasView?.setPreparing(true)
    }

    private func prepareSceneIfReady() {
        guard !isStopped, renderer.resourcesReady, let view = canvasView,
              view.bounds.width > 0, view.bounds.height > 0,
              preparationRevision != renderer.contentRevision else { return }
        let revision = renderer.contentRevision
        preparationRevision = revision
        // SceneKit uploads resources and compiles its pipelines on its own
        // background preparation thread, before the scene becomes visible.
        view.prepare(renderer.preparationResources) { [weak self, weak view] _ in
            DispatchQueue.main.async {
                guard let self, let view, !self.isStopped,
                      self.renderer.contentRevision == revision else { return }
                let observer = MazeFirstFrameObserver { [weak self] in self?.receivedFirstFrame(revision: revision) }
                self.firstFrameObserver = observer
                view.delegate = observer
                view.pointOfView = self.renderer.cameraNode
                view.scene = self.renderer.scene
                view.isPlaying = self.isActive
            }
        }
    }

    private func receivedFirstFrame(revision: Int) {
        guard !isStopped, preparationRevision == revision, renderer.contentRevision == revision, !isReady else { return }
        isReady = true
        canvasView?.setPreparing(false)
        canvasView?.delegate = nil
        firstFrameObserver = nil
        frameClock.reset()
        displayLink?.isPaused = !isActive || canvasView?.window == nil
        publishReadiness()
        publishResultIfReady()
    }

    @objc private func advanceFrame(_ link: CADisplayLink) {
        guard isReady else { return }
        let interval = frameClock.interval(timestamp: link.timestamp, targetTimestamp: link.targetTimestamp)
        renderer.advance(by: interval)
        publishResultIfReady()
    }

    private func roll(_ direction: MoveDirection) -> Bool {
        guard isReady, isActive else { return false }
        onSwipe(direction)
        return true
    }
    @objc private func rollUp() -> Bool { roll(.up) }
    @objc private func rollDown() -> Bool { roll(.down) }
    @objc private func rollLeft() -> Bool { roll(.left) }
    @objc private func rollRight() -> Bool { roll(.right) }
}
