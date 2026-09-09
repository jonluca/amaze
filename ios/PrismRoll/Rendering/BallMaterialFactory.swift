import SceneKit
import UIKit

@MainActor
enum BallMaterialFactory {
    static func color(hex: String) -> UIColor {
        let value = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0xFF647C
        return UIColor(red: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                       blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }

    static func make(for skin: BallSkin) async -> SCNMaterial {
        let texture = await ProceduralTextures.shared.ball(for: skin)
        let reflection = await ProceduralTextures.shared.studioReflection()
        let material = SCNMaterial()
        material.lightingModel = .blinn
        material.diffuse.contents = texture
        material.locksAmbientWithDiffuse = true
        material.specular.contents = UIColor.white
        material.specular.intensity = 0.85
        material.shininess = 0.86
        material.reflective.contents = reflection
        material.reflective.intensity = skin.pattern == "rings" ? 0.4 : 0.18
        material.emission.contents = material.diffuse.contents
        material.emission.intensity = 0.075
        switch skin.pattern {
        case "solar":
            material.emission.intensity = 0.20
            material.shininess = 0.68
            material.reflective.intensity = 0.12
        case "plasma":
            material.emission.intensity = 0.24
            material.shininess = 0.94
            material.reflective.intensity = 0.24
        case "supernova":
            material.emission.intensity = 0.22
            material.shininess = 0.78
            material.reflective.intensity = 0.16
        case "singularity":
            material.emission.intensity = 0.26
            material.shininess = 0.98
            material.reflective.intensity = 0.11
        case "tesseract":
            material.emission.intensity = 0.24
            material.shininess = 0.96
            material.reflective.intensity = 0.29
        case "genesis":
            material.emission.intensity = 0.19
            material.shininess = 0.92
            material.reflective.intensity = 0.32
        default:
            break
        }
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

    static func paintTile(_ tint: UIColor) -> SCNMaterial {
        let material = paint(tint)
        material.specular.intensity = 0.18
        material.shininess = 0.48
        // Shade in tile coordinates so every palette gets the same satin finish.
        // The rounded bevel is purely shading: no extra geometry, transparency,
        // textures, or per-frame work on the CPU.
        material.shaderModifiers = [.surface: """
        #pragma body
        float2 uv = _surface.diffuseTexcoord;
        float slope = smoothstep(0.0, 1.0, uv.x * 0.35 + uv.y * 0.65);
        float3 tint = _surface.diffuse.rgb;
        float3 highlight = mix(tint, float3(1.0), 0.20);
        float3 shade = tint * 0.78;
        float3 finish = mix(highlight, shade, slope);

        // Match the plane's 0.06-unit corner radius within its 0.92-unit face.
        float radius = 0.06 / 0.92;
        float2 corner = abs(uv - 0.5) - (0.5 - radius);
        float edgeDistance = length(max(corner, float2(0.0)))
            + min(max(corner.x, corner.y), 0.0) - radius;
        float bevel = 1.0 - smoothstep(0.004, 0.026, -edgeDistance);
        float edgeLight = (0.5 - uv.x) * 0.65 + (0.5 - uv.y);
        finish += bevel * edgeLight * 0.14;
        _surface.diffuse.rgb = clamp(finish, float3(0.0), float3(1.0));
        _surface.emission.rgb *= mix(float3(1.0), float3(0.78), slope);
        """]
        return material
    }
}
