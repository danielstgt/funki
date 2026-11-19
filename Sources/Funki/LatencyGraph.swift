import AppKit

/// The latency of the most recent probes: the latest as a figure, and a bar
/// for each, with the newest on the right. A failed probe is a dotted red bar.
///
/// The view sits in the menu, so it only draws while the menu is open. There
/// is no layer, timer or animation behind it.
@MainActor
final class LatencyGraph: NSView {
    private static let barWidth: CGFloat = 2
    private static let barGap: CGFloat = 1
    /// Where the menu's titles and separators begin, and how far from the
    /// other edge they end.
    private static let margin: CGFloat = 16
    /// How far a checkmark moves the titles over.
    private static let checkmarkIndent: CGFloat = 14
    /// Digits of equal width keep the figure from shifting as it changes.
    private static let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)

    /// Whether an item of the menu has a checkmark. The menu then moves all
    /// its titles over to make room for it, and a custom view has to follow
    /// by hand to stay in line with them.
    var menuHasCheckmark = false {
        didSet { needsDisplay = true }
    }

    private let history: LatencyHistory

    init(history: LatencyHistory) {
        self.history = history
        // Room for the whole history. The menu makes the view as wide as
        // itself, which adds the room for a checkmark.
        let bars = CGFloat(LatencyHistory.capacity) * (Self.barWidth + Self.barGap) - Self.barGap
        super.init(frame: NSRect(x: 0, y: 0, width: bars + 2 * Self.margin, height: 58))
        autoresizingMask = .width
        history.onChange = { [weak self] in self?.needsDisplay = true }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        let left = Self.margin + (menuHasCheckmark ? Self.checkmarkIndent : 0)
        let bars = NSRect(x: left, y: 8, width: bounds.maxX - Self.margin - left, height: 24)
        let captionY = bars.maxY + 6
        let peak = history.peak

        let label = caption("Latency", color: .secondaryLabelColor, x: bars.minX, y: captionY)
        caption(history.last.map(Self.text) ?? "–", color: .labelColor, x: bars.minX + label + 4, y: captionY)
        // The tallest bar is as high as the graph, so the peak is its scale.
        if peak > .zero {
            caption("max \(Self.text(peak))", color: .tertiaryLabelColor, x: bars.maxX, y: captionY, trailing: true)
        }

        NSColor.separatorColor.setFill()
        NSRect(x: bars.minX, y: bars.minY - 1, width: bars.width, height: 1).fill(using: .sourceOver)

        // Never less than a millisecond for the full height. That also keeps
        // the division below away from zero.
        let scale = max(peak, .milliseconds(1))
        // From the newest at the right edge to as far back as there is room.
        for age in 0..<history.count {
            let x = bars.maxX - Self.barWidth - CGFloat(age) * (Self.barWidth + Self.barGap)
            guard x >= bars.minX else { break }

            if let latency = history[history.count - 1 - age] {
                // The bar that belongs to the figure stands out.
                (age == 0 ? NSColor.labelColor : .tertiaryLabelColor).setFill()
                // At least a point high, so a fast answer still shows up.
                let height = max(1, bars.height * (latency / scale))
                let bar = NSRect(x: x, y: bars.minY, width: Self.barWidth, height: height)
                backingAlignedRect(bar, options: .alignAllEdgesNearest).fill(using: .sourceOver)
            } else {
                // Dotted, so it differs from the tallest bar by more than color.
                NSColor.systemRed.setFill()
                for y in stride(from: bars.minY, to: bars.maxY, by: 4) {
                    NSRect(x: x, y: y, width: Self.barWidth, height: 2).fill(using: .sourceOver)
                }
            }
        }
    }

    /// Draws text starting at `x` or, when `trailing`, ending there. Returns
    /// its width.
    @discardableResult
    private func caption(_ text: String, color: NSColor, x: CGFloat, y: CGFloat, trailing: Bool = false) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: Self.font, .foregroundColor: color]
        let width = text.size(withAttributes: attributes).width
        text.draw(at: NSPoint(x: trailing ? x - width : x, y: y), withAttributes: attributes)
        return width
    }

    private static func text(_ latency: Duration) -> String {
        let milliseconds = latency / .milliseconds(1)
        return milliseconds < 1 ? "<1 ms" : "\(Int(milliseconds.rounded())) ms"
    }

    // MARK: - Accessibility

    override func isAccessibilityElement() -> Bool {
        true
    }

    override func accessibilityRole() -> NSAccessibility.Role? {
        .image
    }

    override func accessibilityLabel() -> String? {
        "Latency: " + (history.last.map(Self.text) ?? "unknown")
    }
}
