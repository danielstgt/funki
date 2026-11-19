#!/usr/bin/env swift
// Renders the social preview ("Open Graph" image) shown when the repository is shared.
// GitHub: Settings › General › Social preview. Recommended 1280×640, under 1 MB.
//
//   make og-image                                           -> Art/og-image.jpg (2560×1280)
//   swift Art/generate-og-image.swift <icon.png> <output.jpg|png> [--scale 2]
//
// The icon is the 1024 pixel PNG that Scripts/generate-icon.swift draws, so `make og-image`
// renders the iconset first. Pure AppKit, no dependencies. Text uses the system font.
// The output format follows the file extension; JPEG keeps a 2x render under 1 MB.
import AppKit

// MARK: - Arguments

var arguments = Array(CommandLine.arguments.dropFirst())
var scale: CGFloat = 2
if let index = arguments.firstIndex(of: "--scale"), index + 1 < arguments.count, let value = Double(arguments[index + 1]) {
    scale = CGFloat(value)
    arguments.removeSubrange(index...index + 1)
}
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: generate-og-image.swift <icon.png> <output.jpg|png> [--scale 2]\n".utf8))
    exit(64)
}
let iconPath = arguments[0]
let outputURL = URL(fileURLWithPath: arguments[1])
guard let icon = NSImage(contentsOfFile: iconPath) else {
    FileHandle.standardError.write(Data("Could not load \(iconPath)\n".utf8))
    exit(1)
}

// MARK: - Palette (matches the app icon)

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

// A night blue taken from the ink of Funki's face, so the orange plate glows on it.
let backgroundTop = NSColor(hex: 0x272C52)
let backgroundBottom = NSColor(hex: 0x11132A)
let orange = NSColor(hex: 0xFF9838)
let yellow = NSColor(hex: 0xFFD45E)
let red = NSColor(hex: 0xFF4D5E)
let ink = NSColor(hex: 0xF6F4F0)
let inkMuted = NSColor(hex: 0xB9BCD0)
let inkFaint = NSColor(hex: 0x7F84A3)

// MARK: - Canvas

let canvas = NSSize(width: 1280, height: 640)
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvas.width * scale), pixelsHigh: Int(canvas.height * scale),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else { exit(1) }
// Set the point size before creating the context so drawing happens in points and
// the context scales to pixels.
bitmap.size = canvas
guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else { exit(1) }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high
context.shouldAntialias = true
let cg = context.cgContext
let bounds = NSRect(origin: .zero, size: canvas)

// MARK: - Helpers

func font(_ size: CGFloat, _ weight: NSFont.Weight, rounded: Bool = false, monospacedDigits: Bool = false) -> NSFont {
    let base = monospacedDigits
        ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        : NSFont.systemFont(ofSize: size, weight: weight)
    guard rounded, let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
    return NSFont(descriptor: descriptor, size: size) ?? base
}

func attributed(_ text: String, font: NSFont, color: NSColor, kern: CGFloat = 0) -> NSAttributedString {
    NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .kern: kern])
}

/// Draws text with its baseline-box bottom-left corner at `origin`; returns the drawn width.
@discardableResult
func draw(_ string: NSAttributedString, at origin: NSPoint) -> CGFloat {
    string.draw(at: origin)
    return ceil(string.size().width)
}

/// Draws text vertically centred on `midY`, starting at `x`; returns the drawn width.
@discardableResult
func draw(_ string: NSAttributedString, x: CGFloat, midY: CGFloat) -> CGFloat {
    draw(string, at: NSPoint(x: x, y: midY - string.size().height / 2))
}

func glow(_ color: NSColor, at center: NSPoint, radius: CGFloat, alpha: CGFloat) {
    NSGradient(colors: [color.withAlphaComponent(alpha), color.withAlphaComponent(0)])?
        .draw(fromCenter: center, radius: 0, toCenter: center, radius: radius, options: [])
}

// MARK: - Background

NSGradient(colors: [backgroundBottom, backgroundTop])?.draw(in: bounds, angle: 90)

// Warm light behind the icon, as if the plate were lit, and a cooler one in the far corner.
glow(orange, at: NSPoint(x: 262, y: 320), radius: 440, alpha: 0.13)
glow(yellow, at: NSPoint(x: 262, y: 340), radius: 230, alpha: 0.08)
glow(red, at: NSPoint(x: 1200, y: 620), radius: 460, alpha: 0.05)

// The antenna's radio waves as a faint motif, sent out from beyond the top right corner.
// Same opening angle as the waves in the icon.
let waveCenter = NSPoint(x: 1320, y: 680)
let waveDirection: CGFloat = 225, waveSpread: CGFloat = 0.26 * 180
for (radius, alpha) in [(CGFloat(170), CGFloat(0.04)), (290, 0.03), (410, 0.022), (530, 0.015)] {
    let wave = NSBezierPath()
    wave.appendArc(withCenter: waveCenter, radius: radius,
                   startAngle: waveDirection - waveSpread, endAngle: waveDirection + waveSpread)
    wave.lineWidth = 30
    wave.lineCapStyle = .round
    NSColor.white.withAlphaComponent(alpha).setStroke()
    wave.stroke()
}

// MARK: - App icon with shadow

// The PNG keeps the margins of the macOS icon grid; its plate is 824 of 1024 pixels.
let iconRect = NSRect(x: 112, y: (canvas.height - 300) / 2, width: 300, height: 300)
cg.saveGState()
let shadow = NSShadow()
shadow.shadowBlurRadius = 40
shadow.shadowOffset = NSSize(width: 0, height: -18)
shadow.shadowColor = NSColor(hex: 0x05061A, alpha: 0.6)
shadow.set()
icon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1)
cg.restoreGState()

// MARK: - Title and tagline

