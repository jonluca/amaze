import SceneKit
import UIKit

@MainActor
enum BallMaterialFactory {
    static func color(hex: String) -> UIColor {
        let value = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0xFF647C
        return UIColor(red: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                       blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }

    static func make(for skin: BallSkin) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .blinn
        material.diffuse.contents = ProceduralTextures.ball(for: skin)
        material.locksAmbientWithDiffuse = true
        material.specular.contents = UIColor.white
        material.specular.intensity = 0.85
        material.shininess = 0.86
        material.reflective.contents = ProceduralTextures.studioReflection()
        material.reflective.intensity = skin.pattern == "rings" ? 0.4 : 0.18
        material.emission.contents = material.diffuse.contents
        material.emission.intensity = 0.075
        return material
    }

    static func paint(_ tint: UIColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .blinn
        material.diffuse.contents = tint
        material.locksAmbientWithDiffuse = true
        material.emission.contents = tint
        material.emission.intensity = 0.16
        material.specular.contents = UIColor.white
        material.specular.intensity = 0.28
        material.shininess = 0.65
        return material
    }
}
