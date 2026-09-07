import SceneKit

@MainActor
final class MazeCanvasView: UIView {
    let sceneView = SCNView()
    var onVisibilityChange: ((Bool) -> Void)?
    var onLayout: ((CGSize) -> Void)?
    private(set) var isPreparing = false
    private var loadingOverlay: UIStackView?
    private lazy var levelTransition = MazeLevelTransition(view: sceneView)

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureViewport()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureViewport()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // SwiftUI owns this stationary viewport. Its child retains the entry
        // transform while layout changes the untransformed bounds and center.
        UIView.performWithoutAnimation {
            sceneView.bounds = CGRect(origin: .zero, size: bounds.size)
            sceneView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        }
        levelTransition.layoutDidChange()
        if isPreparing { setPreparing(true) }
        onLayout?(bounds.size)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        onVisibilityChange?(window != nil)
    }

    func setPreparing(_ preparing: Bool) {
        isPreparing = preparing
        guard preparing, !levelTransition.isTransitioning else {
            loadingOverlay?.removeFromSuperview()
            loadingOverlay = nil
            return
        }
        guard loadingOverlay == nil else { return }
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = BallMaterialFactory.color(hex: "AA98FF")
        indicator.startAnimating()
        let label = UILabel()
        label.text = "Loading your maze"
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white.withAlphaComponent(0.85)
        let stack = UIStackView(arrangedSubviews: [indicator, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([stack.centerXAnchor.constraint(equalTo: centerXAnchor),
                                     stack.centerYAnchor.constraint(equalTo: centerYAnchor)])
        loadingOverlay = stack
    }

    /// Preserve the completed board while its replacement prepares offscreen.
    /// Ordinary first loads and manual level changes do not create a snapshot.
    func beginLevelTransition() {
        cancelLevelTransition()
        guard sceneView.scene != nil, bounds.width > 0, bounds.height > 0 else { return }
        beginLevelTransition(outgoingImage: sceneView.snapshot())
    }

    /// The image overload also permits viewport testing without GPU rendering.
    func beginLevelTransition(outgoingImage: UIImage) {
        cancelLevelTransition()
        layoutIfNeeded()
        levelTransition.begin(outgoingImage: outgoingImage)
        setPreparing(isPreparing)
    }

    /// Called only after SceneKit has displayed the replacement's first frame.
    func revealLevelTransition(reduceMotion: Bool, completion: @escaping () -> Void) {
        levelTransition.reveal(reduceMotion: reduceMotion, completion: completion)
    }

    /// Accessibility or lifecycle changes settle the current valid reveal.
    func finishLevelTransition() {
        levelTransition.finish()
        setPreparing(isPreparing)
    }

    /// Replacement and teardown must not make a stale board ready for input.
    func cancelLevelTransition() {
        levelTransition.cancel()
        setPreparing(isPreparing)
    }

    private func configureViewport() {
        clipsToBounds = true
        backgroundColor = .clear
        isOpaque = false
        sceneView.backgroundColor = .clear
        sceneView.isOpaque = false
        sceneView.isAccessibilityElement = false
        sceneView.accessibilityElementsHidden = true
        sceneView.isUserInteractionEnabled = false
        addSubview(sceneView)
    }
}