let textX: CGFloat = 486
draw(attributed("Funki", font: font(104, .bold, rounded: true), color: ink, kern: -1.5), at: NSPoint(x: textX - 5, y: 384))
draw(attributed("Whether you are online, right in your macOS menu bar.", font: font(30, .regular), color: inkMuted, kern: -0.2),
     at: NSPoint(x: textX, y: 344))

// MARK: - Menu replica: status and the latency of the last checks

/// Latencies in milliseconds, oldest first. `nil` is a failed check, drawn as in the app.
let latencies: [Double?] = [
    24, 27, 22, 31, 25, 21, 38, 29, 24, 22, 26, nil, 34, 27, 23, 22,
    26, 41, 30, 25, 21, 28, 24, 23,
]
let pillPadding: CGFloat = 26
let pillHeight: CGFloat = 66
let stripFont = font(27, .regular, monospacedDigits: true)
let stripFontBold = font(27, .semibold, monospacedDigits: true)
let symbolSize: CGFloat = 32
let barWidth: CGFloat = 6, barGap: CGFloat = 4, barsHeight: CGFloat = 32
let barsWidth = CGFloat(latencies.count) * (barWidth + barGap) - barGap

let status = attributed("Online", font: stripFontBold, color: ink)
let label = attributed("Latency", font: stripFont, color: inkMuted)
let figure = attributed("23 ms", font: stripFontBold, color: ink)
let dividerGap: CGFloat = 22
let stripWidth = symbolSize + 12 + ceil(status.size().width) + dividerGap * 2 + 1
    + ceil(label.size().width) + 9 + ceil(figure.size().width) + 20 + barsWidth

let pillRect = NSRect(x: textX, y: 250, width: stripWidth + pillPadding * 2, height: pillHeight)
let pill = NSBezierPath(roundedRect: pillRect, xRadius: 16, yRadius: 16)
NSColor.white.withAlphaComponent(0.07).setFill()
pill.fill()
pill.lineWidth = 1.5
NSColor.white.withAlphaComponent(0.14).setStroke()
pill.stroke()

var cursor = pillRect.minX + pillPadding
let midY = pillRect.midY

// The menu bar icon, the same SF Symbol the app shows.
let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 25, weight: .medium)
    .applying(.init(paletteColors: [ink]))
if let symbol = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right", accessibilityDescription: nil)?
    .withSymbolConfiguration(symbolConfiguration) {
    let size = symbol.size
    symbol.draw(in: NSRect(x: cursor + (symbolSize - size.width) / 2, y: midY - size.height / 2,
                           width: size.width, height: size.height))
}
cursor += symbolSize + 12
cursor += draw(status, x: cursor, midY: midY)

cursor += dividerGap
NSColor.white.withAlphaComponent(0.16).setFill()
NSRect(x: cursor, y: midY - 17, width: 1, height: 34).fill()
cursor += 1 + dividerGap

cursor += draw(label, x: cursor, midY: midY) + 9
cursor += draw(figure, x: cursor, midY: midY) + 20

// The bars, newest on the right and highlighted like in the menu.
let barsBottom = midY - barsHeight / 2
let peak = latencies.compactMap { $0 }.max() ?? 1
for (index, latency) in latencies.enumerated() {
    let x = cursor + CGFloat(index) * (barWidth + barGap)
    if let latency {
        let isNewest = index == latencies.count - 1
        (isNewest ? ink : NSColor.white.withAlphaComponent(0.34)).setFill()
        let height = max(2, barsHeight * latency / peak)
        NSBezierPath(roundedRect: NSRect(x: x, y: barsBottom, width: barWidth, height: height),
                     xRadius: 1.5, yRadius: 1.5).fill()
    } else {
        red.setFill()
        for y in stride(from: barsBottom, to: barsBottom + barsHeight, by: 7) {
            NSBezierPath(roundedRect: NSRect(x: x, y: y, width: barWidth, height: 4), xRadius: 1.5, yRadius: 1.5).fill()
        }
    }
}

// MARK: - Feature chips

var chipX = textX
for feature in ["Open source", "No dependencies", "No analytics", "13 MB of memory"] {
    let string = attributed(feature, font: font(18, .medium), color: NSColor(hex: 0xDCDDE8))
    let width = ceil(string.size().width) + 32
    let rect = NSRect(x: chipX, y: 170, width: width, height: 40)
    let chip = NSBezierPath(roundedRect: rect, xRadius: 20, yRadius: 20)
    NSColor.white.withAlphaComponent(0.05).setFill()
    chip.fill()
    chip.lineWidth = 1.2
    NSColor.white.withAlphaComponent(0.16).setStroke()
    chip.stroke()
    draw(string, x: rect.minX + 16, midY: rect.midY)
    chipX += width + 12
}

// MARK: - Footer

draw(attributed("github.com/danielstgt/funki", font: font(20, .medium), color: inkFaint, kern: 0.2),
     at: NSPoint(x: textX, y: 104))

NSGraphicsContext.restoreGraphicsState()

// MARK: - Output

let isJPEG = ["jpg", "jpeg"].contains(outputURL.pathExtension.lowercased())
let data: Data?
if isJPEG {
    // The gradient covers the whole canvas, so nothing is lost without an alpha channel.
    data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.93])
} else {
    data = bitmap.representation(using: .png, properties: [:])
}
guard let data else { exit(1) }
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try data.write(to: outputURL)
let kilobytes = Double(data.count) / 1024
print(String(format: "Wrote %@ (%dx%d px, %.0f KB)", outputURL.path, bitmap.pixelsWide, bitmap.pixelsHigh, kilobytes))
if data.count > 1_000_000 {
    print("Warning: GitHub accepts social previews up to 1 MB. Use a .jpg output or --scale 1.")
}
