#!/usr/bin/env swift
// Draws the Funki app icon in the PNG sizes `iconutil` expects.
// Usage: swift Scripts/generate-icon.swift <output.iconset>
import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: generate-icon.swift <output.iconset>\n".utf8))
    exit(64)
}

/// Everything is laid out on a 1024 point canvas and scaled, so every size is
/// drawn natively instead of being resampled from a large image.
func draw(in context: CGContext, pixels: Int) {
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)

    // The macOS icon grid: a rounded square of 824 points, centred.
    let plate = CGPath(
        roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824),
        cornerWidth: 185, cornerHeight: 185, transform: nil
    )

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: CGColor(gray: 0, alpha: 0.28))
    context.addPath(plate)
    context.setFillColor(CGColor(red: 0.1, green: 0.6, blue: 0.4, alpha: 1))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(plate)
    context.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [
            CGColor(red: 0.30, green: 0.86, blue: 0.56, alpha: 1),
            CGColor(red: 0.02, green: 0.55, blue: 0.42, alpha: 1),
        ] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    context.restoreGState()

    // Radio waves around a dot.
    let center = CGPoint(x: 512, y: 512)
    context.setFillColor(.white)
    context.setStrokeColor(.white)
    context.fillEllipse(in: CGRect(x: center.x - 62, y: center.y - 62, width: 124, height: 124))
    context.setLineCap(.round)
    context.setLineWidth(58)
    let spread = CGFloat.pi * 0.27
    for (radius, alpha) in [(168.0, 1.0), (282.0, 0.78)] {
        context.setAlpha(alpha)
        for side in [0, CGFloat.pi] {
            context.addArc(center: center, radius: radius, startAngle: side - spread, endAngle: side + spread, clockwise: false)
            context.strokePath()
        }
    }
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
