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
    private var transitionSubscription: AnyCancellable?
    private var transitionFromRunID: UUID?
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
    private let haptics = MazeHapticPlayer()
    private var completionBeat = MazeCompletionBeat()
    private var receivedMove = false
    private var reduceMotion = false

    init(onSwipe: @escaping (MoveDirection) -> Void) { self.onSwipe = onSwipe }

    func configure(_ view: MazeCanvasView) {
        canvasView = view
        view.setPreparing(true)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.sceneView.backgroundColor = .clear
        view.sceneView.isOpaque = false
        view.sceneView.antialiasingMode = .multisampling4X
        SceneFrameRatePolicy.apply(to: view.sceneView)
        view.sceneView.autoenablesDefaultLighting = false
        view.sceneView.allowsCameraControl = false
        view.sceneView.isPlaying = false
        view.onLayout = { [weak self] size in
            self?.renderer.resize(to: size)
            self?.prepareSceneIfReady()
        }
        view.onVisibilityChange = { [weak self] visible in
            guard let self else { return }
            self.frameClock.reset()
            if !visible { self.canvasView?.finishLevelTransition() }
            if let view = self.canvasView { SceneFrameRatePolicy.apply(to: view.sceneView, displayLink: self.displayLink) }
            self.displayLink?.isPaused = !visible || !self.isReady || !self.isActive
            self.canvasView?.sceneView.isPlaying = visible && self.isReady && self.isActive
            self.syncHaptics()
        }
        renderer.onPreparationNeeded = { [weak self] in self?.beginPreparation() }
        renderer.onResourcesReady = { [weak self] in self?.prepareSceneIfReady() }
        let link = CADisplayLink(target: self, selector: #selector(advanceFrame(_:)))
        SceneFrameRatePolicy.apply(to: view.sceneView, displayLink: link)
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

    func configureFeedback(enabled: Bool, reduceMotion: Bool) {
        haptics.setEnabled(enabled)
        self.reduceMotion = reduceMotion
        if reduceMotion { canvasView?.finishLevelTransition() }
    }

    func bind(_ events: AnyPublisher<GameMoveEvent, Never>?,
              levelTransitions: AnyPublisher<UUID, Never>? = nil, runID: UUID?) {
        renderer.consumesMoveEvents = events != nil
        guard subscribedRunID != runID || (moveSubscription == nil) != (events == nil)
                || (transitionSubscription == nil) != (levelTransitions == nil) else { return }
        if subscribedRunID != runID {
            if transitionFromRunID == nil || transitionFromRunID != subscribedRunID {
                canvasView?.cancelLevelTransition()
            }
            transitionFromRunID = nil
            haptics.reset()
            completionBeat = MazeCompletionBeat()
            receivedMove = false
        }
        moveSubscription?.cancel()
        transitionSubscription?.cancel()
        subscribedRunID = runID
        // This event arrives before the model swaps mazes. Capturing here
        // preserves the outgoing board regardless of SwiftUI update ordering.
        transitionSubscription = levelTransitions?.sink { [weak self] completedRunID in
            guard let self, !self.isStopped, self.subscribedRunID == completedRunID,
                  self.isReady, self.renderer.resultReady,
                  self.canvasView?.window != nil, !self.reduceMotion else { return }
            self.transitionFromRunID = completedRunID
            self.canvasView?.beginLevelTransition()
        }
        moveSubscription = events?.sink { [weak self] event in
            guard let self else { return }
            let before = self.renderer.acceptedMoveCount
            self.renderer.receive(event)
            if self.renderer.acceptedMoveCount > before { self.receivedMove = true }
            self.syncHaptics()
            self.publishResultIfReady()
        }
    }

    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        frameClock.reset()
        if !active { canvasView?.finishLevelTransition() }
        displayLink?.isPaused = !active || !isReady || canvasView?.window == nil
        canvasView?.sceneView.isPlaying = active && canvasView?.sceneView.scene != nil
        syncHaptics()
        publishResultIfReady()
    }

    func publishResultIfReady() {
        syncHaptics()
        if !renderer.hasResult {
            resultRunID = nil
            resultRevision = nil
            resultMoveCount = nil
            return
        }
        if !isStopped, isActive, isReady, receivedMove, renderer.isComplete,
           renderer.resultReady, completionBeat.begin() {
            haptics.playCompletion()
        }
        guard !isStopped, isActive, isReady, renderer.resultReady,
              !completionBeat.isPlaying, !hasPublishedResult else { return }
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
                  self.renderer.resultReady, !self.completionBeat.isPlaying, !self.hasPublishedResult else { return }
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
        haptics.stop()
        canvasView?.cancelLevelTransition()
        let callback = onReady
        DispatchQueue.main.async { callback(false) }
        moveSubscription?.cancel()
        transitionSubscription?.cancel()
        displayLink?.invalidate()
        displayLink = nil
        firstFrameObserver = nil
        renderer.onPreparationNeeded = nil
        renderer.onResourcesReady = nil
        renderer.stop()
    }

    private func beginPreparation() {
        isReady = false
        syncHaptics()
        publishReadiness()
        preparationRevision = nil
        firstFrameObserver = nil
        frameClock.reset()
        displayLink?.isPaused = true
        canvasView?.sceneView.delegate = nil
        canvasView?.sceneView.isPlaying = false
        canvasView?.sceneView.scene = nil
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
        view.sceneView.prepare(renderer.preparationResources) { [weak self, weak view] _ in
            DispatchQueue.main.async {
                guard let self, let view, !self.isStopped,
                      self.renderer.contentRevision == revision else { return }
                let observer = MazeFirstFrameObserver { [weak self] in self?.receivedFirstFrame(revision: revision) }
                self.firstFrameObserver = observer
                view.sceneView.delegate = observer
                view.sceneView.pointOfView = self.renderer.cameraNode
                view.sceneView.scene = self.renderer.scene
                view.sceneView.isPlaying = self.isActive
            }
        }
    }

    private func receivedFirstFrame(revision: Int) {
        guard !isStopped, preparationRevision == revision, renderer.contentRevision == revision, !isReady else { return }
        canvasView?.setPreparing(false)
        canvasView?.sceneView.delegate = nil
        firstFrameObserver = nil
        let runID = subscribedRunID
        canvasView?.revealLevelTransition(reduceMotion: reduceMotion || !isActive) { [weak self] in
            guard let self, !self.isStopped, self.preparationRevision == revision,
                  self.renderer.contentRevision == revision, self.subscribedRunID == runID else { return }
            self.finishRevealingScene()
        }
    }

    private func finishRevealingScene() {
        isReady = true
        frameClock.reset()
        displayLink?.isPaused = !isActive || canvasView?.window == nil
        canvasView?.sceneView.isPlaying = isActive && canvasView?.window != nil
        syncHaptics()
        publishReadiness()
        publishResultIfReady()
    }

    @objc private func advanceFrame(_ link: CADisplayLink) {
        guard isReady, isActive, canvasView?.window != nil else { return }
        let interval = frameClock.interval(timestamp: link.timestamp, targetTimestamp: link.targetTimestamp)
        completionBeat.advance(by: min(interval, 1.0 / 15))
        renderer.advance(by: interval)
        publishResultIfReady()
    }

    private func syncHaptics() {
        let active = !isStopped && isActive && isReady && canvasView?.window != nil
        haptics.setActive(active)
        haptics.setRolling(active && renderer.pendingMoveCount > 0)
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
