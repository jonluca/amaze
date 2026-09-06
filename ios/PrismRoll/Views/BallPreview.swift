import SwiftUI

struct BallPreview: View {
    let skin: BallSkin

    var body: some View {
        BallSceneView(skin: skin).accessibilityHidden(true).allowsHitTesting(false)
    }
}
