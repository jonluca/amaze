import UIKit

/// Texture rasterization and its cache live off the UI actor.
actor ProceduralTextures {
    private typealias RGB = (Double, Double, Double)

    static let shared = ProceduralTextures()
    private var cache: [String: UIImage] = [:]

    func ball(for skin: BallSkin) -> UIImage {
        let key = "ball:\(skin.id):\(skin.hex):\(skin.accentHex):\(skin.pattern)"
        if let image = cache[key] { return image }
        let base = components(skin.hex)
        let accent = components(skin.accentHex)
        let width: Int
        switch skin.pattern {
        case "solar", "plasma", "supernova", "singularity", "tesseract", "genesis":
            width = 1024
        default:
            width = 512
        }
        let image = raster(width: width, height: width / 2) { u, v in
            let phi = u * .pi * 2
            let theta = v * .pi
            let x = sin(theta) * cos(phi)
            let y = cos(theta)
            let z = sin(theta) * sin(phi)
            let cloud = sin(x * 6 + sin(y * 5)) * cos(z * 7 - y * 3)
            let tint: RGB
            switch skin.pattern {
            case "marble":
                let vein = abs(sin(x * 11 + y * 5 + 3 * sin(z * 5 + x * 2) + cloud))
                tint = mix(base, accent, pow(vein, 28) * 0.82 + (cloud + 1) * 0.09)
            case "stripe":
                let stripe = sin(phi * 5 + y * 6 + sin(y * 3))
                tint = mix(base, accent, stripe > 0.32 ? 0.95 : (stripe > 0.19 ? 0.5 : 0.02))
            case "rings":
                let ring = abs(sin(y * 10 + x * 0.8))
                tint = mix(base, accent, ring < 0.20 ? 1 : (ring < 0.27 ? 0.45 : 0.02))
            case "speckle":
                let fine = sin(x * 197 + z * 131) * sin(y * 173 - z * 83)
                tint = mix(base, accent, fine > 0.80 ? 0.98 : (cloud + 1) * 0.12)
            case "solar":
                tint = solar(base, accent, x: x, y: y, z: z)
            case "plasma":
                tint = plasma(base, accent, x: x, y: y, z: z)
            case "supernova":
                tint = supernova(base, accent, x: x, y: y, z: z)
            case "singularity":
                tint = singularity(base, accent, x: x, y: y, z: z)
            case "tesseract":
                tint = tesseract(base, accent, x: x, y: y, z: z)
            case "genesis":
                tint = genesis(base, accent, x: x, y: y, z: z)
            default:
                tint = mix(base, accent, (cloud + 1) * 0.035)
            }
            return (tint.0, tint.1, tint.2, 1)
        }
        cache[key] = image
        return image
    }

    // Sample on the unit sphere so the extravagant finishes stay continuous
    // across the texture seam. They are rasterized once, with no animated work.
    private func solar(_ base: RGB, _ accent: RGB, x: Double, y: Double, z: Double) -> RGB {
        let turbulence = sin(x * 9 + sin(z * 8) * 2) + cos(y * 11 + sin(x * 7))
        let flare = abs(sin(z * 12 + y * 4 + turbulence * 1.7))
        let ember = (sin(x * 21 + y * 17) * cos(z * 19 - y * 13) + 1) * 0.5
        let molten = mix((0.48, 0.035, 0.015), base, 0.38 + flare * 0.62)
        return mix(molten, accent, pow(flare, 14) * 0.88 + ember * 0.10)
    }

    private func plasma(_ base: RGB, _ accent: RGB, x: Double, y: Double, z: Double) -> RGB {
        let field = sin(x * 7 + sin(y * 8) * 1.3) + sin(z * 8 - cos(y * 6))
        let fork = sin(y * 10 + cos(z * 7) + sin(x * 8))
        let arc = exp(-abs(field) * 10)
        let secondary = exp(-abs(fork) * 14) * 0.48
        let haze = (sin(x * 4 - z * 5 + y * 3) + 1) * 0.5
        let glass = mix((0.025, 0.018, 0.10), base, 0.45 + haze * 0.45)
        let ionized = mix(glass, accent, max(arc, secondary))
        return mix(ionized, (0.90, 1, 1), pow(arc, 5) * 0.70)
    }

    private func supernova(_ base: RGB, _ accent: RGB, x: Double, y: Double, z: Double) -> RGB {
        let axis = x * 0.48 + y * 0.64 + z * 0.60
        let angle = atan2(y * 0.60 - z * 0.64, x - axis * 0.48)
        let rays = pow(abs(sin(angle * 13 + axis * 8)), 10)
        let core = pow(abs(axis), 16)
        let plume = pow(abs(sin(axis * 7 + angle * 3 + sin(y * 9))), 4)
        let nebula = mix((0.16, 0.035, 0.43), base, 0.30 + plume * 0.70)
        let fire = mix(nebula, (1, 0.36, 0.13), rays * 0.66)
        return mix(fire, accent, min(1, core * 1.3 + rays * pow(abs(axis), 3) * 0.85))
    }

    private func singularity(_ base: RGB, _ accent: RGB, x: Double, y: Double, z: Double) -> RGB {
        let axis = x * 0.36 + y * 0.80 + z * 0.48
        let warp = axis + sin(x * 5 - z * 4) * 0.065
        let orbit = exp(-pow((abs(warp) - 0.32) * 29, 2))
        let echo = exp(-pow((abs(warp) - 0.49) * 58, 2)) * 0.55
        let haze = exp(-pow((abs(warp) - 0.35) * 7, 2)) * 0.42
        let dust = pow(max(0, sin(x * 183 + z * 137) * cos(y * 157 - z * 109)), 28)
        let void = mix(base, (0.35, 0.09, 0.62), haze)
        let ring = mix(void, accent, max(orbit, echo))
        return mix(ring, (1, 0.86, 0.65), max(orbit * 0.44, dust * 0.8))
    }

    private func tesseract(_ base: RGB, _ accent: RGB, x: Double, y: Double, z: Double) -> RGB {
        let a = abs(sin((x + y) * 8))
        let b = abs(sin((y - z) * 8))
        let c = abs(sin((z + x) * 8))
        let edge = exp(-min(a, min(b, c)) * 18)
        let node = exp(-(a + b + c - max(a, max(b, c))) * 23)
        let facet = (sin(x * 8 + y * 8) * sin(y * 8 - z * 8) + 1) * 0.5
        let crystal = mix((0.018, 0.025, 0.10), base, 0.35 + facet * 0.65)
        let lattice = mix(crystal, accent, edge * 0.94)
        return mix(lattice, (0.92, 0.72, 1), node * 0.95)
    }

    private func genesis(_ base: RGB, _ accent: RGB, x: Double, y: Double, z: Double) -> RGB {
        let flow = x * 5 + y * 4 - z * 3 + sin(y * 6 + z * 4) + sin(z * 7 - x * 3)
        let spectrum: RGB = ((sin(flow) + 1) * 0.5,
                             (sin(flow + 2.1) + 1) * 0.5,
                             (sin(flow + 4.2) + 1) * 0.5)
        let ribbon = pow(abs(sin(flow * 1.4 + sin(x * 10 + y * 5))), 0.7)
        let gilding = exp(-abs(sin(flow * 2.6 + cos(z * 8))) * 14)
        let stars = pow(max(0, sin(x * 149 - y * 113) * cos(z * 139 + x * 97)), 24)
        let prism = mix(base, spectrum, 0.22 + ribbon * 0.66)
        let gold = mix(prism, accent, gilding * 0.92)
        return mix(gold, (1, 1, 0.97), stars * 0.9)
    }

    private func mix(_ base: RGB, _ accent: RGB, _ amount: Double) -> RGB {
        (base.0 + (accent.0 - base.0) * amount,
         base.1 + (accent.1 - base.1) * amount,
         base.2 + (accent.2 - base.2) * amount)
    }

    func timber() -> UIImage {
        if let image = cache["wood"] { return image }
        let image = raster(width: 512, height: 512) { u, v in
            let bend = sin(v * 11) * 0.009 + sin(v * 29 + u * 8) * 0.003
            let growth = sin((u + bend) * 175 + sin(v * 8) * 0.7)
            let grain = pow(abs(growth), 16)
            let fine = sin(u * 950 + sin(v * 39) * 3) * 0.024
            let bands = sin(u * 22) * 0.025
            let knot = exp(-pow((u - 0.72) * 22, 2) - pow((v - 0.35) * 6, 2))
            let tone = 1 - grain * 0.18 + fine + bands - knot * 0.12
            return (0.83 * tone, 0.59 * tone, 0.34 * tone, 1)
        }
        cache["wood"] = image
        return image
    }

    func contactShadow() -> UIImage {
        if let image = cache["contact-shadow"] { return image }
        let image = raster(width: 128, height: 128) { u, v in
            let radius = hypot((u - 0.5) * 2, (v - 0.5) * 2)
            let alpha = pow(max(0, 1 - radius), 2.2) * 0.8
            return (0, 0, 0, alpha)
        }
        cache["contact-shadow"] = image
        return image
    }

    func studioReflection() -> UIImage {
        if let image = cache["studio"] { return image }
        let image = raster(width: 512, height: 256) { u, v in
            let key = exp(-pow(abs((u - 0.22) / 0.14), 6) - pow(abs((v - 0.30) / 0.11), 6))
            let cool = exp(-pow(abs((u - 0.72) / 0.035), 4) - pow(abs((v - 0.5) / 0.22), 6))
            let strip = exp(-pow(abs((u - 0.6) / 0.20), 6) - pow(abs((v - 0.09) / 0.019), 4))
            return (0.12 + key * 0.84 + cool * 0.43 + strip * 0.65,
                    0.15 + key * 0.81 + cool * 0.6 + strip * 0.47,
                    0.22 + key * 0.74 + cool * 0.76 + strip * 0.72, 1)
        }
        cache["studio"] = image
        return image
    }

    private func components(_ hex: String) -> (Double, Double, Double) {
        let value = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        return (Double((value >> 16) & 0xFF) / 255, Double((value >> 8) & 0xFF) / 255, Double(value & 0xFF) / 255)
    }

    private func raster(width: Int, height: Int, pixel: (Double, Double) -> (Double, Double, Double, Double)) -> UIImage {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for row in 0..<height {
            for column in 0..<width {
                let rgba = pixel(Double(column) / Double(width), Double(row) / Double(height))
                let index = (row * width + column) * 4
                let alpha = min(1, max(0, rgba.3))
                pixels[index] = UInt8(min(255, max(0, rgba.0 * alpha * 255)))
                pixels[index + 1] = UInt8(min(255, max(0, rgba.1 * alpha * 255)))
                pixels[index + 2] = UInt8(min(255, max(0, rgba.2 * alpha * 255)))
                pixels[index + 3] = UInt8(alpha * 255)
            }
        }
        let data = Data(pixels) as CFData
        guard let provider = CGDataProvider(data: data),
              let cgImage = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                    bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                    provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { return UIImage() }
        return UIImage(cgImage: cgImage)
    }
}
