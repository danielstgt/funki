#!/usr/bin/env swift
// Draws the Funki app icon in the PNG sizes `iconutil` expects.
// Usage: swift Scripts/generate-icon.swift <output.iconset>
import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: generate-icon.swift <output.iconset>\n".utf8))
    exit(64)
}

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

/// Everything is laid out on a 1024 point canvas and scaled, so every size is
/// drawn natively instead of being resampled from a large image.
func draw(in context: CGContext, pixels: Int) {
    let scale = CGFloat(pixels) / 1024
    context.scaleBy(x: scale, y: scale)

    /// Shadows ignore the transform, so their offset and blur are scaled by hand.
    /// Otherwise the 16 pixel icon would get the shadow of the 1024 pixel one.
    func setShadow(offsetY: CGFloat, blur: CGFloat, color: CGColor) {
        context.setShadow(offset: CGSize(width: 0, height: offsetY * scale), blur: blur * scale, color: color)
    }

    func fill(_ path: CGPath, _ color: CGColor) {
        context.addPath(path)
        context.setFillColor(color)
        context.fillPath()
    }

    func fill(_ path: CGPath, top: CGColor, bottom: CGColor, from topY: CGFloat, to bottomY: CGFloat) {
        let gradient = CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [top, bottom] as CFArray, locations: [0, 1]
        )!
        context.saveGState()
        context.addPath(path)
        context.clip()
        context.drawLinearGradient(gradient, start: CGPoint(x: 512, y: topY), end: CGPoint(x: 512, y: bottomY), options: [])
        context.restoreGState()
    }

    func circle(_ center: CGPoint, _ radius: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius), transform: nil)
    }

    // The macOS icon grid: a rounded square of 824 points, centred.
    let plate = CGPath(
        roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824),
        cornerWidth: 185, cornerHeight: 185, transform: nil
    )
    context.saveGState()
    setShadow(offsetY: -10, blur: 24, color: CGColor(gray: 0, alpha: 0.28))
    fill(plate, color(0xFF9838))
    context.restoreGState()
    fill(plate, top: color(0xFFD45E), bottom: color(0xFF9838), from: 924, to: 100)

    // Funki: a little head with an antenna that sends.
    let ink = color(0x1F2444)
    let headBottom: CGFloat = 190, headTop: CGFloat = 560
    let ball = CGPoint(x: 512, y: 712)

    context.setLineCap(.round)
    context.setLineWidth(24)
    context.setStrokeColor(ink)
    context.move(to: CGPoint(x: 512, y: headTop - 10))
    context.addLine(to: ball)
    context.strokePath()

    let spread = CGFloat.pi * 0.26
    for (radius, alpha) in [(92.0, 1.0), (146.0, 0.5)] {
        context.setStrokeColor(ink.copy(alpha: alpha)!)
        for side in [0, CGFloat.pi] {
            context.addArc(center: ball, radius: radius, startAngle: side - spread, endAngle: side + spread, clockwise: false)
            context.strokePath()
        }
    }

    context.saveGState()
    setShadow(offsetY: -4, blur: 10, color: color(0x9A4A00, alpha: 0.3))
    fill(circle(ball, 44), color(0xFF4D5E))
    context.restoreGState()
    fill(circle(CGPoint(x: ball.x - 13, y: ball.y + 14), 12), color(0xFFFFFF, alpha: 0.7))

    let head = CGPath(
        roundedRect: CGRect(x: 252, y: headBottom, width: 520, height: headTop - headBottom),
        cornerWidth: 160, cornerHeight: 160, transform: nil
    )
    context.saveGState()
    setShadow(offsetY: -14, blur: 30, color: color(0x9A4A00, alpha: 0.35))
    fill(head, .white)
    context.restoreGState()
    fill(head, top: .white, bottom: color(0xF4EEE6), from: headTop, to: headBottom)

    // Eyes with a highlight, cheeks and a smile.
    for x in [440.0, 584.0] {
        fill(CGPath(ellipseIn: CGRect(x: x - 30, y: 400, width: 60, height: 88), transform: nil), ink)
        fill(circle(CGPoint(x: x + 9, y: 464), 12), .white)
    }
    for x in [338.0, 614.0] {
        fill(CGPath(ellipseIn: CGRect(x: x, y: 338, width: 72, height: 38), transform: nil), color(0xFF7A7A, alpha: 0.5))
    }
    context.setStrokeColor(ink)
    context.setLineWidth(22)
    context.addArc(center: CGPoint(x: 512, y: 372), radius: 56, startAngle: .pi * 1.2, endAngle: .pi * 1.8, clockwise: false)
    context.strokePath()
}

let outputDirectory = URL(fileURLWithPath: arguments[1])
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        guard
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
            ),
            let context = NSGraphicsContext(bitmapImageRep: bitmap)
        else { exit(1) }

        draw(in: context.cgContext, pixels: pixels)
        context.flushGraphics()

        guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try png.write(to: outputDirectory.appending(path: name))
    }
}
print("Wrote iconset to \(outputDirectory.path)")
