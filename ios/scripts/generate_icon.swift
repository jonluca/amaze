import AppKit

// Native vector artwork, rendered into the universal iOS icon asset.
let size = NSSize(width: 1024, height: 1024)
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
                             bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false,
                             isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(calibratedRed: 0.973, green: 0.961, blue: 0.937, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
let shadow = NSShadow()
shadow.shadowColor = NSColor(calibratedRed: 0.20, green: 0.25, blue: 0.20, alpha: 0.18)
shadow.shadowBlurRadius = 24
shadow.shadowOffset = NSSize(width: 0, height: -24)
NSGraphicsContext.saveGraphicsState()
shadow.set()
NSColor.white.setFill()
NSBezierPath(roundedRect: NSRect(x: 120, y: 134, width: 784, height: 768), xRadius: 100, yRadius: 100).fill()
NSGraphicsContext.restoreGraphicsState()
let route = NSBezierPath()
route.move(to: NSPoint(x: 302, y: 332))
route.line(to: NSPoint(x: 717, y: 332))
route.line(to: NSPoint(x: 717, y: 518))
route.line(to: NSPoint(x: 305, y: 518))
route.line(to: NSPoint(x: 305, y: 730))
route.line(to: NSPoint(x: 694, y: 730))
route.lineWidth = 122
route.lineCapStyle = .round
route.lineJoinStyle = .round
NSColor(calibratedRed: 0.89, green: 0.91, blue: 0.87, alpha: 1).setStroke()
route.stroke()
route.lineWidth = 86
NSColor(calibratedRed: 0.98, green: 0.46, blue: 0.36, alpha: 1).setStroke()
route.stroke()
let sphere = NSBezierPath(ovalIn: NSRect(x: 601, y: 637, width: 186, height: 186))
NSGraphicsContext.saveGraphicsState()
shadow.shadowBlurRadius = 18
shadow.shadowOffset = NSSize(width: 4, height: -12)
shadow.set()
NSColor(calibratedRed: 0.93, green: 0.38, blue: 0.28, alpha: 1).setFill()
sphere.fill()
NSGraphicsContext.restoreGraphicsState()
NSGradient(colors: [NSColor(calibratedRed: 1, green: 0.77, blue: 0.58, alpha: 1), NSColor(calibratedRed: 1, green: 0.49, blue: 0.35, alpha: 1), NSColor(calibratedRed: 0.70, green: 0.18, blue: 0.16, alpha: 1)])!
    .draw(in: sphere, relativeCenterPosition: NSPoint(x: -0.4, y: 0.5))
NSGraphicsContext.restoreGraphicsState()
let output = CommandLine.arguments[1]
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
