import UIKit

/// Texture rasterization and its cache live off the UI actor.
actor ProceduralTextures {
    static let shared = ProceduralTextures()
    private var cache: [String: UIImage] = [:]

    func ball(for skin: BallSkin) -> UIImage {
        let key = "ball:\(skin.id):\(skin.hex):\(skin.accentHex):\(skin.pattern)"
        if let image = cache[key] { return image }
        let base = components(skin.hex)
        let accent = components(skin.accentHex)
        let image = raster(width: 512, height: 256) { u, v in
            let phi = u * .pi * 2
            let theta = v * .pi
            let x = sin(theta) * cos(phi)
            let y = cos(theta)
            let z = sin(theta) * sin(phi)
            let cloud = sin(x * 6 + sin(y * 5)) * cos(z * 7 - y * 3)
            var blend: Double
            switch skin.pattern {
            case "marble":
                let vein = abs(sin(x * 11 + y * 5 + 3 * sin(z * 5 + x * 2) + cloud))
                blend = pow(vein, 28) * 0.82 + (cloud + 1) * 0.09
            case "stripe":
                let stripe = sin(phi * 5 + y * 6 + sin(y * 3))
                blend = stripe > 0.32 ? 0.95 : (stripe > 0.19 ? 0.5 : 0.02)
            case "rings":
                let ring = abs(sin(y * 10 + x * 0.8))
                blend = ring < 0.20 ? 1 : (ring < 0.27 ? 0.45 : 0.02)
            case "speckle":
                let fine = sin(x * 197 + z * 131) * sin(y * 173 - z * 83)
                blend = fine > 0.80 ? 0.98 : (cloud + 1) * 0.12
            default:
                blend = (cloud + 1) * 0.035
            }
            return (base.0 + (accent.0 - base.0) * blend,
                    base.1 + (accent.1 - base.1) * blend,
                    base.2 + (accent.2 - base.2) * blend, 1)
        }
        cache[key] = image
        return image
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
