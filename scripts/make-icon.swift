import AppKit
let output = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let transform = AffineTransform(scale: CGFloat(pixels) / 1024)
        (transform as NSAffineTransform).concat()
        let tile = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 204, yRadius: 204)
        NSGradient(starting: NSColor(calibratedRed: 0.17, green: 0.24, blue: 0.34, alpha: 1), ending: NSColor(calibratedRed: 0.035, green: 0.055, blue: 0.1, alpha: 1))!.draw(in: tile, angle: -90)
        let pulse = NSBezierPath()
        pulse.move(to: NSPoint(x: 215, y: 480)); pulse.line(to: NSPoint(x: 340, y: 480)); pulse.line(to: NSPoint(x: 420, y: 680)); pulse.line(to: NSPoint(x: 540, y: 335)); pulse.line(to: NSPoint(x: 630, y: 560)); pulse.line(to: NSPoint(x: 690, y: 480)); pulse.line(to: NSPoint(x: 810, y: 480))
        pulse.lineWidth = 49; pulse.lineCapStyle = .round; pulse.lineJoinStyle = .round
        NSColor(calibratedRed: 0.48, green: 0.8, blue: 1, alpha: 1).setStroke(); pulse.stroke()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(output)/icon_\(size)x\(size)\(suffix).png"))
    }
}
