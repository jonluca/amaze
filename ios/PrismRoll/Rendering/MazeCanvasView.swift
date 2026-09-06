import SceneKit

@MainActor
final class MazeCanvasView: SCNView {
    var onLayout: ((CGSize) -> Void)?
    private(set) var isPreparing = false
    private var loadingOverlay: UIStackView?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?(bounds.size)
    }

    func setPreparing(_ preparing: Bool) {
        isPreparing = preparing
        guard preparing else {
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
        label.textColor = BallMaterialFactory.color(hex: "8F9FBE")
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
}
